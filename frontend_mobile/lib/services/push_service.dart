import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class PushService {
  static bool ready = false;
  static StreamSubscription<String>? subscription;
  static Future<void> initialize() async {
    if (!const bool.fromEnvironment('FIREBASE_ENABLED')) return;
    try {
      await Firebase.initializeApp(options: const FirebaseOptions(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
        projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      ));
      ready = true;
    } catch (error) { debugPrint('Firebase initialization failed: $error'); }
  }
  static Future<void> register() async {
    if (!ready) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _send(token);
      await subscription?.cancel();
      subscription = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        try { await _send(token); } catch (error) { debugPrint('Push token update failed: $error'); }
      });
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received foreground push notification: ${message.notification?.title}');
      });
    } catch (error) { debugPrint('Push registration failed: $error'); }
  }
  static Future<void> _send(String? token) => ApiService().dio.post('/notifications/fcm-token', data: {'fcmToken': token});
  static Future<void> unregister() async {
    await subscription?.cancel();
    if (!ready) return;
    try { await _send(null); await FirebaseMessaging.instance.deleteToken(); }
    catch (error) { debugPrint('Push unregister failed: $error'); }
  }
}

