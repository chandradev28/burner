import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _CreateClientIdC = Int32 Function();
typedef _CreateClientIdDart = int Function();

typedef _SendC = Void Function(Int32, Pointer<Utf8>);
typedef _SendDart = void Function(int, Pointer<Utf8>);

typedef _ReceiveC = Pointer<Utf8> Function(Double);
typedef _ReceiveDart = Pointer<Utf8> Function(double);

typedef _ExecuteC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _ExecuteDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// Raw FFI bindings to TDLib's JSON interface (`libtdjson`).
///
/// TDLib is Telegram's own client library, so logging in with a phone number
/// plus the one-time code (and a 2FA password when set) behaves exactly like
/// the official apps: full account access, no Bot API restrictions and no
/// 20 MB download cap.
///
/// The shared library is resolved at runtime and every failure is swallowed,
/// so a build that ships without `libtdjson.so` still runs -- the Telegram
/// account screen simply reports itself as unavailable.
class TdBindings {
  final DynamicLibrary _lib;
  final _CreateClientIdDart createClientId;
  final _SendDart send;
  final _ReceiveDart receive;
  final _ExecuteDart execute;

  TdBindings._(this._lib)
      : createClientId =
            _lib.lookupFunction<_CreateClientIdC, _CreateClientIdDart>(
                'td_create_client_id'),
        send = _lib.lookupFunction<_SendC, _SendDart>('td_send'),
        receive = _lib.lookupFunction<_ReceiveC, _ReceiveDart>('td_receive'),
        execute = _lib.lookupFunction<_ExecuteC, _ExecuteDart>('td_execute');

  DynamicLibrary get library => _lib;

  /// Candidate library names, in preference order.
  static const List<String> _candidates = <String>[
    'libtdjson.so',
    'libtdjson.so.1.8.0',
    'libtdjson.dylib',
    'tdjson.dll',
  ];

  static TdBindings? _cached;
  static bool _tried = false;

  /// Opens `libtdjson` once. Returns null when the library is not bundled.
  static TdBindings? open() {
    if (_tried) return _cached;
    _tried = true;
    for (final name in _candidates) {
      try {
        _cached = TdBindings._(DynamicLibrary.open(name));
        return _cached;
      } catch (_) {
        // Try the next candidate.
      }
    }
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        _cached = TdBindings._(DynamicLibrary.process());
      } catch (_) {
        _cached = null;
      }
    }
    return _cached;
  }
}
