import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';
import 'package:second_serving_frontend/core/config/api_config.dart';

class ScanEvent {
  final DateTime timestamp;
  final bool success;
  final String? failureReason;
  final int productsDetected;
  final int durationMs;

  const ScanEvent({
    required this.timestamp,
    required this.success,
    this.failureReason,
    this.productsDetected = 0,
    this.durationMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'success': success,
        if (failureReason != null) 'failure_reason': failureReason,
        'products_detected': productsDetected,
        'duration_ms': durationMs,
      };

  factory ScanEvent.fromJson(Map<String, dynamic> json) => ScanEvent(
        timestamp: DateTime.parse(json['timestamp'] as String),
        success: json['success'] as bool,
        failureReason: json['failure_reason'] as String?,
        productsDetected: json['products_detected'] as int? ?? 0,
        durationMs: json['duration_ms'] as int? ?? 0,
      );
}

class ScanTelemetryService {
  static const String _localKey = 'telemetry.scan_events';

  final ApiClient? _apiClient;

  ScanTelemetryService({ApiClient? apiClient}) : _apiClient = apiClient;

  Future<void> recordScan({
    required bool success,
    String? failureReason,
    int productsDetected = 0,
    int durationMs = 0,
  }) async {
    final event = ScanEvent(
      timestamp: DateTime.now(),
      success: success,
      failureReason: failureReason,
      productsDetected: productsDetected,
      durationMs: durationMs,
    );

    debugPrint('[ScanTelemetry] ${success ? "OK" : "FAIL"}'
        '${failureReason != null ? " ($failureReason)" : ""}'
        ' — ${productsDetected} products, ${durationMs}ms');

    await _saveLocally(event);
    await _tryPushToBackend(event);
  }

  Future<void> _saveLocally(ScanEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_localKey) ?? [];
    raw.add(jsonEncode(event.toJson()));
    await prefs.setStringList(_localKey, raw);
  }

  Future<void> _tryPushToBackend(ScanEvent event) async {
    if (_apiClient == null) return;
    try {
      await _apiClient.post(
        ApiConfig.telemetryScanEvent,
        body: event.toJson(),
      );
    } catch (e) {
      debugPrint('[ScanTelemetry] Backend push failed (stored locally): $e');
    }
  }

  Future<List<ScanEvent>> getLocalEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_localKey) ?? [];
    return raw.map((s) {
      final json = jsonDecode(s) as Map<String, dynamic>;
      return ScanEvent.fromJson(json);
    }).toList();
  }

  Future<Map<String, dynamic>> getLocalStats() async {
    final events = await getLocalEvents();
    if (events.isEmpty) {
      return {'total': 0, 'success': 0, 'failures': 0, 'crash_rate': 0.0};
    }
    final successes = events.where((e) => e.success).length;
    final failures = events.where((e) => !e.success).length;
    final rate = failures / events.length;

    final failureBreakdown = <String, int>{};
    for (final e in events.where((e) => !e.success)) {
      final reason = e.failureReason ?? 'unknown';
      failureBreakdown[reason] = (failureBreakdown[reason] ?? 0) + 1;
    }

    return {
      'total': events.length,
      'success': successes,
      'failures': failures,
      'crash_rate': double.parse(rate.toStringAsFixed(4)),
      'failure_breakdown': failureBreakdown,
    };
  }

  Future<void> flushPendingToBackend() async {
    if (_apiClient == null) return;
    final events = await getLocalEvents();
    if (events.isEmpty) return;

    try {
      await _apiClient.post(
        ApiConfig.telemetryScanEvent,
        body: {'events': events.map((e) => e.toJson()).toList()},
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localKey);
      debugPrint('[ScanTelemetry] Flushed ${events.length} events to backend');
    } catch (e) {
      debugPrint('[ScanTelemetry] Flush failed, will retry later: $e');
    }
  }
}
