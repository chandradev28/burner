import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/addon.dart';
import '../services/addon_client.dart';
import '../services/storage_service.dart';

/// Holds the list of installed Stremio addons.
class AddonProvider extends ChangeNotifier {
  final List<Addon> _addons = [];
  bool _initialized = false;
  bool _loading = false;

  List<Addon> get addons => List.unmodifiable(_addons);
  bool get initialized => _initialized;
  bool get loading => _loading;

  /// Loads persisted addons; installs the bundled defaults on first run.
  Future<void> init() async {
    if (_initialized) return;
    _loading = true;
    notifyListeners();

    final stored = await StorageService.getStringList(StorageService.addonsKey);
    _addons.clear();
    for (final encoded in stored) {
      try {
        _addons.add(Addon.decode(encoded));
      } catch (_) {
        // Skip corrupted entries.
      }
    }

    if (_addons.isEmpty) {
      for (final url in BurnerConstants.defaultAddons) {
        try {
          _addons.add(await AddonClient.fetchAddon(url));
        } catch (_) {
          // Offline or addon unreachable; user can add it later.
        }
      }
      await _persist();
    } else {
      // Refresh manifests in the background (best effort).
      _refreshManifests();
    }

    _initialized = true;
    _loading = false;
    notifyListeners();
  }

  Future<void> _refreshManifests() async {
    var changed = false;
    for (var i = 0; i < _addons.length; i++) {
      try {
        final fresh = await AddonClient.fetchAddon(_addons[i].transportUrl);
        if (fresh.manifest.version != _addons[i].manifest.version) {
          _addons[i] = fresh;
          changed = true;
        }
      } catch (_) {
        // Keep the cached manifest.
      }
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  /// Installs an addon from any manifest URL. Throws on failure.
  Future<Addon> addAddon(String manifestUrl) async {
    final addon = await AddonClient.fetchAddon(manifestUrl);
    _addons.removeWhere((a) => a.manifest.id == addon.manifest.id);
    _addons.add(addon);
    await _persist();
    notifyListeners();
    return addon;
  }

  Future<void> removeAddon(Addon addon) async {
    _addons.removeWhere((a) => a.transportUrl == addon.transportUrl);
    await _persist();
    notifyListeners();
  }

  List<Addon> withResource(String resource, String type, String id) =>
      _addons.where((a) => a.hasResource(resource, type, id)).toList();

  Future<void> _persist() async {
    await StorageService.setStringList(
      StorageService.addonsKey,
      _addons.map((a) => a.encode()).toList(),
    );
  }
}
