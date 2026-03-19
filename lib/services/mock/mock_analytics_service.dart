import 'package:second_serving_frontend/models/analytics.dart';
import 'package:second_serving_frontend/services/analytics_service.dart';
import 'package:second_serving_frontend/services/mock/mock_data.dart';

class MockAnalyticsService implements AnalyticsService {
  @override
  Future<DashboardResponse> getDashboard({int? month, int? year}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return MockData.dashboard;
  }

  @override
  Future<SavingsResponse> getSavings({int? month, int? year}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return MockData.dashboard.savings;
  }

  @override
  Future<List<WasteTrendItem>> getWasteTrends({int months = 3}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return MockData.wasteTrends;
  }

  @override
  Future<WasteSummary> getSummary() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return MockData.dashboard.wasteSummary;
  }

  @override
  Future<UserSegment> getSegment() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return MockData.dashboard.segment;
  }
}
