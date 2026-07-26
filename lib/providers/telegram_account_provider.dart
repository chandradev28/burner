import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/stream_item.dart';
import '../services/storage_service.dart';
import '../services/telegram/td_client.dart';
import '../services/telegram/td_media.dart';
import '../services/telegram/tg_stream_server.dart';

/// Where the login flow currently stands.
enum TgStage {
  /// libtdjson is missing from this build.
  unavailable,

  /// Needs an api_id / api_hash pair from my.telegram.org.
  needsApiCredentials,

  /// Waiting for TDLib to boot.
  connecting,

  /// Waiting for a phone number.
  waitPhone,

  /// Waiting for the one-time code Telegram just sent.
  waitCode,

  /// Waiting for the two-step verification password.
  waitPassword,

  /// Logged in.
  ready,
}

/// The logged-in Telegram account, used as a content source.
///
/// This replaces the old bot-token integration: you sign in with your phone
/// number and the code Telegram sends you (plus your 2FA password if you have
/// one), exactly like the official app. Everything your account can see becomes
/// a playable source, with no Bot API file size cap.
class TelegramAccountProvider extends ChangeNotifier {
  static const int _defaultChatLimit = 150;

  TgStage _stage = TgStage.connecting;
  String _apiId = '';
  String _apiHash = '';
  String _phone = '';
  String? _codeHint;
  String? _passwordHint;
  String? _error;
  bool _busy = false;
  bool _enabled = true;

  String _accountName = '';
  List<TgChat> _chats = const [];
  final Set<int> _selectedChats = <int>{};
  bool _searchAllChats = true;
  bool _onDemandSearch = true;
  List<TgMedia> _index = const [];

  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _parametersSent = false;

  // ------------------------------------------------------------------ getters

  TgStage get stage => _stage;
  String get apiId => _apiId;
  String get apiHash => _apiHash;
  String get phone => _phone;
  String? get codeHint => _codeHint;
  String? get passwordHint => _passwordHint;
  String? get error => _error;
  bool get busy => _busy;
  bool get enabled => _enabled;
  String get accountName => _accountName;
  List<TgChat> get chats => List.unmodifiable(_chats);
  Set<int> get selectedChats => Set.unmodifiable(_selectedChats);
  bool get searchAllChats => _searchAllChats;
  bool get onDemandSearch => _onDemandSearch;
  List<TgMedia> get index => List.unmodifiable(_index);

  bool get available => TdClient.instance.available;
  bool get isLoggedIn => _stage == TgStage.ready;
  bool get hasApiCredentials => _apiId.isNotEmpty && _apiHash.isNotEmpty;

  /// True when this source should contribute streams.
  bool get isActiveSource => _enabled && isLoggedIn;

  String get statusLabel {
    switch (_stage) {
      case TgStage.unavailable:
        return 'Telegram login not available in this build';
      case TgStage.needsApiCredentials:
        return 'Add your api_id and api_hash to begin';
      case TgStage.connecting:
        return 'Connecting to Telegram...';
      case TgStage.waitPhone:
        return 'Enter your phone number';
      case TgStage.waitCode:
        return 'Enter the code Telegram sent you';
      case TgStage.waitPassword:
        return 'Enter your two-step verification password';
      case TgStage.ready:
        return _accountName.isEmpty ? 'Signed in' : 'Signed in as $_accountName';
    }
  }

  // --------------------------------------------------------------------- init

