import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'crm_api.dart';

/// Push notifications (Firebase Cloud Messaging) — arifa za SuperAdmin
/// (matangazo) na admin (stock/mauzo/zamu/madeni) zinazomfikia mtumiaji
/// hata app ikiwa imefungwa kabisa. Android pekee kwa sasa (google-
/// services.json ipo tu kwa Android — angalia main.dart).
class PushNotificationService {
  static bool _initialized = false;
  static String? _lastToken;

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Piga baada ya mtumiaji kuingia (login) na biashara kuchaguliwa, ili
  /// token iandikwe ikiwa na user_id/business_id sahihi. Salama kupigwa
  /// mara nyingi — haifanyi kazi mara mbili isipokuwa token imebadilika.
  static Future<void> init({
    required CrmApi crm,
    required int userId,
    int? businessId,
    void Function(RemoteMessage message)? onForegroundMessage,
  }) async {
    if (!_supported) return;
    try {
      final messaging = FirebaseMessaging.instance;
      if (!_initialized) {
        _initialized = true;
        await messaging.requestPermission(alert: true, badge: true, sound: true);
        FirebaseMessaging.onMessage.listen((message) => onForegroundMessage?.call(message));
      }
      final token = await messaging.getToken();
      if (token != null && token != _lastToken) {
        _lastToken = token;
        await crm.registerDeviceToken(userId: userId, businessId: businessId, fcmToken: token);
      }
      messaging.onTokenRefresh.listen((newToken) {
        _lastToken = newToken;
        crm.registerDeviceToken(userId: userId, businessId: businessId, fcmToken: newToken);
      });
    } catch (e) {
      debugPrint('Push notification init failed: $e');
    }
  }

  /// Piga wakati wa logout ili kifaa kisiendelee kupokea arifa za
  /// mtumiaji aliyetoka.
  static Future<void> unregister(CrmApi crm) async {
    if (!_supported || _lastToken == null) return;
    try {
      await crm.unregisterDeviceToken(_lastToken!);
    } catch (_) {}
  }

  /// Onyesho rahisi la ujumbe ulioupokea app ikiwa WAZI (foreground) —
  /// ikiwa app imefungwa, Android yenyewe inaonyesha arifa ya kawaida ya
  /// mfumo (system tray), hii haihitajiki kwa hali hiyo.
  static void showForegroundBanner(BuildContext context, RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;
    AppNotification.show(
      context,
      body.isNotEmpty ? '$title\n$body' : title,
      AppColors.accent,
      icon: Icons.notifications_active_rounded,
      duration: const Duration(seconds: 5),
    );
  }
}
