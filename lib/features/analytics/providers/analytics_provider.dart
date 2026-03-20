import 'package:flutter/material.dart';
import 'package:second_serving_frontend/features/analytics/models/analytics.dart';
import 'package:second_serving_frontend/features/analytics/services/analytics_service.dart';

class AnalyticsProvider extends ChangeNotifier {
  final AnalyticsService _service;

  DashboardResponse? _dashboard;
  List<WasteTrendItem> _wasteTrends = [];
  bool _isLoading = false;
  String? _error;

  AnalyticsProvider(this._service);

  DashboardResponse? get dashboard => _dashboard;
  SavingsResponse? get savings => _dashboard?.savings;
  WasteSummary? get wasteSummary => _dashboard?.wasteSummary;
  UserSegment? get segment => _dashboard?.segment;
  List<WasteTrendItem> get wasteTrends => _wasteTrends;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDashboard({int? month, int? year}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dashboard = await _service.getDashboard(month: month, year: year);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
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

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
