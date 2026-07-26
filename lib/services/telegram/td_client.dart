import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'td_bindings.dart';

/// A TDLib error returned in place of a result.
class TdError implements Exception {
  final int code;
  final String message;

  const TdError(this.code, this.message);

  /// Human readable text for the common Telegram login errors.
  String get friendly {
    switch (message) {
      case 'PHONE_NUMBER_INVALID':
        return 'That phone number is not valid. Include the country code.';
      case 'PHONE_CODE_INVALID':
        return 'Wrong code. Check the digits and try again.';
      case 'PHONE_CODE_EXPIRED':
        return 'That code expired. Request a new one.';
      case 'PASSWORD_HASH_INVALID':
        return 'Wrong two-step verification password.';
      case 'API_ID_INVALID':
      case 'API_ID_PUBLISHED_FLOOD':
        return 'That api_id / api_hash pair was rejected by Telegram.';
      case 'SESSION_PASSWORD_NEEDED':
        return 'Two-step verification password required.';
      default:
        if (message.startsWith('FLOOD_WAIT_')) {
          final secs = message.split('_').last;
          return 'Telegram rate limit -- wait ${secs}s and try again.';
        }
        return message;
    }
  }

  @override
  String toString() => 'TdError($code): $message';
}

/// Thin async wrapper around TDLib's JSON interface.
///
/// Requests are correlated with the `@extra` field, and `td_receive` is polled
/// with a zero timeout on a periodic timer so the UI isolate never blocks.
class TdClient {
  TdClient._();

  static final TdClient instance = TdClient._();

  static const Duration _pollInterval = Duration(milliseconds: 20);
  static const int _maxDrainPerTick = 64;

  TdBindings? _bindings;
  int? _clientId;
  Timer? _poll;
  int _seq = 0;

  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  final StreamController<Map<String, dynamic>> _updates =
      StreamController<Map<String, dynamic>>.broadcast();

  /// True when `libtdjson` was found in this build.
  bool get available => TdBindings.open() != null;

  bool get started => _clientId != null;

  /// Every TDLib update (`@type` starts with `update...`).
  Stream<Map<String, dynamic>> get updates => _updates.stream;

  /// Creates the TDLib client and starts pumping its output queue.
  bool start() {
    if (_clientId != null) return true;
    final bindings = TdBindings.open();
    if (bindings == null) return false;
    _bindings = bindings;

    // Keep TDLib quiet in release builds.
    _executeRaw({
      '@type': 'setLogVerbosityLevel',
      'new_verbosity_level': 1,
    });

    _clientId = bindings.createClientId();
    _poll ??= Timer.periodic(_pollInterval, (_) => _drain());
    return true;
  }

  /// Fire-and-forget query.
  void post(Map<String, dynamic> query) {
    final bindings = _bindings;
    final clientId = _clientId;
    if (bindings == null || clientId == null) return;
    final ptr = jsonEncode(query).toNativeUtf8();
    try {
      bindings.send(clientId, ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  /// Sends a query and awaits its matching result.
  ///
  /// Throws [TdError] when TDLib answers with an `error` object, and
  /// [TimeoutException] if nothing comes back in time. File downloads use a
  /// long timeout because a synchronous `downloadFile` waits for real bytes.
  Future<Map<String, dynamic>> request(
    Map<String, dynamic> query, {
    Duration timeout = const Duration(seconds: 45),
  }) {
    if (!start()) {
      return Future.error(
          const TdError(-1, 'Telegram library is not available in this build'));
    }
    final extra = 'q${_seq++}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[extra] = completer;
    post({...query, '@extra': extra});

    return completer.future.timeout(timeout, onTimeout: () {
      _pending.remove(extra);
      throw TimeoutException('Telegram request timed out: ${query['@type']}');
    });
  }

  /// Synchronous TDLib call (only valid for a few offline methods).
  Map<String, dynamic>? _executeRaw(Map<String, dynamic> query) {
    final bindings = _bindings ?? TdBindings.open();
    if (bindings == null) return null;
    final ptr = jsonEncode(query).toNativeUtf8();
    try {
      final out = bindings.execute(ptr);
      if (out == nullptr) return null;
      final decoded = jsonDecode(out.toDartString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    } finally {
      calloc.free(ptr);
    }
  }

  void _drain() {
    final bindings = _bindings;
    if (bindings == null) return;
    for (var i = 0; i < _maxDrainPerTick; i++) {
      Pointer<Utf8> out;
      try {
        out = bindings.receive(0);
      } catch (_) {
        return;
      }
      if (out == nullptr) return;

      Map<String, dynamic>? event;
      try {
        final decoded = jsonDecode(out.toDartString());
        if (decoded is Map<String, dynamic>) event = decoded;
      } catch (_) {
        event = null;
      }
      if (event == null) continue;

      final extra = event['@extra'];
      if (extra is String && _pending.containsKey(extra)) {
        final completer = _pending.remove(extra)!;
        if (event['@type'] == 'error') {
          completer.completeError(TdError(
            event['code'] is int ? event['code'] as int : 0,
            (event['message'] ?? 'Unknown Telegram error').toString(),
          ));
        } else {
          completer.complete(event);
        }
        continue;
      }

      if (!_updates.isClosed) _updates.add(event);
    }
  }

  /// Closes the TDLib instance (used on logout).
  Future<void> close() async {
    if (_clientId == null) return;
    try {
      await request({'@type': 'close'}, timeout: const Duration(seconds: 10));
    } catch (_) {}
    _poll?.cancel();
    _poll = null;
    _clientId = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(const TdError(-2, 'Telegram client closed'));
      }
    }
    _pending.clear();
  }
}
