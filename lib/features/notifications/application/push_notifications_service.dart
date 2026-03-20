import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../data/services/notifications_api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationsService {
  PushNotificationsService({
    required NotificationsApiService notificationsApiService,
    required Future<String?> Function() accessTokenProvider,
    FirebaseMessaging? firebaseMessaging,
  })  : _notificationsApiService = notificationsApiService,
        _accessTokenProvider = accessTokenProvider,
        _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance;

  final NotificationsApiService _notificationsApiService;
  final Future<String?> Function() _accessTokenProvider;
  final FirebaseMessaging _firebaseMessaging;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final String? initialToken = await _firebaseMessaging.getToken();
    if (initialToken != null) {
      await _registerTokenIfPossible(initialToken);
    }

    _firebaseMessaging.onTokenRefresh.listen((String token) async {
      await _registerTokenIfPossible(token);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {});
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {});
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
