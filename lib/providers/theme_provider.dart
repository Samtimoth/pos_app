import 'dart:async';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ThemeProvider
//  Manages dark / light theme preference with time-based auto switching.
//
//  Preference:
//    'auto'  — dark from 18:00 → 06:00, light from 06:00 → 18:00
//    'dark'  — always dark
//    'light' — always light
// ─────────────────────────────────────────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'theme_pref';

  String _pref = 'auto';
  Timer? _autoTimer;

  String get preference => _pref;

  // ── Computed: is current theme dark? ────────────────────────────────────
  bool get isDark {
    if (_pref == 'dark')  return true;
    if (_pref == 'light') return false;
    return _isNightNow();
  }

  ThemeMode get themeMode => isDark ? ThemeMode.dark : ThemeMode.light;

  // ── Night = 18:00 – 05:59 ───────────────────────────────────────────────
  static bool _isNightNow() {
    final h = DateTime.now().hour;
    return h >= 18 || h < 6;
  }

  // ── Init ─────────────────────────────────────────────────────────────────
  Future<void> load() async {
    _pref = StorageService.getString(_prefKey) ?? 'auto';
    _applyColors();
    _startAutoTimer();
    notifyListeners();
  }

  // ── Change preference ────────────────────────────────────────────────────
  Future<void> setPreference(String pref) async {
    assert(pref == 'auto' || pref == 'dark' || pref == 'light');
    _pref = pref;
    await StorageService.saveString(_prefKey, pref);
    _applyColors();
    _startAutoTimer();
    notifyListeners();
  }

  // ── Apply AppColors palette ───────────────────────────────────────────────
  void _applyColors() {
    isDark ? AppColors.applyDark() : AppColors.applyLight();
  }

  // ── Auto timer: re-check every minute when in auto mode ─────────────────
  void _startAutoTimer() {
    _autoTimer?.cancel();
    if (_pref != 'auto') return;

    // Fire at the next whole minute then every 60 seconds
    final now    = DateTime.now();
    final delay  = Duration(seconds: 60 - now.second);
    Timer(delay, () {
      if (!_isDisposed) {
        _checkAutoSwitch();
        _autoTimer = Timer.periodic(const Duration(seconds: 60), (_) {
          if (!_isDisposed) { _checkAutoSwitch(); }
        });
      }
    });
  }

  bool _isDisposed = false;

  void _checkAutoSwitch() {
    final wasD = isDark;
    _applyColors();
    if (wasD != isDark) { notifyListeners(); }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _autoTimer?.cancel();
    super.dispose();
  }
}
