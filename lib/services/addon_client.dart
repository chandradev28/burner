import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/addon.dart';
import '../models/meta.dart';
import '../models/stream_item.dart';

/// HTTP client implementing the Stremio addon protocol:
///   {base}/manifest.json
///   {base}/catalog/{type}/{id}.json
///   {base}/catalog/{type}/{id}/{extraProps}.json
///   {base}/meta/{type}/{id}.json
///   {base}/stream/{type}/{id}.json
class AddonClient {
  AddonClient._();

  static const Duration _timeout = Duration(seconds: 20);

  /// Safety rails for paged search so a broken addon cannot loop forever.
  static const int maxSearchPages = 12;
  static const int maxSearchResults = 600;

  static Future<Map<String, dynamic>> _getJson(String url) async {
    final response =
        await http.get(Uri.parse(url), headers: {'Accept': 'application/json'})
            .timeout(_timeout);
    if (response.statusCode != 200) {
      throw AddonException('HTTP ${response.statusCode} for $url');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw AddonException('Unexpected response from $url');
    }
    return decoded.cast<String, dynamic>();
  }

  /// Normalizes user input into a manifest URL.
  /// Accepts stremio:// links and base URLs without /manifest.json.
  static String normalizeManifestUrl(String input) {
    var url = input.trim();
    if (url.startsWith('stremio://')) {
      url = url.replaceFirst('stremio://', 'https://');
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    if (!url.endsWith('manifest.json')) {
      url = '${url.replaceAll(RegExp(r'/+$'), '')}/manifest.json';
    }
    return url;
  }

  /// Fetches and parses an addon manifest.
  static Future<Addon> fetchAddon(String manifestUrl) async {
    final url = normalizeManifestUrl(manifestUrl);
    final json = await _getJson(url);
    final manifest = AddonManifest.fromJson(json);
    if (manifest.id.isEmpty) {
      throw AddonException('Invalid manifest at $url');
    }
    return Addon(transportUrl: url, manifest: manifest);
  }

  /// Fetches a catalog. [extraProps] is an already-encoded extra segment
  /// such as "search=batman" or "genre=Action&skip=100".
  static Future<List<MetaItem>> fetchCatalog(
    Addon addon,
    AddonCatalog catalog, {
    String? extraProps,
  }) async {
    final extraSegment =
        (extraProps == null || extraProps.isEmpty) ? '' : '/$extraProps';
    final url =
        '${addon.baseUrl}/catalog/${catalog.type}/${Uri.encodeComponent(catalog.id)}$extraSegment.json';
    final json = await _getJson(url);
    final metas = json['metas'];
    if (metas is! List) return const [];
    return metas
        .whereType<Map>()
        .map((m) => MetaItem.fromJson(m.cast<String, dynamic>()))
        .where((m) => m.id.isNotEmpty)
        .toList();
  }

  /// Searches one catalog using the `search` extra (first page only).
  static Future<List<MetaItem>> searchCatalog(
    Addon addon,
    AddonCatalog catalog,
    String query,
  ) {
    return searchCatalogPage(addon, catalog, query);
  }

  /// Searches one catalog, asking for a specific page via the `skip` extra.
  ///
  /// Stremio catalogs return a fixed page (often 20-100 items) and expect the
  /// client to ask for more with `skip=N`.
  static Future<List<MetaItem>> searchCatalogPage(
    Addon addon,
    AddonCatalog catalog,
    String query, {
    int skip = 0,
  }) {
    final encoded = Uri.encodeComponent(query);
    return fetchCatalog(
      addon,
      catalog,
      extraProps:
          skip <= 0 ? 'search=$encoded' : 'search=$encoded&skip=$skip',
    );
  }

  /// Searches one catalog and keeps paging with `skip` until the addon runs
  /// out of results.
  ///
  /// Paging stops when a page comes back short, empty, or contains nothing new
  /// (which is how addons that ignore `skip` behave).
  ///
  /// [onPage] receives the new items of each page as they arrive so the UI can
  /// fill in progressively.
  static Future<List<MetaItem>> searchCatalogAll(
    Addon addon,
    AddonCatalog catalog,
    String query, {
    int maxPages = maxSearchPages,
    int maxItems = maxSearchResults,
    void Function(List<MetaItem> newItems)? onPage,
  }) async {
    final all = <MetaItem>[];
    final seen = <String>{};
    var skip = 0;
    int? pageSize;

    for (var page = 0; page < maxPages; page++) {
      List<MetaItem> items;
      try {
        items = await searchCatalogPage(addon, catalog, query, skip: skip);
      } catch (_) {
        break; // keep whatever we already have
      }
      if (items.isEmpty) break;

      final fresh = <MetaItem>[];
      for (final item in items) {
        if (seen.add('${item.type}:${item.id}')) fresh.add(item);
      }
      if (fresh.isEmpty) break; // addon ignored skip and repeated itself

      all.addAll(fresh);
      onPage?.call(fresh);

      pageSize ??= items.length;
      if (items.length < pageSize) break; // short page means the end
      if (all.length >= maxItems) break;

      skip += items.length;
    }

    return all.length > maxItems ? all.sublist(0, maxItems) : all;
  }

  /// Fetches full metadata for an item from one addon.
  static Future<MetaItem?> fetchMeta(
    Addon addon,
    String type,
    String id,
  ) async {
    final url =
        '${addon.baseUrl}/meta/$type/${Uri.encodeComponent(id)}.json';
    final json = await _getJson(url);
    final meta = json['meta'];
    if (meta is! Map) return null;
    final item = MetaItem.fromJson(meta.cast<String, dynamic>());
    return item.id.isEmpty ? null : item;
  }

  /// Fetches full metadata trying every capable addon, first hit wins.
  static Future<MetaItem?> resolveMeta(
    List<Addon> addons,
    String type,
    String id,
  ) async {
    for (final addon in addons.where((a) => a.hasResource('meta', type, id))) {
      try {
        final meta = await fetchMeta(addon, type, id);
        if (meta != null) return meta;
      } catch (_) {
        // try next addon
      }
    }
    return null;
  }

  /// Fetches streams for an item from one addon.
  static Future<List<StreamItem>> fetchStreams(
    Addon addon,
    String type,
    String id,
  ) async {
    final url =
        '${addon.baseUrl}/stream/$type/${Uri.encodeComponent(id)}.json';
    final json = await _getJson(url);
    final streams = json['streams'];
    if (streams is! List) return const [];
    return streams
        .whereType<Map>()
        .map((s) => StreamItem.fromJson(s.cast<String, dynamic>(),
            addonName: addon.name))
        .toList();
  }

  /// Aggregates streams for an item across all capable addons in parallel.
  static Future<List<StreamItem>> resolveStreams(
    List<Addon> addons,
    String type,
    String id,
  ) async {
    final capable =
        addons.where((a) => a.hasResource('stream', type, id)).toList();
    final results = await Future.wait(
      capable.map((a) => fetchStreams(a, type, id).catchError(
            (_) => <StreamItem>[],
          )),
    );
    final all = <StreamItem>[];
    for (final list in results) {
      all.addAll(list);
    }
    // Playable first, then external, then torrent-only.
    all.sort((a, b) => _rank(a).compareTo(_rank(b)));
    return all;
  }

  static int _rank(StreamItem s) {
    if (s.isPlayable) return 0;
    if (s.isExternal || s.isYouTube) return 1;
    return 2;
  }
}

class AddonException implements Exception {
  final String message;
  const AddonException(this.message);

  @override
  String toString() => message;
}
