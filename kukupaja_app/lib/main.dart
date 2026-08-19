import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase + push are only wired up for the real mobile targets. On desktop
  // (used for quick demos) there's no Firebase config, so skip native init to
  // avoid crashing on startup — the storefront falls back to demo data.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await Firebase.initializeApp();
      await PushNotificationService.init();
    } catch (_) {
      // Non-fatal: never let notification setup block app launch.
    }
  }
  runApp(const KukuPajaApp());
}

class KukuPajaApp extends StatelessWidget {
  const KukuPajaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, darkMode, child) => ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, language, child) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'KukuPaja',
          themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            // Only cap the width on desktop, where the OS window can be far
            // wider than a phone. On a real phone/tablet, hand the child the
            // full screen untouched so nothing here can ever affect layout.
            const isDesktop = {
              TargetPlatform.windows,
              TargetPlatform.macOS,
              TargetPlatform.linux,
            };
            if (!isDesktop.contains(defaultTargetPlatform)) return child!;
            final size = MediaQuery.sizeOf(context);
            return Container(
              color: const Color(0xFF11171A),
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: size.width < 480 ? size.width : 480,
                height: size.height,
                child: child,
              ),
            );
          },
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: green),
            scaffoldBackgroundColor: const Color(0xFFF7F4F1),
            useMaterial3: true,
            pageTransitionsTheme: appPageTransitionsTheme,
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: green,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF17110C),
            cardTheme: const CardThemeData(color: Color(0xFF241811)),
            navigationBarTheme: const NavigationBarThemeData(
              backgroundColor: Color(0xFF1F150E),
              indicatorColor: Color(0xFF6E3111),
            ),
            useMaterial3: true,
            pageTransitionsTheme: appPageTransitionsTheme,
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Color(0xFF261A12),
            ),
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
