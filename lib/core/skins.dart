import 'package:flutter/material.dart';

/// The three shipped app-wide UI skins.
enum SkinId { hbo, netflix, appleTv }

/// How the global footer navigation renders.
enum NavStyle {
  /// Floating translucent pill (HBO Max).
  glassPill,

  /// Edge-to-edge opaque bar with a hairline top border (Netflix).
  flatBar,

  /// Edge-to-edge frosted blur tab bar (Apple TV).
  frostedTab,
}

/// How the featured carousel renders.
enum HeroStyle {
  /// Landscape backdrop, left aligned title + gradient fade.
  cinematicGradient,

  /// Tall portrait key art, centered logo, genre dot list.
  netflixPortrait,

  /// Inset rounded 16:9 card with generous margins.
  appleWideCard,
}

/// How the home screen header renders.
enum HomeHeaderStyle {
  /// No header at all - hero runs under the status bar.
  minimal,

  /// Working All / Movies / Series filter chips.
  netflixChips,

  /// Large "Watch Now" title.
  appleLargeTitle,
}

/// Every visual token the app reads. Swapping a [SkinData] swaps the whole UI:
/// colors, typography, corner radii, nav bar shape, hero layout, buttons.
@immutable
class SkinData {
  final SkinId id;
  final String name;
  final String description;

  // Palette
  final Color bg;
  final Color surface;
  final Color card;
  final Color stroke;
  final Color accent;
  final Color accentAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color danger;

  final LinearGradient brand;
  final LinearGradient heroOverlay;

  // Geometry
  final double posterRadius;
  final double cardRadius;
  final double buttonRadius;

  // Typography
  final bool uppercaseRowTitles;
  final double rowTitleSize;
  final FontWeight rowTitleWeight;
  final double rowTitleSpacing;

  // Layout behaviour
  final NavStyle navStyle;
  final HeroStyle heroStyle;
  final HomeHeaderStyle headerStyle;

  // Buttons
  final bool gradientPrimaryButton;
  final Color primaryButtonColor;
  final Color primaryButtonTextColor;

  /// Footer labels: Home / Search / Library / Profile.
  final List<String> navLabels;

  const SkinData({
    required this.id,
    required this.name,
    required this.description,
    required this.bg,
    required this.surface,
    required this.card,
    required this.stroke,
    required this.accent,
    required this.accentAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.danger,
    required this.brand,
    required this.heroOverlay,
    required this.posterRadius,
    required this.cardRadius,
    required this.buttonRadius,
    required this.uppercaseRowTitles,
    required this.rowTitleSize,
    required this.rowTitleWeight,
    required this.rowTitleSpacing,
    required this.navStyle,
    required this.heroStyle,
    required this.headerStyle,
    required this.gradientPrimaryButton,
    required this.primaryButtonColor,
    required this.primaryButtonTextColor,
    required this.navLabels,
  });

  String get key => id.name;

  bool get isHbo => id == SkinId.hbo;
  bool get isNetflix => id == SkinId.netflix;
  bool get isAppleTv => id == SkinId.appleTv;

  BorderRadius get posterBorderRadius => BorderRadius.circular(posterRadius);
  BorderRadius get cardBorderRadius => BorderRadius.circular(cardRadius);
  BorderRadius get buttonBorderRadius => BorderRadius.circular(buttonRadius);

