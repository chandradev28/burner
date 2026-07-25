import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/addon.dart';
import '../models/meta.dart';
import '../services/addon_client.dart';

/// One horizontal rail on the Home screen.
class CatalogRow {
  final Addon addon;
  final AddonCatalog catalog;
  final List<MetaItem> items;

  const CatalogRow({
    required this.addon,
    required this.catalog,
    required this.items,
  });

  String get title {
    final type = catalog.type == 'movie'
        ? 'Movies'
        : catalog.type == 'series'
            ? 'Series'
            : catalog.type;
    final name = catalog.name.trim();
    if (name.isEmpty) return type;
    // Avoid "Top Top" style titles.
    if (name.toLowerCase().contains(catalog.type.toLowerCase())) return name;
    return '$name \u2022 $type';
  }
}

/// Loads home-screen catalogs (rails + hero items) from installed addons.
class CatalogProvider extends ChangeNotifier {
  bool _loading = false;
  String? _error;
  final List<CatalogRow> _rows = [];
  final List<MetaItem> _heroItems = [];

  bool get loading => _loading;
  String? get error => _error;
  List<CatalogRow> get rows => List.unmodifiable(_rows);
  List<MetaItem> get heroItems => List.unmodifiable(_heroItems);

  Future<void> loadHome(List<Addon> addons, {bool force = false}) async {
    if (_loading) return;
    if (_rows.isNotEmpty && !force) return;

    _loading = true;
    _error = null;
    notifyListeners();

    final futures = <Future<CatalogRow?>>[];
    for (final addon in addons) {
      final catalogs = addon.manifest.catalogs
          .where((c) => !c.requiresExtra)
          .take(BurnerConstants.maxRowsPerAddon);
      for (final catalog in catalogs) {
        futures.add(_loadRow(addon, catalog));
      }
    }

    final results = await Future.wait(futures);
    _rows
      ..clear()
      ..addAll(results.whereType<CatalogRow>().where((r) => r.items.isNotEmpty));

    _heroItems
      ..clear()
      ..addAll(_pickHeroItems());

    if (_rows.isEmpty) {
      _error = addons.isEmpty
          ? 'No addons installed. Add a Stremio addon to get started.'
          : 'Could not load catalogs. Check your connection and pull to refresh.';
    }

    _loading = false;
    notifyListeners();
  }

  Future<CatalogRow?> _loadRow(Addon addon, AddonCatalog catalog) async {
    try {
      final items = await AddonClient.fetchCatalog(addon, catalog);
      return CatalogRow(
        addon: addon,
        catalog: catalog,
        items: items.take(BurnerConstants.maxItemsPerRow).toList(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Featured items for the hero carousel: top items that have artwork,
  /// alternating across rows for variety.
  List<MetaItem> _pickHeroItems() {
    final picked = <MetaItem>[];
    final seen = <String>{};
    var index = 0;
    while (picked.length < BurnerConstants.heroItemCount) {
      var added = false;
      for (final row in _rows) {
        if (index >= row.items.length) continue;
        final item = row.items[index];
        final art = item.background ?? item.poster;
        if (art == null || !seen.add('${item.type}:${item.id}')) continue;
        picked.add(item);
        added = true;
        if (picked.length >= BurnerConstants.heroItemCount) break;
      }
      if (!added) break;
      index++;
    }
    return picked;
  }
}
