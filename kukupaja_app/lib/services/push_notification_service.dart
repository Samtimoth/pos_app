import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

const _ordersChannel = AndroidNotificationChannel(
  'orders_channel',
  'Arifa za Oda',
  description: 'Arifa za oda mpya kwa admin',
  importance: Importance.high,
);

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_ordersChannel);

    await FirebaseMessaging.instance.requestPermission();

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _local.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _ordersChannel.id,
            _ordersChannel.name,
            channelDescription: _ordersChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  /// Fetches this device's FCM token and registers it against the logged-in
  /// user so the backend can push order notifications to it. Failures here
  /// are swallowed - push registration should never block login or use of
  /// the dashboard.
  static Future<void> registerToken(String authToken) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      await ApiService.registerDeviceToken(
        authToken,
        fcmToken,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (_) {
      // Non-fatal.
    }
  }
}
