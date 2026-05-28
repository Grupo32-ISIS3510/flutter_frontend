import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';
import 'package:second_serving_frontend/core/config/api_config.dart';

/// Identificadores estables de las features que trackeamos para la BQ T3.1.
/// Si agregas una nueva feature, agrega su id aqui (es el valor que se
/// persiste en backend y aparece en el dashboard).
class FeatureIds {
  static const String inventory = 'inventory';
  static const String scanReceipt = 'scan_receipt';
  static const String recipes = 'recipes';
  static const String shoppingList = 'shopping_list';
  static const String analytics = 'analytics';
  static const String notifications = 'notifications';
  static const String favorites = 'favorites';

  static const Set<String> all = {
    inventory,
    scanReceipt,
    recipes,
    shoppingList,
    analytics,
    notifications,
    favorites,
  };
}

class FeatureUsageEvent {
  final DateTime timestamp;
  final String feature;

  const FeatureUsageEvent({required this.timestamp, required this.feature});

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'feature': feature,
      };

  factory FeatureUsageEvent.fromJson(Map<String, dynamic> json) =>
      FeatureUsageEvent(
        timestamp: DateTime.parse(json['timestamp'] as String),
        feature: json['feature'] as String,
      );
}

/// BQ T3.1 — Frecuencia de uso semanal por feature.
///
/// Estrategia: local-first con flush oportunista.
///   1. recordFeatureUse() guarda el evento en SharedPreferences y dispara
///      un POST individual al backend (fire-and-forget).
///   2. Si el POST falla (offline), el evento queda local.
///   3. Al recuperar conexion, ConnectivityProvider llama a flushToBackend()
///      que envia todos los eventos pendientes en un solo batch.
class FeatureUsageTelemetryService {
  static const String _localKey = 'telemetry.feature_usage';

  final ApiClient? _apiClient;

  FeatureUsageTelemetryService({ApiClient? apiClient}) : _apiClient = apiClient;

  Future<void> recordFeatureUse(String feature) async {
    if (!FeatureIds.all.contains(feature)) {
      debugPrint('[FeatureUsage] Unknown feature id: $feature (event ignored)');
      return;
    }
    final event = FeatureUsageEvent(
      timestamp: DateTime.now(),
      feature: feature,
    );

    debugPrint('[FeatureUsage] $feature');

    await _saveLocally(event);
    await _tryPushToBackend(event);
  }

  Future<void> _saveLocally(FeatureUsageEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_localKey) ?? [];
    raw.add(jsonEncode(event.toJson()));
    await prefs.setStringList(_localKey, raw);
  }

  Future<void> _tryPushToBackend(FeatureUsageEvent event) async {
    if (_apiClient == null) return;
    try {
      await _apiClient.post(
        ApiConfig.telemetryFeatureEvent,
        body: event.toJson(),
      );
    } catch (e) {
      debugPrint('[FeatureUsage] Backend push failed (stored locally): $e');
    }
  }

  Future<List<FeatureUsageEvent>> getLocalEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_localKey) ?? [];
    return raw
        .map((s) =>
            FeatureUsageEvent.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  /// Conteos por feature en una ventana de N dias (default 7).
  /// Util para mostrar stats offline en la app sin esperar al backend.
  Future<Map<String, int>> getLocalCountsLastDays({int days = 7}) async {
    final events = await getLocalEvents();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final filtered = events.where((e) => e.timestamp.isAfter(cutoff));
    final counts = <String, int>{};
    for (final e in filtered) {
      counts[e.feature] = (counts[e.feature] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> flushToBackend() async {
    if (_apiClient == null) return;
    final events = await getLocalEvents();
    if (events.isEmpty) return;
    try {
      await _apiClient.post(
        '${ApiConfig.telemetryFeatureEvent}/batch',
        body: {'events': events.map((e) => e.toJson()).toList()},
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localKey);
      debugPrint('[FeatureUsage] Flushed ${events.length} events');
    } catch (e) {
      debugPrint('[FeatureUsage] Flush failed, will retry later: $e');
    }
  }
}
