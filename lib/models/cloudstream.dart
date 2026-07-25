import 'dart:convert';

/// A single CloudStream provider plugin (`.cs3`) declared by a repo.
class CsPlugin {
  final String internalName;
  final String? name;
  final String? description;
  final String url;
  final String? iconUrl;
  final String? language;
  final List<String> tvTypes;
  final int status;
  final int? version;
  final List<String> authors;

  const CsPlugin({
    required this.internalName,
    required this.url,
    this.name,
    this.description,
    this.iconUrl,
    this.language,
    this.tvTypes = const [],
    this.status = 1,
    this.version,
    this.authors = const [],
  });

  factory CsPlugin.fromJson(Map<String, dynamic> json) {
    return CsPlugin(
      internalName: (json['internalName'] ?? json['name'] ?? '').toString(),
      name: json['name']?.toString(),
      description: json['description']?.toString(),
      url: (json['url'] ?? '').toString(),
      iconUrl: json['iconUrl']?.toString(),
      language: json['language']?.toString(),
      tvTypes: json['tvTypes'] is List
          ? (json['tvTypes'] as List).map((e) => e.toString()).toList()
          : const [],
      status: json['status'] is int ? json['status'] as int : 1,
      version: json['version'] is int ? json['version'] as int : null,
      authors: json['authors'] is List
          ? (json['authors'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'internalName': internalName,
        'name': name,
        'description': description,
        'url': url,
        'iconUrl': iconUrl,
        'language': language,
        'tvTypes': tvTypes,
        'status': status,
        'version': version,
        'authors': authors,
      };

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : internalName;

  /// status 1 = working, 0 = down, 2 = slow, 3 = beta (CloudStream convention).
  bool get isDown => status == 0;

  bool get supportsMovies =>
      tvTypes.isEmpty || tvTypes.any((t) => t.toLowerCase().contains('movie'));

  bool get supportsSeries => tvTypes.isEmpty ||
      tvTypes.any((t) {
        final v = t.toLowerCase();
        return v.contains('tv') || v.contains('series') || v.contains('anime');
      });
}

/// A CloudStream repository (`repo.json`) plus every plugin it lists.
class CsRepo {
  final String url;
  final String name;
  final String? description;
  final List<String> pluginLists;
  final List<CsPlugin> plugins;
  final Set<String> enabledPlugins;

  const CsRepo({
    required this.url,
    required this.name,
    this.description,
    this.pluginLists = const [],
    this.plugins = const [],
    this.enabledPlugins = const {},
  });

  CsRepo copyWith({List<CsPlugin>? plugins, Set<String>? enabledPlugins}) {
    return CsRepo(
      url: url,
      name: name,
      description: description,
      pluginLists: pluginLists,
      plugins: plugins ?? this.plugins,
      enabledPlugins: enabledPlugins ?? this.enabledPlugins,
    );
  }

  bool isEnabled(CsPlugin p) =>
      enabledPlugins.isEmpty || enabledPlugins.contains(p.internalName);

  List<CsPlugin> get activePlugins =>
      plugins.where((p) => !p.isDown && isEnabled(p)).toList();

  Map<String, dynamic> toJson() => {
        'url': url,
        'name': name,
        'description': description,
        'pluginLists': pluginLists,
        'plugins': plugins.map((p) => p.toJson()).toList(),
        'enabledPlugins': enabledPlugins.toList(),
      };

  factory CsRepo.fromJson(Map<String, dynamic> json) => CsRepo(
        url: (json['url'] ?? '').toString(),
        name: (json['name'] ?? 'Repository').toString(),
        description: json['description']?.toString(),
        pluginLists: json['pluginLists'] is List
            ? (json['pluginLists'] as List).map((e) => e.toString()).toList()
            : const [],
        plugins: json['plugins'] is List
            ? (json['plugins'] as List)
                .whereType<Map>()
                .map((e) => CsPlugin.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
        enabledPlugins: json['enabledPlugins'] is List
            ? (json['enabledPlugins'] as List).map((e) => e.toString()).toSet()
            : <String>{},
      );

  String encode() => jsonEncode(toJson());

  static CsRepo decode(String raw) =>
      CsRepo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
