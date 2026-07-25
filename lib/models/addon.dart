import 'dart:convert';

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return const [];
}

/// A resource declared by an addon manifest. Manifests may declare resources
/// as plain strings ("catalog") or as objects with types/idPrefixes.
class AddonResource {
  final String name;
  final List<String> types;
  final List<String> idPrefixes;

  const AddonResource({
    required this.name,
    this.types = const [],
    this.idPrefixes = const [],
  });

  factory AddonResource.fromJson(dynamic json) {
    if (json is String) return AddonResource(name: json);
    final map = json as Map<String, dynamic>;
    return AddonResource(
      name: (map['name'] ?? '').toString(),
      types: _stringList(map['types']),
      idPrefixes: _stringList(map['idPrefixes']),
    );
  }
}

/// One "extra" parameter supported by a catalog (search, genre, skip...).
class CatalogExtra {
  final String name;
  final bool isRequired;
  final List<String> options;

  const CatalogExtra({
    required this.name,
    this.isRequired = false,
    this.options = const [],
  });

  factory CatalogExtra.fromJson(Map<String, dynamic> json) {
    return CatalogExtra(
      name: (json['name'] ?? '').toString(),
      isRequired: json['isRequired'] == true,
      options: _stringList(json['options']),
    );
  }
}

/// A catalog exposed by an addon (e.g. movie/top, series/top).
class AddonCatalog {
  final String type;
  final String id;
  final String name;
  final List<CatalogExtra> extra;

  const AddonCatalog({
    required this.type,
    required this.id,
    required this.name,
    this.extra = const [],
  });

  factory AddonCatalog.fromJson(Map<String, dynamic> json) {
    final extras = <CatalogExtra>[];
    if (json['extra'] is List) {
      for (final e in (json['extra'] as List)) {
        if (e is Map<String, dynamic>) extras.add(CatalogExtra.fromJson(e));
      }
    }
    // Legacy manifest format: extraSupported / extraRequired string lists.
    final legacyRequired = _stringList(json['extraRequired']).toSet();
    for (final name in _stringList(json['extraSupported'])) {
      if (!extras.any((x) => x.name == name)) {
        extras.add(CatalogExtra(
          name: name,
          isRequired: legacyRequired.contains(name),
        ));
      }
    }
    return AddonCatalog(
      type: (json['type'] ?? '').toString(),
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['id'] ?? '').toString(),
      extra: extras,
    );
  }

  /// True when the catalog cannot be fetched without extra params
  /// (e.g. a search-only catalog) — those are skipped on Home.
  bool get requiresExtra => extra.any((e) => e.isRequired);

  bool get supportsSearch => extra.any((e) => e.name == 'search');

  bool get supportsSkip => extra.any((e) => e.name == 'skip');
}

/// A parsed addon manifest.
class AddonManifest {
  final String id;
  final String version;
  final String name;
  final String description;
  final String? logo;
  final String? background;
  final List<String> types;
  final List<AddonResource> resources;
  final List<AddonCatalog> catalogs;
  final List<String> idPrefixes;
  final Map<String, dynamic> raw;

  const AddonManifest({
    required this.id,
    required this.version,
    required this.name,
    required this.description,
    this.logo,
    this.background,
    this.types = const [],
    this.resources = const [],
    this.catalogs = const [],
    this.idPrefixes = const [],
    this.raw = const {},
  });

  factory AddonManifest.fromJson(Map<String, dynamic> json) {
    final resources = <AddonResource>[];
    if (json['resources'] is List) {
      for (final r in (json['resources'] as List)) {
        resources.add(AddonResource.fromJson(r));
      }
    }
    final catalogs = <AddonCatalog>[];
    if (json['catalogs'] is List) {
      for (final c in (json['catalogs'] as List)) {
        if (c is Map<String, dynamic>) catalogs.add(AddonCatalog.fromJson(c));
      }
    }
    return AddonManifest(
      id: (json['id'] ?? '').toString(),
      version: (json['version'] ?? '0.0.0').toString(),
      name: (json['name'] ?? 'Unknown addon').toString(),
      description: (json['description'] ?? '').toString(),
      logo: json['logo']?.toString(),
      background: json['background']?.toString(),
      types: _stringList(json['types']),
      resources: resources,
      catalogs: catalogs,
      idPrefixes: _stringList(json['idPrefixes']),
      raw: json,
    );
  }
}

/// An installed addon: its transport URL plus parsed manifest.
class Addon {
  final String transportUrl; // ends with /manifest.json
  final AddonManifest manifest;

  const Addon({required this.transportUrl, required this.manifest});

  String get baseUrl =>
      transportUrl.replaceAll(RegExp(r'/manifest\.json/?$'), '');

  String get name => manifest.name;

  /// Whether this addon can serve [resource] (catalog/meta/stream/subtitles)
  /// for the given content [type] and item [id].
  bool hasResource(String resource, String type, String id) {
    for (final r in manifest.resources) {
      if (r.name != resource) continue;
      final types = r.types.isNotEmpty ? r.types : manifest.types;
      if (types.isNotEmpty && !types.contains(type)) continue;
      final prefixes =
          r.idPrefixes.isNotEmpty ? r.idPrefixes : manifest.idPrefixes;
      if (prefixes.isNotEmpty && !prefixes.any((p) => id.startsWith(p))) {
        continue;
      }
      return true;
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
        'transportUrl': transportUrl,
        'manifest': manifest.raw,
      };

  factory Addon.fromJson(Map<String, dynamic> json) => Addon(
        transportUrl: json['transportUrl'] as String,
        manifest: AddonManifest.fromJson(
            (json['manifest'] as Map).cast<String, dynamic>()),
      );

  String encode() => jsonEncode(toJson());

  factory Addon.decode(String source) =>
      Addon.fromJson((jsonDecode(source) as Map).cast<String, dynamic>());
}
