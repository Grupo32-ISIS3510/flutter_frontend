import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_serving_frontend/features/analytics/models/analytics.dart';

/// Snapshot persistido de la pantalla de detalle de ahorro/desperdicio:
/// agrupa el ahorro del mes actual y la tendencia de desperdicio de los
/// últimos N meses bajo un único timestamp, para servir la pantalla completa
/// desde caché cuando no hay red.
class SavingsDetailSnapshot {
  final DateTime fetchedAt;
  final int months;
  final SavingsResponse savings;
  final List<WasteTrendItem> wasteTrends;

  const SavingsDetailSnapshot({
    required this.fetchedAt,
    required this.months,
    required this.savings,
    required this.wasteTrends,
  });

  Map<String, dynamic> toJson() => {
        'fetched_at': fetchedAt.toIso8601String(),
        'months': months,
        'savings': savings.toJson(),
        'waste_trends': wasteTrends.map((e) => e.toJson()).toList(),
      };

  factory SavingsDetailSnapshot.fromJson(Map<String, dynamic> json) {
    return SavingsDetailSnapshot(
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
      months: json['months'] as int,
      savings: SavingsResponse.fromJson(json['savings'] as Map<String, dynamic>),
      wasteTrends: (json['waste_trends'] as List)
          .map((e) => WasteTrendItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Caché local (SharedPreferences) del snapshot de la pantalla de detalle.
///
/// TTL de 24h. Clave parametrizada por `months` (el backend ya filtra por
/// token, así que no se incluye userId). Mismo patrón que
/// `WeatherCacheService`.
class WasteCache {
  static const String _keyPrefix = 'analytics.savingsDetailSnapshot.';
  static const Duration _validFor = Duration(hours: 24);

  String _keyFor(int months) => '$_keyPrefix$months';

  /// Devuelve el snapshot sólo si existe y no ha expirado (<24h).
  Future<SavingsDetailSnapshot?> read({int months = 3}) async {
    final snapshot = await readAny(months: months);
    if (snapshot == null) return null;

    if (DateTime.now().difference(snapshot.fetchedAt) > _validFor) {
      return null;
    }
    return snapshot;
  }

  /// Devuelve el snapshot guardado ignorando el TTL (fallback offline).
  Future<SavingsDetailSnapshot?> readAny({int months = 3}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(months));
    if (raw == null) return null;

    final json = jsonDecode(raw) as Map<String, dynamic>;
    return SavingsDetailSnapshot.fromJson(json);
  }

  Future<void> save(SavingsDetailSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyFor(snapshot.months),
      jsonEncode(snapshot.toJson()),
    );
  }

  Future<void> invalidate({int months = 3}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(months));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
