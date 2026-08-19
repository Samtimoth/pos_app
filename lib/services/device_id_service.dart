import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Generates and persists a stable per-install device identifier,
/// used by the backend to count how many distinct devices use each business.
class DeviceIdService {
  static const _prefsKey = 'device_id';

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsKey);
    if (id == null || id.isEmpty) {
      id = _generateId();
      await prefs.setString(_prefsKey, id);
    }
    return id;
  }

  static String getDeviceName() {
    if (kIsWeb) return 'Web';
    try {
      final os = Platform.operatingSystem;
      return os.isEmpty ? 'Unknown' : os[0].toUpperCase() + os.substring(1);
    } catch (_) {
      return 'Unknown';
    }
  }

  static String _generateId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
