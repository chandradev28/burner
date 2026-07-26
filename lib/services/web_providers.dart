import 'dart:async';

import '../models/meta.dart';
import '../models/stream_item.dart';
import 'extractors.dart';

/// One scrapable streaming front-end.
class WebProvider {
  final String key;
  final String name;
  final String Function(String imdbId) movieUrl;
  final String Function(String imdbId, int season, int episode) episodeUrl;

  const WebProvider({
    required this.key,
    required this.name,
    required this.movieUrl,
    required this.episodeUrl,
  });
}

/// Dart-native replacement for CloudStream providers.
///
/// CloudStream's own `.cs3` plugins are compiled Android (Kotlin/DEX) code and
/// cannot be executed by a Flutter app \u2014 that is why tapping a repo entry used
/// to just download the plugin file. These providers reimplement the same idea
/// natively: resolve an IMDb id to an embed page, crawl it with [Extractors],
/// and return a direct `.m3u8` / `.mp4` that plays inside Burner.
class WebProviders {
  WebProviders._();

  static const List<WebProvider> all = <WebProvider>[
    WebProvider(
      key: 'vidsrc_to',
      name: 'VidSrc',
      movieUrl: _vidsrcToMovie,
      episodeUrl: _vidsrcToEpisode,
    ),
    WebProvider(
      key: 'vidsrc_xyz',
      name: 'VidSrc Mirror',
      movieUrl: _vidsrcXyzMovie,
      episodeUrl: _vidsrcXyzEpisode,
    ),
    WebProvider(
      key: 'autoembed',
      name: 'AutoEmbed',
      movieUrl: _autoEmbedMovie,
      episodeUrl: _autoEmbedEpisode,
    ),
    WebProvider(
      key: 'two_embed',
      name: '2Embed',
      movieUrl: _twoEmbedMovie,
      episodeUrl: _twoEmbedEpisode,
    ),
    WebProvider(
      key: 'multiembed',
      name: 'MultiEmbed',
      movieUrl: _multiEmbedMovie,
      episodeUrl: _multiEmbedEpisode,
    ),
  ];

  static String _vidsrcToMovie(String id) => 'https://vidsrc.to/embed/movie/$id';
  static String _vidsrcToEpisode(String id, int s, int e) =>
      'https://vidsrc.to/embed/tv/$id/$s/$e';

  static String _vidsrcXyzMovie(String id) =>
      'https://vidsrc.xyz/embed/movie?imdb=$id';
  static String _vidsrcXyzEpisode(String id, int s, int e) =>
      'https://vidsrc.xyz/embed/tv?imdb=$id&season=$s&episode=$e';

  static String _autoEmbedMovie(String id) =>
      'https://player.autoembed.cc/embed/movie/$id';
  static String _autoEmbedEpisode(String id, int s, int e) =>
      'https://player.autoembed.cc/embed/tv/$id/$s/$e';

  static String _twoEmbedMovie(String id) => 'https://www.2embed.cc/embed/$id';
  static String _twoEmbedEpisode(String id, int s, int e) =>
      'https://www.2embed.cc/embedtv/$id&s=$s&e=$e';

  static String _multiEmbedMovie(String id) =>
      'https://multiembed.mov/?video_id=$id';
  static String _multiEmbedEpisode(String id, int s, int e) =>
      'https://multiembed.mov/?video_id=$id&s=$s&e=$e';

  /// Resolves playable streams for a title across every enabled provider.
  ///
  /// [videoId] is either the IMDb id (movies) or `tt123:season:episode`.
  static Future<List<StreamItem>> resolve({
    required MetaItem meta,
    required String videoId,
    Set<String>? enabledKeys,
  }) async {
    final parts = videoId.split(':');
    final imdbId = parts.first.trim();
    if (!imdbId.startsWith('tt')) return const [];

    final season = parts.length > 2 ? int.tryParse(parts[1]) : null;
    final episode = parts.length > 2 ? int.tryParse(parts[2]) : null;
    final isEpisode = season != null && episode != null;

    final providers = enabledKeys == null
        ? all
        : all.where((p) => enabledKeys.contains(p.key)).toList();
    if (providers.isEmpty) return const [];

    final futures = providers.map((provider) async {
      final target = isEpisode
          ? provider.episodeUrl(imdbId, season, episode)
          : provider.movieUrl(imdbId);
      try {
        final found = await Extractors.harvest(target, referer: target);
        return found.map((stream) {
          return StreamItem(
            name: provider.name,
            title: [
              stream.isHls ? 'HLS' : 'MP4',
              _labelFor(stream.url),
            ].where((s) => s.isNotEmpty).join(' \\u2022 '),
            url: stream.url,
            headers: stream.headers,
            sourceKind: 'provider',
            sourceName: provider.name,
          );
        }).toList();
      } catch (_) {
        return const <StreamItem>[];
      }
    });

    final lists = await Future.wait(futures);
    final merged = <StreamItem>[];
    final seen = <String>{};
    for (final list in lists) {
      for (final item in list) {
        if (seen.add(item.url ?? '')) merged.add(item);
      }
    }
    return merged;
  }

  /// Best-effort quality hint from the playlist path (\u2026/1080/index.m3u8).
  static String _labelFor(String url) {
    for (final quality in const ['2160', '1440', '1080', '720', '480', '360']) {
      if (url.contains(quality)) return '${quality}p';
    }
    return 'auto';
  }
}
