import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:second_serving_frontend/firebase_options.dart';

import '../data/services/notifications_api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class PushNotificationsService {
  PushNotificationsService({
    required NotificationsApiService notificationsApiService,
    required Future<String?> Function() accessTokenProvider,
    FirebaseMessaging? firebaseMessaging,
  })  : _notificationsApiService = notificationsApiService,
        _accessTokenProvider = accessTokenProvider,
        _firebaseMessagingOverride = firebaseMessaging;

  final NotificationsApiService _notificationsApiService;
  final Future<String?> Function() _accessTokenProvider;
  final FirebaseMessaging? _firebaseMessagingOverride;

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
        await _registerTokenIfPossible(token);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {});
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {});
    } catch (_) {}
  }

  Future<void> syncTokenIfPossible() async {
    try {
      await _ensureFirebaseInitialized();
      final String? currentToken = await _firebaseMessaging
          .getToken()
          .timeout(const Duration(seconds: 8));
      if (currentToken != null) {
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
}
