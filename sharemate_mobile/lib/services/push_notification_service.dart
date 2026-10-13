import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Renders incoming FCM push messages as an actual system notification.
///
/// Firebase Messaging never draws a notification itself while the app is in
/// the foreground (on Android or iOS) — that's only true when the app is
/// backgrounded/killed. Backend messages are sent data-only (no
/// "notification" block) specifically so nothing is ever auto-displayed by
/// the OS — this service is the single place that decides whether to show
/// one, which is what lets it also skip the device of whoever triggered the
/// action (via the `exclude_uid` field) in every app state.
class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'flts_route_updates',
    'Route updates',
    description: 'Live transit alerts for your bus route',
    importance: Importance.high,
  );

  static bool _pluginInitialized = false;
  static bool _foregroundListenerRegistered = false;

  static Future<void> _initPlugin() async {
    if (_pluginInitialized) return;
    _pluginInitialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  /// Call once from the main isolate after Firebase is ready.
  static Future<void> initialize() async {
    await _initPlugin();
    if (_foregroundListenerRegistered) return;
    _foregroundListenerRegistered = true;

    // Foreground messages are never auto-displayed by the OS — show them
    // ourselves via the local-notifications plugin.
    FirebaseMessaging.onMessage.listen(showFromRemoteMessage);
  }

  /// Call from the background message handler — that runs in its own
  /// isolate, so static init state from the main isolate isn't shared and
  /// the plugin needs to be set up again here.
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    await _initPlugin();
    await showFromRemoteMessage(message);
  }

  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    // Skip the device of whoever triggered this event — e.g. don't show
    // "you left the route" to the very user who just stopped sharing.
    try {
      final excludeUid = message.data['exclude_uid'] as String?;
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (excludeUid != null &&
          excludeUid.isNotEmpty &&
          excludeUid == currentUid) {
        return;
      }
    } catch (e) {
      debugPrint('PushNotificationService: exclude_uid check failed: $e');
    }

    final title = message.data['title'] as String? ?? message.notification?.title;
    final body = message.data['body'] as String? ?? message.notification?.body;
    if (title == null && body == null) return;

    try {
      await _plugin.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('PushNotificationService: failed to show notification: $e');
    }
  }
}
