import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/skins.dart';
import '../services/storage_service.dart';

/// Holds the selected UI skin and persists it across launches.
///
/// Changing the skin rebuilds [MaterialApp] with a new [ThemeData] and every
/// widget that reads `context.skin`, so the switch is instant and app-wide.
class SkinProvider extends ChangeNotifier {
  SkinData _skin = SkinData.hbo;
  bool _loaded = false;

  SkinData get skin => _skin;
  bool get loaded => _loaded;

  Future<void> init() async {
    final stored = await StorageService.getString(StorageService.skinKey);
    _skin = SkinData.byKey(stored);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setSkin(SkinData skin) async {
    if (skin.id == _skin.id) return;
    _skin = skin;
    notifyListeners();
    await StorageService.setString(StorageService.skinKey, skin.key);
  }
}

/// Convenience access used across the widget tree.
extension SkinContext on BuildContext {
  /// Current skin. Rebuilds this widget when the user switches UI.
  SkinData get skin => Provider.of<SkinProvider>(this).skin;

  /// Current skin without subscribing (for callbacks / one-off reads).
  SkinData get skinOnce =>
      Provider.of<SkinProvider>(this, listen: false).skin;
}
