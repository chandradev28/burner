import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences with app-scoped keys.
class StorageService {
  StorageService._();

  static const String addonsKey = 'burner.addons';
  static const String watchlistKey = 'burner.watchlist';
  static const String progressKey = 'burner.progress';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<List<String>> getStringList(String key) async {
    return (await prefs).getStringList(key) ?? const [];
  }

  static Future<void> setStringList(String key, List<String> value) async {
    await (await prefs).setStringList(key, value);
  }

  static Future<String?> getString(String key) async {
    return (await prefs).getString(key);
  }

  static Future<void> setString(String key, String value) async {
    await (await prefs).setString(key, value);
  }

  static Future<void> remove(String key) async {
    await (await prefs).remove(key);
  }
}
