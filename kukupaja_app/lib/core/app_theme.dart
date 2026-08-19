import 'package:flutter/material.dart';

// KukuPaja brand palette — fiery orange with a gold accent, matching the
// flame logo. The variable names stay `green`/`yellow` (used across the app)
// to keep this a drop-in colour swap; only the values changed from the old
// KukuSoko green/yellow scheme.
const green = Color(0xFFE85319); // primary — fiery orange
const yellow = Color(0xFFFFB300); // accent — gold
final darkModeNotifier = ValueNotifier<bool>(false);
final languageNotifier = ValueNotifier<String>('sw');

String tr(String sw, String en) => languageNotifier.value == 'sw' ? sw : en;

String money(num value) => 'TSh ${value.toStringAsFixed(0)}';

/// A single smooth fade-forward transition used on every platform, instead
/// of each platform's mismatched default (Cupertino slide, Android zoom,
/// desktop's plain fade) so navigating feels the same everywhere.
const appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
  },
);
