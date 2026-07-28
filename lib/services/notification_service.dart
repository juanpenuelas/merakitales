import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Comprueba el permiso actual sin disparar ningun prompt; si ya esta
  /// autorizado (o provisional), suscribe al topic. Para re-suscripcion
  /// silenciosa de usuarios que ya habian concedido el permiso.
  Future<bool> ensureSubscribedIfAuthorized() async {
    final settings = await _fcm.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _subscribeToTopicBasedOnLanguage();
      return true;
    }
    return false;
  }

  /// Dispara el prompt del sistema y suscribe al topic si concede.
  Future<bool> requestPermissionAndSubscribe() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('NotificationService: permission granted, subscribing to topic.');
      await _subscribeToTopicBasedOnLanguage();
      return true;
    } else {
      debugPrint('NotificationService: permission declined or not accepted.');
      return false;
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
