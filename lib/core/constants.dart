/// App-wide defaults.
class BurnerConstants {
  BurnerConstants._();

  static const String appName = 'BURNER';

  /// Addons installed on first launch. Cinemeta is Stremio's official
  /// metadata addon (catalogs, meta, search) — it serves no video content.
  static const List<String> defaultAddons = <String>[
    'https://v3-cinemeta.strem.io/manifest.json',
  ];

  /// Max catalog rails pulled from each addon for the Home screen.
  static const int maxRowsPerAddon = 4;

  /// Number of items in the hero carousel.
  static const int heroItemCount = 5;

  /// Max items to show per rail.
  static const int maxItemsPerRow = 30;
}
