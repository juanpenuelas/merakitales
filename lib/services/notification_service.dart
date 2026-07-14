import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> requestPermissionsAndSubscribe() async {
    // 1. Request Permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized || 
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted permission');
      await _subscribeToTopicBasedOnLanguage();
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  Future<void> _subscribeToTopicBasedOnLanguage() async {
    if (kIsWeb) return;

    // Get language code (es or en)
    final String deviceLanguage = ui.PlatformDispatcher.instance.locale.languageCode;
    final String languageCode = deviceLanguage == 'es' ? 'es' : 'en';
    final String topicName = 'new_tales_$languageCode';
    
    try {
      await _fcm.subscribeToTopic(topicName);
      debugPrint('Subscribed to topic: $topicName');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }
}