  Future<void> init() async {
    await _loadSettings();

    if (!TdClient.instance.available) {
      _stage = TgStage.unavailable;
      notifyListeners();
      return;
    }

    _sub ??= TdClient.instance.updates.listen(_onUpdate, onError: (_) {});
    TdClient.instance.start();

    if (!hasApiCredentials) {
      _stage = TgStage.needsApiCredentials;
      notifyListeners();
      return;
    }

    _stage = TgStage.connecting;
    notifyListeners();
    try {
      await TdClient.instance.request({'@type': 'getAuthorizationState'});
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    final raw =
        await StorageService.getString(StorageService.telegramAccountKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _apiId = (json['apiId'] ?? '').toString();
      _apiHash = (json['apiHash'] ?? '').toString();
      _phone = (json['phone'] ?? '').toString();
      _enabled = json['enabled'] != false;
      _searchAllChats = json['searchAllChats'] != false;
      _onDemandSearch = json['onDemandSearch'] != false;
      final selected = json['selectedChats'];
      if (selected is List) {
        _selectedChats
          ..clear()
          ..addAll(selected.whereType<int>());
      }
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    await StorageService.setString(
      StorageService.telegramAccountKey,
      jsonEncode({
        'apiId': _apiId,
        'apiHash': _apiHash,
        'phone': _phone,
        'enabled': _enabled,
        'searchAllChats': _searchAllChats,
        'onDemandSearch': _onDemandSearch,
        'selectedChats': _selectedChats.toList(),
      }),
    );
  }

  // ----------------------------------------------------------- auth machinery

  void _onUpdate(Map<String, dynamic> event) {
    if (event['@type'] != 'updateAuthorizationState') return;
    final state = event['authorization_state'];
    if (state is Map) _applyAuthState(state.cast<String, dynamic>());
  }

  Future<void> _applyAuthState(Map<String, dynamic> state) async {
    switch ((state['@type'] ?? '').toString()) {
      case 'authorizationStateWaitTdlibParameters':
        await _sendParameters();
        break;
      case 'authorizationStateWaitPhoneNumber':
        _stage = TgStage.waitPhone;
        _busy = false;
        notifyListeners();
        break;
      case 'authorizationStateWaitCode':
        final info = state['code_info'];
        _codeHint = info is Map ? _describeCodeType(info) : null;
        _stage = TgStage.waitCode;
        _busy = false;
        notifyListeners();
        break;
      case 'authorizationStateWaitPassword':
        final hint = (state['password_hint'] ?? '').toString();
        _passwordHint = hint.isEmpty ? null : hint;
        _stage = TgStage.waitPassword;
        _busy = false;
        notifyListeners();
        break;
      case 'authorizationStateReady':
        _stage = TgStage.ready;
        _busy = false;
        notifyListeners();
        await _afterLogin();
        break;
      case 'authorizationStateLoggingOut':
      case 'authorizationStateClosed':
        _stage =
            hasApiCredentials ? TgStage.waitPhone : TgStage.needsApiCredentials;
        _accountName = '';
        _chats = const [];
        _index = const [];
        _busy = false;
        _parametersSent = false;
        notifyListeners();
        break;
    }
  }

  static String _describeCodeType(Map info) {
    final type = info['type'];
    final kind = type is Map ? (type['@type'] ?? '').toString() : '';
    switch (kind) {
      case 'authenticationCodeTypeTelegramMessage':
        return 'Sent to your other Telegram sessions';
      case 'authenticationCodeTypeSms':
        return 'Sent by SMS';
      case 'authenticationCodeTypeCall':
        return 'You will receive a phone call';
      case 'authenticationCodeTypeFlashCall':
        return 'Watch for a flash call';
      case 'authenticationCodeTypeFragment':
        return 'Delivered through Fragment';
      default:
        return 'Code sent';
    }
  }

  Future<void> _sendParameters() async {
    if (_parametersSent || !hasApiCredentials) return;
    _parametersSent = true;
    try {
      final dir = await getApplicationSupportDirectory();
      await TdClient.instance.request({
        '@type': 'setTdlibParameters',
        'use_test_dc': false,
        'database_directory': '${dir.path}/tdlib',
        'files_directory': '${dir.path}/tdlib/files',
        'use_file_database': true,
        'use_chat_info_database': true,
        'use_message_database': true,
        'use_secret_chats': false,
        'api_id': int.tryParse(_apiId) ?? 0,
        'api_hash': _apiHash,
        'system_language_code': 'en',
        'device_model': 'Android',
        'system_version': 'Android',
        'application_version': '1.0',
      });
    } catch (e) {
      _parametersSent = false;
      _fail(e);
    }
  }

  Future<void> _afterLogin() async {
    await TgStreamServer.instance.start();
    try {
      final me = await TdClient.instance.request({'@type': 'getMe'});
      final first = (me['first_name'] ?? '').toString();
      final last = (me['last_name'] ?? '').toString();
      final username = me['usernames'] is Map
          ? (((me['usernames'] as Map)['editable_username']) ?? '').toString()
          : '';
      _accountName = [first, last].where((s) => s.isNotEmpty).join(' ');
      if (_accountName.isEmpty && username.isNotEmpty) {
        _accountName = '@$username';
      }
      notifyListeners();
    } catch (_) {}
    await loadChats();
  }

  // ------------------------------------------------------------- user actions

  Future<void> setApiCredentials(String id, String hash) async {
    _apiId = id.trim();
    _apiHash = hash.trim();
    _error = null;
    await _saveSettings();
    _parametersSent = false;
    notifyListeners();
    await init();
  }

  Future<bool> sendPhone(String phone) async {
    final value = phone.trim();
    if (value.isEmpty) return false;
    _phone = value;
    return _run(() async {
      await TdClient.instance.request({
        '@type': 'setAuthenticationPhoneNumber',
        'phone_number': value,
      });
      await _saveSettings();
    });
  }

  Future<bool> submitCode(String code) {
    final value = code.trim();
    if (value.isEmpty) return Future.value(false);
    return _run(() async {
      await TdClient.instance.request({
        '@type': 'checkAuthenticationCode',
        'code': value,
      });
    });
  }

  Future<bool> submitPassword(String password) {
    if (password.isEmpty) return Future.value(false);
    return _run(() async {
      await TdClient.instance.request({
        '@type': 'checkAuthenticationPassword',
        'password': password,
      });
    });
  }

  Future<bool> resendCode() => _run(() async {
        await TdClient.instance.request({'@type': 'resendAuthenticationCode'});
      });

  Future<bool> changeNumber() async {
    _stage = TgStage.waitPhone;
    _codeHint = null;
    notifyListeners();
    return true;
  }

  Future<void> logOut() async {
    _busy = true;
    notifyListeners();
    try {
      await TdClient.instance.request({'@type': 'logOut'});
    } catch (_) {}
    _selectedChats.clear();
    _index = const [];
    _chats = const [];
    _accountName = '';
    _busy = false;
    _stage = hasApiCredentials ? TgStage.waitPhone : TgStage.needsApiCredentials;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setSearchAllChats(bool value) async {
    _searchAllChats = value;
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setOnDemandSearch(bool value) async {
    _onDemandSearch = value;
    notifyListeners();
    await _saveSettings();
  }

  Future<void> toggleChat(int chatId, bool selected) async {
    if (selected) {
      _selectedChats.add(chatId);
    } else {
      _selectedChats.remove(chatId);
    }
    notifyListeners();
    await _saveSettings();
  }

  Future<void> loadChats() async {
    if (!isLoggedIn) return;
    _busy = true;
    notifyListeners();
    try {
      _chats = await TdMedia.loadChats(limit: _defaultChatLimit);
    } catch (e) {
      _fail(e);
    }
    _busy = false;
    notifyListeners();
  }

  /// Builds a browsable index from the chats you pinned.
  Future<void> refreshIndex() async {
    if (!isLoggedIn) return;
    _busy = true;
    notifyListeners();
    final found = <TgMedia>[];
    try {
      for (final chatId in _selectedChats.take(12)) {
        found.addAll(await TdMedia.recentVideos(chatId, limit: 40));
      }
      _index = found;
    } catch (e) {
      _fail(e);
    }
    _busy = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // --------------------------------------------------------- source interface

  /// Streams for a title, merged into the combined stream list.
  ///
  /// Pinned chats are searched first, then the whole account when global search
  /// is on, and finally the cached index is used as a fallback.
  Future<List<StreamItem>> streamsFor(String query) async {
    if (!isActiveSource || query.trim().isEmpty) return const [];
    await TgStreamServer.instance.start();

    final found = <TgMedia>[];
    final seen = <int>{};

    void collect(Iterable<TgMedia> items) {
      for (final item in items) {
        if (item.fileId <= 0 || item.size <= 0) continue;
        if (seen.add(item.fileId)) found.add(item);
      }
    }

    for (final chatId in _selectedChats.take(8)) {
      try {
        collect(await TdMedia.searchChat(chatId, query, limit: 20));
      } catch (_) {}
    }

    if (_onDemandSearch && _searchAllChats) {
      try {
        collect(await TdMedia.searchAllChats(query, limit: 40));
      } catch (_) {}
    }

    if (found.isEmpty && _index.isNotEmpty) {
      collect(TdMedia.filter(_index, query));
    }

    final streams = <StreamItem>[];
    for (final media in found.take(25)) {
      final url = TgStreamServer.instance.urlFor(
        fileId: media.fileId,
        size: media.size,
        mimeType: media.mimeType,
        name: media.caption,
      );
      if (url == null) continue;
      final parts = <String>[
        if (media.chatTitle.isNotEmpty) media.chatTitle,
        if (media.sizeLabel.isNotEmpty) media.sizeLabel,
        if (media.durationLabel.isNotEmpty) media.durationLabel,
      ];
      streams.add(StreamItem(
        name: media.qualityLabel == null
            ? 'Telegram'
            : 'Telegram \u2022 ${media.qualityLabel}',
        title: '${media.caption}\n${parts.join(' \u2022 ')}',
        url: url,
        sourceKind: 'telegram',
        sourceName: media.chatTitle.isEmpty ? 'Telegram' : media.chatTitle,
      ));
    }
    return streams;
  }

  // ------------------------------------------------------------------ helpers

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  void _fail(Object e) {
    _error = e is TdError ? e.friendly : e.toString();
    _busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