  /// ---------------------------------------------------------------- HBO Max
  static const SkinData hbo = SkinData(
    id: SkinId.hbo,
    name: 'HBO Max',
    description:
        'Purple-to-blue gradients, floating liquid-glass tab bar, cinematic wide hero.',
    bg: Color(0xFF0A0A12),
    surface: Color(0xFF12121D),
    card: Color(0xFF1A1A28),
    stroke: Color(0xFF2A2A3C),
    accent: Color(0xFF8B2DF0),
    accentAlt: Color(0xFF3C6FF5),
    textPrimary: Color(0xFFF5F5FA),
    textSecondary: Color(0xFFA7A7BC),
    danger: Color(0xFFE5484D),
    brand: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF9B4DFF), Color(0xFF5A2DE0), Color(0xFF3C6FF5)],
    ),
    heroOverlay: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Color(0xCC0A0A12), Color(0xFF0A0A12)],
      stops: [0.30, 0.78, 1.0],
    ),
    posterRadius: 8,
    cardRadius: 12,
    buttonRadius: 6,
    uppercaseRowTitles: false,
    rowTitleSize: 17,
    rowTitleWeight: FontWeight.w700,
    rowTitleSpacing: 0.2,
    navStyle: NavStyle.glassPill,
    heroStyle: HeroStyle.cinematicGradient,
    headerStyle: HomeHeaderStyle.minimal,
    gradientPrimaryButton: true,
    primaryButtonColor: Color(0xFF8B2DF0),
    primaryButtonTextColor: Colors.white,
    navLabels: ['Home', 'Search', 'My Stuff', 'Profile'],
  );

  /// ---------------------------------------------------------------- Netflix
  static const SkinData netflix = SkinData(
    id: SkinId.netflix,
    name: 'Netflix',
    description:
        'Pure black, signature red, sharp corners, portrait key-art hero and a flat tab bar.',
    bg: Color(0xFF000000),
    surface: Color(0xFF141414),
    card: Color(0xFF1F1F1F),
    stroke: Color(0xFF2B2B2B),
    accent: Color(0xFFE50914),
    accentAlt: Color(0xFFB0060F),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB3B3B3),
    danger: Color(0xFFE50914),
    brand: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE50914), Color(0xFFB0060F)],
    ),
    heroOverlay: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x66000000), Color(0x00000000), Color(0xE6000000), Color(0xFF000000)],
      stops: [0.0, 0.32, 0.80, 1.0],
    ),
    posterRadius: 4,
    cardRadius: 4,
    buttonRadius: 4,
    uppercaseRowTitles: false,
    rowTitleSize: 16.5,
    rowTitleWeight: FontWeight.w700,
    rowTitleSpacing: 0,
    navStyle: NavStyle.flatBar,
    heroStyle: HeroStyle.netflixPortrait,
    headerStyle: HomeHeaderStyle.netflixChips,
    gradientPrimaryButton: false,
    primaryButtonColor: Color(0xFFFFFFFF),
    primaryButtonTextColor: Color(0xFF000000),
    navLabels: ['Home', 'Search', 'My List', 'Me'],
  );

  /// --------------------------------------------------------------- Apple TV
  static const SkinData appleTv = SkinData(
    id: SkinId.appleTv,
    name: 'Apple TV',
    description:
        'Near-black graphite, blue accent, big rounded cards, frosted tab bar and large titles.',
    bg: Color(0xFF000000),
    surface: Color(0xFF0E0E10),
    card: Color(0xFF1C1C1E),
    stroke: Color(0xFF2C2C2E),
    accent: Color(0xFF0A84FF),
    accentAlt: Color(0xFF64D2FF),
    textPrimary: Color(0xFFF2F2F7),
    textSecondary: Color(0xFF98989D),
    danger: Color(0xFFFF453A),
    brand: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
    ),
    heroOverlay: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x00000000), Color(0x99000000), Color(0xF2000000)],
      stops: [0.35, 0.75, 1.0],
    ),
    posterRadius: 14,
    cardRadius: 18,
    buttonRadius: 22,
    uppercaseRowTitles: false,
    rowTitleSize: 20,
    rowTitleWeight: FontWeight.w700,
    rowTitleSpacing: -0.3,
    navStyle: NavStyle.frostedTab,
    heroStyle: HeroStyle.appleWideCard,
    headerStyle: HomeHeaderStyle.appleLargeTitle,
    gradientPrimaryButton: false,
    primaryButtonColor: Color(0xFFFFFFFF),
    primaryButtonTextColor: Color(0xFF000000),
    navLabels: ['Watch Now', 'Search', 'Library', 'Settings'],
  );

  static const List<SkinData> all = <SkinData>[hbo, netflix, appleTv];

  static SkinData byKey(String? key) {
    for (final skin in all) {
      if (skin.key == key) return skin;
    }
    return hbo;
  }
}

/// Builds a full [ThemeData] from a skin so every Material surface
/// (scaffolds, app bars, dialogs, inputs, tabs, snackbars, spinners)
/// follows the selected UI without per-screen work.
ThemeData buildSkinTheme(SkinData s) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: s.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: s.accent,
      brightness: Brightness.dark,
      primary: s.accent,
      secondary: s.accentAlt,
      surface: s.surface,
      error: s.danger,
    ),
  );

  return base.copyWith(
    canvasColor: s.bg,
    cardColor: s.card,
    dividerColor: s.stroke,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: s.isAppleTv,
      foregroundColor: s.textPrimary,
      titleTextStyle: TextStyle(
        color: s.textPrimary,
        fontSize: s.isAppleTv ? 17 : 20,
        fontWeight: s.isAppleTv ? FontWeight.w600 : FontWeight.w800,
        letterSpacing: s.isNetflix ? 0.2 : 0,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: s.textPrimary,
      displayColor: s.textPrimary,
    ),
    iconTheme: IconThemeData(color: s.textPrimary),
    listTileTheme: ListTileThemeData(
      iconColor: s.accent,
      textColor: s.textPrimary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: s.accent),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: s.bg,
      selectedItemColor: s.isAppleTv ? s.accent : s.textPrimary,
      unselectedItemColor: s.textSecondary,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: s.card,
      contentTextStyle: TextStyle(color: s.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: s.cardBorderRadius),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(s.isNetflix ? 6 : 16),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(s.isNetflix ? 8 : 20),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.card,
      hintStyle: TextStyle(color: s.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(s.isAppleTv ? 14 : (s.isNetflix ? 4 : 10)),
        borderSide: BorderSide.none,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: s.textPrimary,
      unselectedLabelColor: s.textSecondary,
      indicatorColor: s.accent,
    ),
  );
}
