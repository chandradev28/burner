import 'dart:async';

import 'package:http/http.dart' as http;

/// A direct video link discovered by crawling an embed page.
class FoundStream {
  final String url;
  final String referer;
  final String? quality;

  const FoundStream({required this.url, required this.referer, this.quality});

  bool get isHls => url.toLowerCase().contains('.m3u8');

  Map<String, String> get headers => {
        'User-Agent': Extractors.userAgent,
        'Referer': referer,
        'Origin': Extractors.originOf(referer),
      };
}

/// Generic embed crawler.
///
/// Most streaming front-ends nest one or two iframes and then expose the real
/// `.m3u8` / `.mp4` inside a JSON blob or a packed script. Instead of writing a
/// bespoke scraper per host, [harvest] walks the iframe chain, unpacks any
/// `eval(function(p,a,c,k,e,d))` payloads it meets, and collects every direct
/// video link it can see. This runs entirely in Dart, so the results are
/// playable by the in-app player.
class Extractors {
  Extractors._();

  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

  static const Duration _timeout = Duration(seconds: 12);

  static final RegExp _videoUrl = RegExp(
    r'''https?:\/\/[^\s"'<>\\)]+?\.(?:m3u8|mp4)(?:\?[^\s"'<>\\)]*)?''',
    caseSensitive: false,
  );

  static final RegExp _fileProp = RegExp(
    r'''["'](?:file|src|source|videoUrl|hls|playlist)["']\s*:\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  static final RegExp _iframeSrc = RegExp(
    r'''<iframe[^>]+src\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  static final RegExp _packed = RegExp(
    r"""\}\s*\(\s*'(.*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'(.*?)'\.split\('\|'\)""",
    dotAll: true,
  );

  static String originOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    return '${uri.scheme}://${uri.host}';
  }

  /// Fetches a page as a browser would, following the referer chain.
  static Future<String?> fetch(String url, {String? referer}) async {
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': userAgent,
              'Accept': '*/*',
              if (referer != null) 'Referer': referer,
              if (referer != null) 'Origin': originOf(referer),
            },
          )
          .timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 400) {
        return response.body;
      }
    } catch (_) {
      // Network failure / bad host: treat as "nothing found".
    }
    return null;
  }

  /// Reverses the common `eval(function(p,a,c,k,e,d){...})` packer.
  static String? unpack(String source) {
    final match = _packed.firstMatch(source);
    if (match == null) return null;

    var payload = match.group(1)!.replaceAll(r"\'", "'");
    final radix = int.tryParse(match.group(2)!) ?? 36;
    final count = int.tryParse(match.group(3)!) ?? 0;
    final words = match.group(4)!.split('|');

    String encode(int value) {
      final prefix = value < radix ? '' : encode(value ~/ radix);
      final rest = value % radix;
      return prefix +
          (rest > 35
              ? String.fromCharCode(rest + 29)
              : rest.toRadixString(36));
    }

    for (var i = count - 1; i >= 0; i--) {
      if (i >= words.length || words[i].isEmpty) continue;
      payload = payload.replaceAll(
        RegExp('\\b${RegExp.escape(encode(i))}\\b'),
        words[i],
      );
    }
    return payload;
  }

  static String _absolute(String candidate, String base) {
    if (candidate.startsWith('//')) return 'https:$candidate';
    if (candidate.startsWith('http')) return candidate;
    final baseUri = Uri.tryParse(base);
    if (baseUri == null) return candidate;
    return baseUri.resolve(candidate).toString();
  }

  /// Pulls every direct video link out of a single blob of HTML/JS.
  static List<String> linksIn(String body, String base) {
    final found = <String>{};

    void scan(String text) {
      for (final m in _videoUrl.allMatches(text)) {
        found.add(m.group(0)!.replaceAll(r'\/', '/'));
      }
      for (final m in _fileProp.allMatches(text)) {
        final value = m.group(1)!.replaceAll(r'\/', '/');
        final lower = value.toLowerCase();
        if (lower.contains('.m3u8') || lower.contains('.mp4')) {
          found.add(_absolute(value, base));
        }
      }
    }

    scan(body);
    final unpacked = unpack(body);
    if (unpacked != null) scan(unpacked);

    return found.toList();
  }

  /// Walks an embed page (and up to [depth] nested iframes) collecting
  /// direct, in-app playable video links.
  static Future<List<FoundStream>> harvest(
    String url, {
    String? referer,
    int depth = 2,
  }) async {
    final results = <String, FoundStream>{};
    final visited = <String>{};

    Future<void> walk(String target, String? from, int remaining) async {
      if (remaining < 0 || !visited.add(target)) return;
      final body = await fetch(target, referer: from);
      if (body == null) return;

      for (final link in linksIn(body, target)) {
        results.putIfAbsent(
          link,
          () => FoundStream(url: link, referer: target),
        );
      }
      if (results.isNotEmpty || remaining == 0) return;

      final iframes = _iframeSrc
          .allMatches(body)
          .map((m) => _absolute(m.group(1)!, target))
          .where((u) => u.startsWith('http'))
          .take(3);
      for (final frame in iframes) {
        await walk(frame, target, remaining - 1);
      }
    }

    await walk(url, referer, depth);
    return results.values.toList();
  }
}
