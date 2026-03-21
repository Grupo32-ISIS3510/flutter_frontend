import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:second_serving_frontend/firebase_options.dart';

import 'local_notifications_service.dart';

import '../data/services/notifications_api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationsService {
  static const int _defaultDaysBeforeExpiry = 1;

  PushNotificationsService({
    required NotificationsApiService notificationsApiService,
    required Future<String?> Function() accessTokenProvider,
    FirebaseMessaging? firebaseMessaging,
    LocalNotificationsService? localNotificationsService,
  }) : _notificationsApiService = notificationsApiService,
       _accessTokenProvider = accessTokenProvider,
       _firebaseMessagingOverride = firebaseMessaging,
       _localNotificationsService =
           localNotificationsService ?? LocalNotificationsService.instance;

  final NotificationsApiService _notificationsApiService;
  final Future<String?> Function() _accessTokenProvider;
  final FirebaseMessaging? _firebaseMessagingOverride;
  final LocalNotificationsService _localNotificationsService;
  final StreamController<String> _notificationTapController =
      StreamController<String>.broadcast();
  String? _pendingTapRoute;

  Stream<String> get onNotificationTap => _notificationTapController.stream;

  String? consumePendingTapRoute() {
    final String? route = _pendingTapRoute;
    _pendingTapRoute = null;
    return route;
  }

  FirebaseMessaging get _firebaseMessaging =>
      _firebaseMessagingOverride ?? FirebaseMessaging.instance;

  Future<void> initialize() async {
    await _ensureFirebaseInitialized();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      await syncTokenIfPossible();

      _firebaseMessaging.onTokenRefresh.listen((String token) async {
        if (kDebugMode) {
          debugPrint('FCM_TOKEN_REFRESH: $token');
        }
        await _registerTokenIfPossible(token);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final String title =
            message.notification?.title ?? '⚠️ Alimentos próximos a vencer';
        final String body =
            message.notification?.body ??
            _buildBodyFromMessageData(message.data);
        final String route = _extractRoute(message);

        await _localNotificationsService.showForegroundPushNotification(
          title: title,
          body: body,
          payload: route,
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _emitTapRoute(_extractRoute(message));
      });

      final RemoteMessage? initialMessage = await _firebaseMessaging
          .getInitialMessage();
      if (initialMessage != null) {
        _emitTapRoute(_extractRoute(initialMessage));
      }
    } catch (_) {}
  }

  Future<void> syncTokenIfPossible() async {
    try {
      await _ensureFirebaseInitialized();
      final String? currentToken = await _firebaseMessaging.getToken().timeout(
        const Duration(seconds: 8),
      );
      if (currentToken != null) {
        if (kDebugMode) {
          debugPrint('FCM_TOKEN: $currentToken');
        }
        await _registerTokenIfPossible(currentToken);
      }
    } catch (_) {}
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  Future<void> _registerTokenIfPossible(String token) async {
    final String? authToken = await _accessTokenProvider();
    if (authToken == null || authToken.isEmpty) {
      return;
    }

    await _notificationsApiService.registerDevice(
      authToken: authToken,
      fcmToken: token,
      platform: _platformValue,
    );

    await _notificationsApiService.updatePreferences(
      authToken: authToken,
      daysBeforeExpiry: _defaultDaysBeforeExpiry,
      pushEnabled: true,
    );
  }

  String get _platformValue {
    if (Platform.isAndroid) {
      return 'android_flutter';
    }
    if (Platform.isIOS) {
      return 'ios_flutter';
    }
    return 'android_flutter';
  }

  void _emitTapRoute(String route) {
    if (_notificationTapController.hasListener) {
      _notificationTapController.add(route);
      return;
    }
    _pendingTapRoute = route;
  }

  String _extractRoute(RemoteMessage message) {
    final String? route = message.data['route'] as String?;
    if (route != null && route.isNotEmpty) {
      return route;
    }
    return '/home';
  }

  String _buildBodyFromMessageData(Map<String, dynamic> data) {
    final String? itemName = data['item_name'] as String?;
    final String? daysRemaining = data['days_remaining']?.toString();

    if (itemName != null && itemName.isNotEmpty) {
      if (daysRemaining == null || daysRemaining.isEmpty) {
        return '$itemName está próximo a vencer';
      }
      if (daysRemaining == '0') {
        return '$itemName vence hoy';
      }
      return '$itemName vence en $daysRemaining día${daysRemaining == '1' ? '' : 's'}';
    }

    return 'Revisa tu inventario para evitar desperdicio';
  }
}
