import 'dart:async';

import 'package:flutter/material.dart';
import 'package:second_serving_frontend/core/connectivity/connectivity_service.dart';
import 'package:second_serving_frontend/features/analytics/data/waste_cache.dart';
import 'package:second_serving_frontend/features/analytics/models/analytics.dart';
import 'package:second_serving_frontend/features/analytics/services/analytics_service.dart';

enum SavingsDetailStatus { loading, success, error }

/// Pérdida acumulada por categoría (agregación client-side para la sección
/// "Por categoría" — responde la 2da parte de la BQ T2.4).
class CategoryLoss {
  final String category;
  final double valueLostCop;

  const CategoryLoss(this.category, this.valueLostCop);
}

/// Total de desperdicio por mes (sección "Últimos 3 meses").
class MonthLoss {
  final String month;
  final double valueLostCop;

  const MonthLoss(this.month, this.valueLostCop);
}

/// ViewModel dedicado de la pantalla SavingsDetail (patrón MVVM/Provider).
///
/// Responde la BQ T2.4 combinando dos fuentes del backend traídas EN PARALELO:
///   - GET /analytics/savings (ahorro vs. desperdicio del mes actual)
///   - GET /analytics/waste?months=N (tendencia + desglose por categoría)
///
/// Caché de 3 capas:
///   L1: snapshot en memoria (este provider)
///   L2: [WasteCache] (SharedPreferences, 24h)
///   L3: red (fetch paralelo con Future.wait)
///
/// Conectividad eventual: si recibe un [ConnectivityService], se suscribe a
/// sus cambios y, al pasar de offline → online, recarga automáticamente para
/// reemplazar los datos servidos desde caché por datos frescos.
class SavingsDetailProvider extends ChangeNotifier {
  final AnalyticsService _service;
  final WasteCache _cache;

  StreamSubscription<bool>? _connectivitySub;
  int _lastMonths = 3;

  SavingsDetailProvider(
    this._service,
    this._cache, {
    ConnectivityService? connectivityService,
  }) {
    // El stream solo emite ante cambios reales y deduplicados, así que un
    // evento `true` representa la transición offline → online.
    _connectivitySub = connectivityService?.onStatusChange.listen((online) {
      if (online) {
        load(months: _lastMonths);
      }
    });
  }

  SavingsDetailSnapshot? _snapshot;
  SavingsDetailStatus _status = SavingsDetailStatus.loading;
  String? _errorMessage;

  SavingsDetailStatus get status => _status;
  String? get errorMessage => _errorMessage;
  SavingsResponse? get savings => _snapshot?.savings;
  List<WasteTrendItem> get wasteTrends => _snapshot?.wasteTrends ?? const [];
  bool get isFromCache => _servedFromCache;
  bool _servedFromCache = false;

  /// Total de `value_lost_cop` por mes, en el orden en que llega del backend.
  List<MonthLoss> get wasteByMonth {
    final order = <String>[];
    final totals = <String, double>{};
    for (final item in wasteTrends) {
      if (!totals.containsKey(item.month)) order.add(item.month);
      totals[item.month] = (totals[item.month] ?? 0) + item.valueLostCop;
    }
    return order.map((m) => MonthLoss(m, totals[m]!)).toList();
  }

  /// Top N categorías con mayor pérdida acumulada en los meses cargados.
  List<CategoryLoss> topCategoriesByLoss({int top = 3}) {
    final totals = <String, double>{};
    for (final item in wasteTrends) {
      final cat = item.category;
      if (cat == null || cat.isEmpty) continue;
      totals[cat] = (totals[cat] ?? 0) + item.valueLostCop;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(top).map((e) => CategoryLoss(e.key, e.value)).toList();
  }

  Future<void> load({int months = 3}) async {
    _lastMonths = months;
    // L1: memoria — si ya tenemos snapshot, lo mostramos de una.
    if (_snapshot != null && _snapshot!.months == months) {
      _status = SavingsDetailStatus.success;
      notifyListeners();
    } else {
      // L2: caché persistente válida (<24h) → publicar de inmediato.
      final cached = await _cache.read(months: months);
      if (cached != null) {
        _snapshot = cached;
        _servedFromCache = true;
        _status = SavingsDetailStatus.success;
        notifyListeners();
      } else {
        _status = SavingsDetailStatus.loading;
        notifyListeners();
      }
    }

    // L3: red — fetch en paralelo (multi-threading: async{} + awaitAll()).
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        _service.getSavings(month: now.month, year: now.year),
        _service.getWasteTrends(months: months),
      ]);

      final savings = results[0] as SavingsResponse;
      final trends = results[1] as List<WasteTrendItem>;

      final fresh = SavingsDetailSnapshot(
        fetchedAt: DateTime.now(),
        months: months,
        savings: savings,
        wasteTrends: trends,
      );
      _snapshot = fresh;
      _servedFromCache = false;
      _errorMessage = null;
      _status = SavingsDetailStatus.success;
      await _cache.save(fresh);
      notifyListeners();
    } catch (e) {
      // Conectividad eventual: si falla la red, intentamos servir caché
      // (aunque esté vencida). Sólo si no hay nada mostramos error.
      final stale = await _cache.readAny(months: months);
      if (_snapshot != null || stale != null) {
        _snapshot ??= stale;
        _servedFromCache = true;
        _status = SavingsDetailStatus.success;
        notifyListeners();
      } else {
        _errorMessage = 'No hay conexión y no hay datos guardados.';
        _status = SavingsDetailStatus.error;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
