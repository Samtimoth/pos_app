import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> saveString(String key, String value) =>
      _prefs.setString(key, value);
  static String? getString(String key) => _prefs.getString(key);

  static Future<void> saveInt(String key, int value) =>
      _prefs.setInt(key, value);
  static int? getInt(String key) => _prefs.getInt(key);

  static Future<void> saveBool(String key, bool value) =>
      _prefs.setBool(key, value);
  static bool? getBool(String key) => _prefs.getBool(key);

  static Future<void> remove(String key) => _prefs.remove(key);

  static Future<void> removeMany(Iterable<String> keys) async {
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  static Future<void> clearSession() => removeMany(const [
    'server_url',
    'user_id',
    'username',
    'fullname',
    'global_role',
    'role',
    'business_id',
    'branch_id',
    'selected_business_id',
    'selected_branch_id',
  ]);

  static Future<void> clear() => _prefs.clear();
}
