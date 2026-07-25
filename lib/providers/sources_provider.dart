import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/cloudstream.dart';
import '../models/telegram.dart';
import '../services/cloudstream_client.dart';
import '../services/storage_service.dart';
import '../services/telegram_client.dart';

/// Owns every non-Stremio content source: CloudStream repositories and the
/// Telegram integration, plus which sources are switched on.
class SourcesProvider extends ChangeNotifier {
  final List<CsRepo> _repos = [];
  TelegramConfig _telegram = const TelegramConfig();
  List<TelegramItem> _telegramIndex = const [];

  bool _addonsEnabled = true;
  bool _cloudStreamEnabled = true;
  bool _loading = false;
  String? _error;

  List<CsRepo> get repos => List.unmodifiable(_repos);
  TelegramConfig get telegram => _telegram;
  List<TelegramItem> get telegramIndex => _telegramIndex;
  bool get addonsEnabled => _addonsEnabled;
  bool get cloudStreamEnabled => _cloudStreamEnabled;
  bool get loading => _loading;
  String? get error => _error;

  int get pluginCount =>
      _repos.fold(0, (sum, repo) => sum + repo.plugins.length);

  /// Repos actually usable for playback lookups.
  List<CsRepo> get activeRepos => _cloudStreamEnabled ? _repos : const [];

  Future<void> init() async {
    final rawRepos =
        await StorageService.getStringList(StorageService.cloudStreamReposKey);
    _repos
      ..clear()
      ..addAll(rawRepos.map((raw) {
        try {
          return CsRepo.decode(raw);
        } catch (_) {
          return null;
        }
      }).whereType<CsRepo>());

    final rawTelegram =
        await StorageService.getString(StorageService.telegramConfigKey);
    if (rawTelegram != null) {
      try {
        _telegram = TelegramConfig.decode(rawTelegram);
      } catch (_) {}
    }

    final toggles =
        await StorageService.getStringList(StorageService.sourceTogglesKey);
    if (toggles.isNotEmpty) {
      _addonsEnabled = !toggles.contains('addons:off');
      _cloudStreamEnabled = !toggles.contains('cloudstream:off');
    }

    notifyListeners();
    if (_telegram.enabled && _telegram.isConfigured) {
      unawaited(refreshTelegramIndex());
    }
  }

  // ---------------------------------------------------------------- toggles

  Future<void> setAddonsEnabled(bool value) async {
    _addonsEnabled = value;
    notifyListeners();
    await _persistToggles();
  }

  Future<void> setCloudStreamEnabled(bool value) async {
    _cloudStreamEnabled = value;
    notifyListeners();
    await _persistToggles();
  }

  Future<void> _persistToggles() async {
    await StorageService.setStringList(StorageService.sourceTogglesKey, [
      if (!_addonsEnabled) 'addons:off',
      if (!_cloudStreamEnabled) 'cloudstream:off',
    ]);
  }

  // ------------------------------------------------------------ cloudstream

  Future<void> addRepo(String url) async {
    final normalized = CloudStreamClient.normalizeRepoUrl(url);
    if (normalized.isEmpty) return;
    if (_repos.any((r) => r.url == normalized)) {
      _error = 'Repository already added';
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final repo = await CloudStreamClient.fetchRepo(normalized);
      _repos.add(repo);
      await _persistRepos();
    } catch (e) {
      _error = 'Could not add repository: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> removeRepo(CsRepo repo) async {
    _repos.removeWhere((r) => r.url == repo.url);
    notifyListeners();
    await _persistRepos();
  }

  Future<void> refreshAllRepos() async {
    if (_repos.isEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();
    for (var i = 0; i < _repos.length; i++) {
      try {
        _repos[i] = await CloudStreamClient.refresh(_repos[i]);
      } catch (_) {}
    }
    _loading = false;
    notifyListeners();
    await _persistRepos();
  }

  Future<void> togglePlugin(CsRepo repo, CsPlugin plugin, bool enabled) async {
    final index = _repos.indexWhere((r) => r.url == repo.url);
    if (index < 0) return;
    final current = _repos[index];
    final set = current.enabledPlugins.isEmpty
        ? current.plugins.map((p) => p.internalName).toSet()
        : {...current.enabledPlugins};
    if (enabled) {
      set.add(plugin.internalName);
    } else {
      set.remove(plugin.internalName);
    }
    _repos[index] = current.copyWith(enabledPlugins: set);
    notifyListeners();
    await _persistRepos();
  }

  Future<void> setAllPlugins(CsRepo repo, bool enabled) async {
    final index = _repos.indexWhere((r) => r.url == repo.url);
    if (index < 0) return;
    final current = _repos[index];
    _repos[index] = current.copyWith(
      enabledPlugins:
          enabled ? current.plugins.map((p) => p.internalName).toSet() : <String>{'__none__'},
    );
    notifyListeners();
    await _persistRepos();
  }

  Future<void> _persistRepos() async {
    await StorageService.setStringList(
      StorageService.cloudStreamReposKey,
      _repos.map((r) => r.encode()).toList(),
    );
  }

  // --------------------------------------------------------------- telegram

  Future<bool> saveTelegram(TelegramConfig config) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      String? username;
      if (config.isConfigured) {
        username = await TelegramClient.validateToken(config.botToken);
      }
      _telegram = config.copyWith(botUsername: username);
      await StorageService.setString(
        StorageService.telegramConfigKey,
        _telegram.encode(),
      );
      _loading = false;
      notifyListeners();
      if (_telegram.enabled) unawaited(refreshTelegramIndex());
      return true;
    } catch (e) {
      _error = 'Telegram: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> clearTelegram() async {
    _telegram = const TelegramConfig();
    _telegramIndex = const [];
    await StorageService.remove(StorageService.telegramConfigKey);
    notifyListeners();
  }

  Future<void> refreshTelegramIndex() async {
    if (!_telegram.isConfigured) return;
    try {
      _telegramIndex = await TelegramClient.indexUpdates(_telegram);
    } catch (e) {
      _error = 'Telegram index failed: $e';
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
