import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'td_client.dart';

/// Serves Telegram files to the in-app player over loopback HTTP.
///
/// `video_player` needs a seekable URL, while TDLib hands out byte ranges of a
/// growing local file. This server bridges the two: it answers HTTP Range
/// requests by asking TDLib to download exactly the requested window
/// (`downloadFile` with `offset` + `limit` + `synchronous`), then streams those
/// bytes straight from disk. Result: fast start, real seeking, and no waiting
/// for the whole file -- the same behaviour as streaming inside Telegram.
class TgStreamServer {
  TgStreamServer._();

  static final TgStreamServer instance = TgStreamServer._();

  /// 2 MB windows keep memory flat while staying efficient over the wire.
  static const int _chunkSize = 2 * 1024 * 1024;

  HttpServer? _server;

  int? get port => _server?.port;

  Future<bool> start() async {
    if (_server != null) return true;
    try {
      final server =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: true);
      server.autoCompress = false;
      _server = server;
      server.listen(
        _handle,
        onError: (_) {},
        cancelOnError: false,
      );
      return true;
    } catch (_) {
      _server = null;
      return false;
    }
  }

  /// Playable loopback URL for a TDLib file id.
  String? urlFor({
    required int fileId,
    required int size,
    String? mimeType,
    String? name,
  }) {
    final p = port;
    if (p == null) return null;
    final query = <String, String>{
      'size': '$size',
      if (mimeType != null && mimeType.isNotEmpty) 'mime': mimeType,
    };
    final suffix = _extensionFor(mimeType, name);
    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: p,
      path: '/tg/$fileId$suffix',
      queryParameters: query,
    );
    return uri.toString();
  }

  static String _extensionFor(String? mimeType, String? name) {
    if (name != null && name.contains('.')) {
      final ext = name.split('.').last.toLowerCase();
      if (ext.length <= 4 && RegExp(r'^[a-z0-9]+$').hasMatch(ext)) {
        return '.$ext';
      }
    }
    switch (mimeType) {
      case 'video/x-matroska':
        return '.mkv';
      case 'video/webm':
        return '.webm';
      case 'video/quicktime':
        return '.mov';
      default:
        return '.mp4';
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final segments = request.uri.pathSegments;
      if (segments.length < 2 || segments.first != 'tg') {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }

      final rawId = segments[1].split('.').first;
      final fileId = int.tryParse(rawId);
      final total = int.tryParse(request.uri.queryParameters['size'] ?? '') ?? 0;
      final mime = request.uri.queryParameters['mime'] ?? 'video/mp4';
      if (fileId == null || total <= 0) {
        response.statusCode = HttpStatus.badRequest;
        await response.close();
        return;
      }

      // ---- range parsing -------------------------------------------------
      var start = 0;
      var end = total - 1;
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      final isRange = rangeHeader != null && rangeHeader.startsWith('bytes=');
      if (isRange) {
        final spec = rangeHeader.substring(6).split(',').first.trim();
        final parts = spec.split('-');
        if (parts.first.isEmpty) {
          // Suffix range: bytes=-N
          final lastN = int.tryParse(parts.last) ?? total;
          start = math.max(0, total - lastN);
        } else {
          start = int.tryParse(parts.first) ?? 0;
          if (parts.length > 1 && parts[1].isNotEmpty) {
            end = int.tryParse(parts[1]) ?? end;
          }
        }
      }
      start = start.clamp(0, total - 1);
      end = end.clamp(start, total - 1);
      final length = end - start + 1;

      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.headers.set(HttpHeaders.contentTypeHeader, mime);
      response.headers.contentLength = length;
      if (isRange) {
        response.statusCode = HttpStatus.partialContent;
        response.headers
            .set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$total');
      } else {
        response.statusCode = HttpStatus.ok;
      }

      if (request.method == 'HEAD') {
        await response.close();
        return;
      }

      // ---- stream the window, chunk by chunk -----------------------------
      var position = start;
      while (position <= end) {
        final want = math.min(_chunkSize, end - position + 1);
        final file = await TdClient.instance.request(
          {
            '@type': 'downloadFile',
            'file_id': fileId,
            'priority': 32,
            'offset': position,
            'limit': want,
            'synchronous': true,
          },
          timeout: const Duration(minutes: 5),
        );

        final local = file['local'];
        final path = local is Map ? (local['path'] ?? '').toString() : '';
        if (path.isEmpty) break;

        final handle = await File(path).open();
        List<int> bytes;
        try {
          await handle.setPosition(position);
          bytes = await handle.read(want);
        } finally {
          await handle.close();
        }
        if (bytes.isEmpty) break;

        response.add(bytes);
        await response.flush();
        position += bytes.length;
      }
      await response.close();
    } on TdError {
      _fail(response);
    } on TimeoutException {
      _fail(response);
    } catch (_) {
      // The player seeked away or closed the socket -- nothing to do.
      _fail(response);
    }
  }

  void _fail(HttpResponse response) {
    try {
      response.close();
    } catch (_) {}
  }
}
