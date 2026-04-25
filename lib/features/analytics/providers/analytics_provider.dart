import 'package:flutter/material.dart';
import 'package:second_serving_frontend/features/analytics/models/analytics.dart';
import 'package:second_serving_frontend/features/analytics/services/analytics_service.dart';

class AnalyticsProvider extends ChangeNotifier {
  final AnalyticsService _service;

  DashboardResponse? _dashboard;
  RecipeImpactResponse? _recipeImpact;
  BehaviorPatternsResponse? _behaviorPatterns;
  SavingsResponse? _monthlySavings;
  List<WasteTrendItem> _wasteTrends = [];
  bool _isLoading = false;
  bool _isLoadingSavings = false;
  String? _error;

  AnalyticsProvider(this._service);

  DashboardResponse? get dashboard => _dashboard;
  SavingsResponse? get monthlySavings => _monthlySavings;
  // Preferimos el dato del endpoint dedicado /analytics/savings (más fresco
  // y barato de refrescar tras un consumo). Caemos al del dashboard como
  // fallback en la primera carga.
  SavingsResponse? get savings => _monthlySavings ?? _dashboard?.savings;
  WasteSummary? get wasteSummary => _dashboard?.wasteSummary;
  UserSegment? get segment => _dashboard?.segment;
  RecipeImpactResponse? get recipeImpact =>
      _recipeImpact ?? _dashboard?.recipeImpact;
  BehaviorPatternsResponse? get behaviorPatterns =>
      _behaviorPatterns ?? _dashboard?.behaviorPatterns;
  List<WasteTrendItem> get wasteTrends => _wasteTrends;
  bool get isLoading => _isLoading;
  bool get isLoadingSavings => _isLoadingSavings;
  String? get error => _error;

  Future<void> loadDashboard({int? month, int? year}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dashboard = await _service.getDashboard(month: month, year: year);
      _recipeImpact = _dashboard?.recipeImpact ?? _recipeImpact;
      _behaviorPatterns = _dashboard?.behaviorPatterns ?? _behaviorPatterns;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Carga sólo el panel "ahorrado este mes" pegándole al endpoint
  /// dedicado `/analytics/savings?month=&year=`. Más barato que recargar
  /// todo el dashboard tras un consumo.
  Future<void> loadMonthlySavings({int? month, int? year}) async {
    _isLoadingSavings = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      _monthlySavings = await _service.getSavings(
        month: month ?? now.month,
        year: year ?? now.year,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoadingSavings = false;
    notifyListeners();
  }

  Future<void> loadWasteTrends({int months = 3}) async {
    try {
      _wasteTrends = await _service.getWasteTrends(months: months);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadRecipeImpact({int? month, int? year}) async {
    try {
      _recipeImpact = await _service.getRecipeImpact(month: month, year: year);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadBehaviorPatterns({int? month, int? year}) async {
    try {
      _behaviorPatterns = await _service.getBehaviorPatterns(
        month: month,
        year: year,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
