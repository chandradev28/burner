import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cloudstream.dart';

/// Client for the CloudStream repository format.
///
/// A repo is a `repo.json` describing the repository plus one or more
/// `pluginLists` URLs, each returning an array of provider plugins.
/// See https://cloudstream.miraheze.org/wiki/Main_Page
class CloudStreamClient {
  CloudStreamClient._();

  static const Duration _timeout = Duration(seconds: 20);

  /// Accepts a raw repo.json URL, a GitHub page URL, or a `cloudstreamrepo://`
  /// deep link and normalizes it to a fetchable JSON URL.
  static String normalizeRepoUrl(String input) {
    var url = input.trim();
    if (url.startsWith('cloudstreamrepo://')) {
      url = url.replaceFirst('cloudstreamrepo://', 'https://');
    }
    // github.com/user/repo/blob/branch/file.json -> raw.githubusercontent.com
    if (url.contains('github.com') && url.contains('/blob/')) {
      url = url
          .replaceFirst('github.com', 'raw.githubusercontent.com')
          .replaceFirst('/blob/', '/');
    }
    return url;
  }

  /// Fetches a repository and every plugin it lists.
  static Future<CsRepo> fetchRepo(String rawUrl) async {
    final url = normalizeRepoUrl(rawUrl);
    final response = await http.get(Uri.parse(url)).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Repository returned HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw Exception('Not a valid CloudStream repository');
    }
    final json = decoded.cast<String, dynamic>();

    final pluginLists = json['pluginLists'] is List
        ? (json['pluginLists'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final plugins = await _fetchPluginLists(pluginLists);

    return CsRepo(
      url: url,
      name: (json['name'] ?? 'CloudStream repo').toString(),
      description: json['description']?.toString(),
      pluginLists: pluginLists,
      plugins: plugins,
      enabledPlugins: plugins.map((p) => p.internalName).toSet(),
    );
  }

  /// Re-fetches only the plugin lists of an existing repo.
  static Future<CsRepo> refresh(CsRepo repo) async {
    final plugins = await _fetchPluginLists(repo.pluginLists);
    if (plugins.isEmpty) return repo;
    // Keep user toggles for plugins that still exist.
    final names = plugins.map((p) => p.internalName).toSet();
    final enabled = repo.enabledPlugins.isEmpty
        ? names
        : repo.enabledPlugins.where(names.contains).toSet();
    return repo.copyWith(plugins: plugins, enabledPlugins: enabled);
  }

  static Future<List<CsPlugin>> _fetchPluginLists(List<String> lists) async {
    final results = await Future.wait(
      lists.map((listUrl) async {
        try {
          final res = await http
              .get(Uri.parse(normalizeRepoUrl(listUrl)))
              .timeout(_timeout);
          if (res.statusCode != 200) return <CsPlugin>[];
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          if (data is! List) return <CsPlugin>[];
          return data
              .whereType<Map>()
              .map((e) => CsPlugin.fromJson(e.cast<String, dynamic>()))
              .where((p) => p.internalName.isNotEmpty)
              .toList();
        } catch (_) {
          return <CsPlugin>[];
        }
      }),
    );

    // Merge + de-duplicate by internalName, preferring the highest version.
    final merged = <String, CsPlugin>{};
    for (final list in results) {
      for (final plugin in list) {
        final existing = merged[plugin.internalName];
        if (existing == null ||
            (plugin.version ?? 0) > (existing.version ?? 0)) {
          merged[plugin.internalName] = plugin;
        }
      }
    }
    final all = merged.values.toList()
      ..sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return all;
  }
}
