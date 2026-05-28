import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:second_serving_frontend/core/config/api_config.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';

/// Envía eventos genéricos a `POST /api/v1/analytics/events` para alimentar
/// las BQs del backend:
///   - **T1.1 / T3.4** — `notification_received` y `notification_opened`,
///     con `properties.item_id` (UUID del item de inventario) para que el
///     backend pueda calcular latencias y distribución de tiempos de respuesta.
///
/// Estrategia: **best-effort fire-and-forget**. Cualquier fallo de red se
/// silencia (no rompe el flujo de la notificación). Sin cola dedicada por
/// ahora — los eventos perdidos por offline son tolerables a este nivel.
class AnalyticsEventsService {
  AnalyticsEventsService({ApiClient? apiClient}) : _apiClient = apiClient;

  final ApiClient? _apiClient;

  Future<void> trackNotificationReceived(String itemId) =>
      _send('notification_received', itemId: itemId);

  Future<void> trackNotificationOpened(String itemId) =>
      _send('notification_opened', itemId: itemId);

  Future<void> _send(String eventName, {required String itemId}) async {
    final client = _apiClient;
    if (client == null) return;
    if (itemId.isEmpty) {
      debugPrint('[AnalyticsEvents] skipped $eventName: empty itemId');
      return;
    }
    try {
      await client.post(
        ApiConfig.analyticsEvents,
        body: {
          'events': [
            {
              'event_name': eventName,
              'occurred_at': DateTime.now().toUtc().toIso8601String(),
              'properties': {'item_id': itemId},
              'platform': _platform(),
            }
          ],
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsEvents] $eventName push failed: $e');
    }
  }

  String _platform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}
