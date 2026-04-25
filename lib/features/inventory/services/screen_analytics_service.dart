import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';
import 'package:second_serving_frontend/core/config/api_config.dart';

class ScreenEvent {
  final DateTime timestamp;
  final String screenName;
  final String eventType;
  final String? exitReason;
  final int dwellTimeMs;

  const ScreenEvent({
    required this.timestamp,
    required this.screenName,
    required this.eventType,
    this.exitReason,
    this.dwellTimeMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'screen_name': screenName,
        'event_type': eventType,
        if (exitReason != null) 'exit_reason': exitReason,
        'dwell_time_ms': dwellTimeMs,
      };

  factory ScreenEvent.fromJson(Map<String, dynamic> json) => ScreenEvent(
        timestamp: DateTime.parse(json['timestamp'] as String),
        screenName: json['screen_name'] as String,
        eventType: json['event_type'] as String,
        exitReason: json['exit_reason'] as String?,
        dwellTimeMs: json['dwell_time_ms'] as int? ?? 0,
      );
}

class ScreenAnalyticsService {
  static const String _localKey = 'telemetry.screen_events';

  final ApiClient? _apiClient;
  final Map<String, DateTime> _enterTimestamps = {};

  ScreenAnalyticsService({ApiClient? apiClient}) : _apiClient = apiClient;

  void recordEnter(String screenName) {
    _enterTimestamps[screenName] = DateTime.now();

    final event = ScreenEvent(
      timestamp: DateTime.now(),
      screenName: screenName,
      eventType: 'enter',
    );

    debugPrint('[ScreenAnalytics] ENTER $screenName');
    _saveLocally(event);
    _tryPushToBackend(event);
  }

  void recordExit(String screenName, String exitReason) {
    final enterTime = _enterTimestamps.remove(screenName);
    final dwellMs = enterTime != null
        ? DateTime.now().difference(enterTime).inMilliseconds
        : 0;

    final event = ScreenEvent(
      timestamp: DateTime.now(),
      screenName: screenName,
      eventType: 'exit',
      exitReason: exitReason,
      dwellTimeMs: dwellMs,
    );

    debugPrint('[ScreenAnalytics] EXIT $screenName reason=$exitReason dwell=${dwellMs}ms');
    _saveLocally(event);
    _tryPushToBackend(event);
  }

  Future<void> _saveLocally(ScreenEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_localKey) ?? [];
    raw.add(jsonEncode(event.toJson()));
    await prefs.setStringList(_localKey, raw);
  }

  Future<void> _tryPushToBackend(ScreenEvent event) async {
    if (_apiClient == null) return;
    try {
      await _apiClient.post(
        ApiConfig.telemetryScreenEvent,
        body: event.toJson(),
      );
    } catch (e) {
      debugPrint('[ScreenAnalytics] Backend push failed (stored locally): $e');
    }
  }

  Future<List<ScreenEvent>> getLocalEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_localKey) ?? [];
    return raw.map((s) {
      final json = jsonDecode(s) as Map<String, dynamic>;
      return ScreenEvent.fromJson(json);
    }).toList();
  }

  Future<Map<String, dynamic>> getLocalStats() async {
    final events = await getLocalEvents();
    if (events.isEmpty) return {};

    final byScreen = <String, Map<String, int>>{};
    for (final e in events) {
      byScreen.putIfAbsent(e.screenName, () => {'enter': 0, 'completed': 0, 'abandoned': 0});
      if (e.eventType == 'enter') {
        byScreen[e.screenName]!['enter'] = (byScreen[e.screenName]!['enter'] ?? 0) + 1;
      } else if (e.eventType == 'exit') {
        final isCompleted = e.exitReason == 'completed' ||
            e.exitReason == 'completed_manual' ||
            e.exitReason == 'scan_started';
        final key = isCompleted ? 'completed' : 'abandoned';
        byScreen[e.screenName]![key] = (byScreen[e.screenName]![key] ?? 0) + 1;
      }
    }

    final stats = <String, dynamic>{};
    for (final entry in byScreen.entries) {
      final enters = entry.value['enter'] ?? 0;
      final abandoned = entry.value['abandoned'] ?? 0;
      final rate = enters > 0 ? abandoned / enters : 0.0;
      stats[entry.key] = {
        'total_enters': enters,
        'completed': entry.value['completed'] ?? 0,
        'abandoned': abandoned,
        'abandonment_rate': double.parse(rate.toStringAsFixed(4)),
      };
    }
    return stats;
  }

  Future<void> flushToBackend() async {
    if (_apiClient == null) return;
    final events = await getLocalEvents();
    if (events.isEmpty) return;

    try {
      await _apiClient.post(
        '${ApiConfig.telemetryScreenEvent}/batch',
        body: {'events': events.map((e) => e.toJson()).toList()},
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localKey);
      debugPrint('[ScreenAnalytics] Flushed ${events.length} events');
    } catch (e) {
      debugPrint('[ScreenAnalytics] Flush failed, will retry later: $e');
    }
  }
}
