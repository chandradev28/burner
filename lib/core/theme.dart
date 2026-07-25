import 'package:flutter/material.dart';

/// HBO Max inspired palette: near-black backgrounds with a purple->blue
/// brand gradient and soft light-gray typography.
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

ThemeData buildBurnerTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: BurnerColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BurnerColors.purple,
      brightness: Brightness.dark,
      surface: BurnerColors.surface,
    ),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: BurnerColors.textPrimary,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: BurnerColors.textPrimary,
      displayColor: BurnerColors.textPrimary,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xF00A0A12),
      selectedItemColor: BurnerColors.textPrimary,
      unselectedItemColor: BurnerColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: BurnerColors.card,
      contentTextStyle: const TextStyle(color: BurnerColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: BurnerColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BurnerColors.card,
      hintStyle: const TextStyle(color: BurnerColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
    dividerColor: BurnerColors.stroke,
    tabBarTheme: const TabBarThemeData(
      labelColor: BurnerColors.textPrimary,
      unselectedLabelColor: BurnerColors.textSecondary,
      indicatorColor: BurnerColors.purple,
    ),
  );
}
