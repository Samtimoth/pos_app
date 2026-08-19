import 'package:shared_preferences/shared_preferences.dart';

/// Backend base URL. Resolution order:
/// 1. A URL saved locally via [setOverride] (e.g. from a settings screen) —
///    lets testers switch servers without rebuilding the app.
/// 2. `--dart-define=API_BASE_URL=...` supplied at build time.
/// 3. A localhost placeholder, which will simply fail to connect until one
///    of the above is configured — it is intentionally not a real machine's
///    Wi-Fi IP, since that would only work on the original developer's network.
class ApiConfig {
  static const _prefsKey = 'api_base_url_override';

  static const _buildTimeUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://focustec.co.tz/kukupaja/api',
  );

  static String _current = _buildTimeUrl;

  static String get baseUrl => _current;

  static String get adminUrl => _current.replaceFirst(RegExp(r'/api/?$'), '/admin/');

  /// Loads any previously saved override. Call once during app startup.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _current = saved.trim();
    }
  }

  /// Persists a new base URL (e.g. `http://192.168.1.20/kukupaja_backend/api`)
  /// so it survives app restarts, without needing a rebuild.
  static Future<void> setOverride(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_prefsKey);
      _current = _buildTimeUrl;
      return;
    }
    await prefs.setString(_prefsKey, trimmed);
    _current = trimmed;
  }

  static Future<void> resetToBuildDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _current = _buildTimeUrl;
  }
}
