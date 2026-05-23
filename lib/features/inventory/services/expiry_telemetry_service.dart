import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';
import 'package:second_serving_frontend/core/config/api_config.dart';

class ExpiryAccuracyEvent {
  final DateTime timestamp;
  final String category;
  final bool ocrDetectedDate;
  final DateTime? ocrDate;
  final DateTime userConfirmedDate;
  final bool accurate;

  const ExpiryAccuracyEvent({
    required this.timestamp,
    required this.category,
    required this.ocrDetectedDate,
    this.ocrDate,
    required this.userConfirmedDate,
    required this.accurate,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'category': category,
        'ocr_detected_date': ocrDetectedDate,
        if (ocrDate != null)
          'ocr_date':
              '${ocrDate!.year}-${ocrDate!.month.toString().padLeft(2, '0')}-${ocrDate!.day.toString().padLeft(2, '0')}',
        'user_confirmed_date':
            '${userConfirmedDate.year}-${userConfirmedDate.month.toString().padLeft(2, '0')}-${userConfirmedDate.day.toString().padLeft(2, '0')}',
        'accurate': accurate,
      };

  factory ExpiryAccuracyEvent.fromJson(Map<String, dynamic> json) {
    DateTime? ocrDate;
    if (json['ocr_date'] != null) {
      ocrDate = DateTime.tryParse(json['ocr_date'] as String);
    }
    return ExpiryAccuracyEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      category: json['category'] as String,
      ocrDetectedDate: json['ocr_detected_date'] as bool,
      ocrDate: ocrDate,
      userConfirmedDate: DateTime.parse(json['user_confirmed_date'] as String),
      accurate: json['accurate'] as bool,
    );
  }
}

class ExpiryTelemetryService {
  static const String _localKey = 'telemetry.expiry_accuracy';

  final ApiClient? _apiClient;

  ExpiryTelemetryService({ApiClient? apiClient}) : _apiClient = apiClient;

  Future<void> recordAccuracy({
    required String category,
    required bool ocrDetectedDate,
    DateTime? ocrDate,
    required DateTime userConfirmedDate,
  }) async {
    final accurate = ocrDetectedDate &&
        ocrDate != null &&
        ocrDate.year == userConfirmedDate.year &&
        ocrDate.month == userConfirmedDate.month &&
        ocrDate.day == userConfirmedDate.day;

    final event = ExpiryAccuracyEvent(
      timestamp: DateTime.now(),
      category: category,
      ocrDetectedDate: ocrDetectedDate,
      ocrDate: ocrDate,
      userConfirmedDate: userConfirmedDate,
      accurate: accurate,
    );

    debugPrint('[ExpiryTelemetry] category=$category '
        'ocrDetected=$ocrDetectedDate accurate=$accurate');

    await _saveLocally(event);
    await _tryPushToBackend(event);
  }

  Future<void> _saveLocally(ExpiryAccuracyEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_localKey) ?? [];
    raw.add(jsonEncode(event.toJson()));
    await prefs.setStringList(_localKey, raw);
  }

  Future<void> _tryPushToBackend(ExpiryAccuracyEvent event) async {
    if (_apiClient == null) return;
    try {
      await _apiClient.post(
        ApiConfig.telemetryExpiryAccuracy,
        body: event.toJson(),
      );
    } catch (e) {
      debugPrint('[ExpiryTelemetry] Backend push failed (stored locally): $e');
    }
  }

  Future<List<ExpiryAccuracyEvent>> getLocalEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_localKey) ?? [];
    return raw.map((s) {
      final json = jsonDecode(s) as Map<String, dynamic>;
      return ExpiryAccuracyEvent.fromJson(json);
    }).toList();
  }

  /// Stats grouped by category: { "Frutas": { total, detected, accurate, accuracy_rate }, ... }
  Future<Map<String, dynamic>> getLocalStats() async {
    final events = await getLocalEvents();
    if (events.isEmpty) return {};

    final byCategory = <String, List<ExpiryAccuracyEvent>>{};
    for (final e in events) {
      byCategory.putIfAbsent(e.category, () => []).add(e);
    }

    final stats = <String, dynamic>{};
    for (final entry in byCategory.entries) {
      final total = entry.value.length;
      final detected = entry.value.where((e) => e.ocrDetectedDate).length;
      final accurate = entry.value.where((e) => e.accurate).length;
      final rate = detected > 0 ? accurate / detected : 0.0;

      stats[entry.key] = {
        'total': total,
        'detected': detected,
        'accurate': accurate,
        'accuracy_rate': double.parse(rate.toStringAsFixed(4)),
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
        '${ApiConfig.telemetryExpiryAccuracy}/batch',
        body: {'events': events.map((e) => e.toJson()).toList()},
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localKey);
      debugPrint('[ExpiryTelemetry] Flushed ${events.length} events');
    } catch (e) {
      debugPrint('[ExpiryTelemetry] Flush failed, will retry later: $e');
    }
  }
}
