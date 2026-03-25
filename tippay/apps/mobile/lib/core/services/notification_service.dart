import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  final Dio _dio;
  FirebaseMessaging? _messaging;
  bool _initialized = false;

  NotificationService(this._dio);

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _messaging = FirebaseMessaging.instance;

      // Request permission (iOS / Android 13+)
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      _initialized = true;
    } catch (e) {
      // Firebase not configured — skip silently
      debugPrint('[FCM] Init failed (Firebase not configured?): $e');
    }
  }

  /// Get FCM token and register it with the backend.
  Future<void> registerToken() async {
    if (_messaging == null) return;
    try {
      final token = await _messaging!.getToken();
      if (token == null) return;

      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      await _dio.post(ApiConstants.registerFcmToken, data: {
        'token': token,
        'platform': platform,
      });
      debugPrint('[FCM] Token registered');

      // Refresh token when it rotates
      _messaging!.onTokenRefresh.listen((newToken) async {
        try {
          await _dio.post(ApiConstants.registerFcmToken, data: {
            'token': newToken,
            'platform': platform,
          });
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  /// Deregister token on logout.
  Future<void> removeToken() async {
    if (_messaging == null) return;
    try {
      await _dio.delete(ApiConstants.removeFcmToken);
      await _messaging!.deleteToken();
    } catch (_) {}
  }

  /// Listen for foreground messages. Call [onMessage] with the notification.
  void listenForeground(void Function(String title, String body, String? screen) onMessage) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        final screen = message.data['screen'] as String?;
        onMessage(
          notification.title ?? 'Fliq',
          notification.body ?? '',
          screen,
        );
      }
    });
  }

  /// Handle notification tap from terminated / background state.
  void listenTaps(void Function(String screen) onTap) {
    // App opened from terminated state via notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        final screen = message.data['screen'] as String?;
        if (screen != null) onTap(screen);
      }
    });

    // App opened from background state via notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final screen = message.data['screen'] as String?;
      if (screen != null) onTap(screen);
    });
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(dioProvider));
});
