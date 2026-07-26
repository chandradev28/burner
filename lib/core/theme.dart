import 'package:flutter/material.dart';

import 'skins.dart';

/// HBO Max inspired palette: near-black backgrounds with a purple->blue
/// brand gradient and soft light-gray typography.
///
/// This is the default (HBO Max) palette only. Live UI colors come from the
/// active [SkinData] - see `lib/core/skins.dart`.
class BurnerColors {
  BurnerColors._();

  static const Color bg = Color(0xFF0A0A12);
  static const Color surface = Color(0xFF12121D);
  static const Color card = Color(0xFF1A1A28);
  static const Color stroke = Color(0xFF2A2A3C);

  static const Color purple = Color(0xFF8B2DF0);
  static const Color deepPurple = Color(0xFF5A2DE0);
  static const Color blue = Color(0xFF3C6FF5);

  static const Color textPrimary = Color(0xFFF5F5FA);
  static const Color textSecondary = Color(0xFFA7A7BC);
  static const Color danger = Color(0xFFE5484D);

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9B4DFF), Color(0xFF5A2DE0), Color(0xFF3C6FF5)],
  );

  static const LinearGradient heroOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC0A0A12), Color(0xFF0A0A12)],
    stops: [0.30, 0.78, 1.0],
  );
}

/// Default theme (HBO Max skin). The live app theme is built per-skin by
/// [buildSkinTheme]; this remains for tooling / fallbacks.
ThemeData buildBurnerTheme() => buildSkinTheme(SkinData.hbo);
