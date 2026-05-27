import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:second_serving_frontend/firebase_options.dart';

import 'local_notifications_service.dart';
import 'package:second_serving_frontend/features/analytics/services/analytics_events_service.dart';

import '../data/services/notifications_api_service.dart';
import '../data/services/push_sync_cache_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationsService {
  static const int _defaultDaysBeforeExpiry = 1;

  PushNotificationsService({
    required NotificationsApiService notificationsApiService,
    required Future<String?> Function() accessTokenProvider,
    PushSyncCacheService? syncCacheService,
    FirebaseMessaging? firebaseMessaging,
    LocalNotificationsService? localNotificationsService,
    AnalyticsEventsService? analyticsEventsService,
  }) : _notificationsApiService = notificationsApiService,
       _accessTokenProvider = accessTokenProvider,
       _syncCacheService = syncCacheService ?? PushSyncCacheService(),
       _firebaseMessagingOverride = firebaseMessaging,
       _localNotificationsService =
           localNotificationsService ?? LocalNotificationsService.instance,
       _analyticsEvents = analyticsEventsService;

  final NotificationsApiService _notificationsApiService;
  final Future<String?> Function() _accessTokenProvider;
  final PushSyncCacheService _syncCacheService;
  final FirebaseMessaging? _firebaseMessagingOverride;
  final LocalNotificationsService _localNotificationsService;
  AnalyticsEventsService? _analyticsEvents;

  /// Permite inyectar el servicio después de la construcción (necesario porque
  /// el `PushNotificationsService` se crea en `main()` antes de que exista
  /// el `ApiClient` del State).
  void attachAnalyticsEvents(AnalyticsEventsService service) {
    _analyticsEvents = service;
  }
  final StreamController<String> _notificationTapController =
      StreamController<String>.broadcast();
  final StreamController<PushSyncState> _syncStatusController =
      StreamController<PushSyncState>.broadcast();
  String? _pendingTapRoute;
  bool _retryInFlight = false;

  Stream<String> get onNotificationTap => _notificationTapController.stream;
  Stream<PushSyncState> get onSyncStatusChanged =>
      _syncStatusController.stream;

  Future<PushSyncState> readSyncStatus() => _syncCacheService.read();

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

        // BQ T1.1 / T3.4 — registrar recepción si el push trae item_id.
        _trackNotificationEvent(message, opened: false);

        // Recibir un push confirma que hay red: aprovechamos para drenar
        // cualquier registro que haya quedado encolado por falta de conexión.
        unawaited(retryPendingSync());
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _emitTapRoute(_extractRoute(message));
        _trackNotificationEvent(message, opened: true);
      });

      final RemoteMessage? initialMessage = await _firebaseMessaging
          .getInitialMessage();
      if (initialMessage != null) {
        _emitTapRoute(_extractRoute(initialMessage));
        _trackNotificationEvent(initialMessage, opened: true);
      }
    } catch (_) {}
  }

  Future<void> syncTokenIfPossible() async {
    String? freshToken;
    try {
      await _ensureFirebaseInitialized();
      freshToken = await _firebaseMessaging.getToken().timeout(
        const Duration(seconds: 8),
      );
    } catch (_) {
      // Firebase no está alcanzable (offline o fallo transitorio).
      // Intentaremos con lo que haya en la cola persistente más abajo.
    }

    if (freshToken != null) {
      if (kDebugMode) {
        debugPrint('FCM_TOKEN: $freshToken');
      }
      await _registerTokenIfPossible(freshToken);
      return;
    }

    // Sin token fresco disponible: si dejamos algo pendiente antes, reintentar.
    await retryPendingSync();
  }

  /// Intenta re-registrar un token que quedó encolado por falta de conectividad
  /// o sesión. Es idempotente y seguro de invocar desde múltiples triggers
  /// (onMessage, onAuthenticated, foreground, etc.).
  Future<void> retryPendingSync() async {
    if (_retryInFlight) {
      return;
    }
    _retryInFlight = true;
    try {
      final PushSyncState state = await _syncCacheService.read();
      if (!state.hasPending) {
        return;
      }
      await _registerTokenIfPossible(state.token!);
    } finally {
      _retryInFlight = false;
    }
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
    String? authToken;
    try {
      authToken = await _accessTokenProvider();
    } catch (error) {
      await _syncCacheService.markPending(token, error: error.toString());
      _emitStatusAsync();
      return;
    }

    if (authToken == null || authToken.isEmpty) {
      await _syncCacheService.markPending(
        token,
        error: 'Sin sesión activa; se reintentará al iniciar sesión.',
      );
      _emitStatusAsync();
      return;
    }

    try {
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

      await _syncCacheService.markSynced(token);
      _emitStatusAsync();
    } catch (error) {
      // Fallo de red o backend: encolamos para reintentar en próximo evento
      // de conectividad (onMessage, onAuthenticated, syncTokenIfPossible).
      await _syncCacheService.markPending(token, error: error.toString());
      _emitStatusAsync();
    }
  }

  void _emitStatusAsync() {
    unawaited(
      _syncCacheService.read().then((PushSyncState state) {
        if (!_syncStatusController.isClosed) {
          _syncStatusController.add(state);
        }
      }).catchError((_) {}),
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

  /// BQ T1.1 / T3.4 — empuja `notification_received` (al recibir) o
  /// `notification_opened` (al tappear) si el push trae `item_id` en `data`.
  /// Sin item_id no se trackea (el backend exige el UUID exacto).
  void _trackNotificationEvent(RemoteMessage message, {required bool opened}) {
    final service = _analyticsEvents;
    if (service == null) return;
    final dynamic raw = message.data['item_id'];
    final String? itemId = raw is String && raw.isNotEmpty ? raw : null;
    if (itemId == null) return;
    if (opened) {
      unawaited(service.trackNotificationOpened(itemId));
    } else {
      unawaited(service.trackNotificationReceived(itemId));
    }
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
