import 'package:second_serving_frontend/core/config/api_config.dart';
import 'package:second_serving_frontend/features/analytics/models/analytics.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';

abstract class AnalyticsService {
  Future<DashboardResponse> getDashboard({int? month, int? year});
  Future<SavingsResponse> getSavings({int? month, int? year});
  Future<List<WasteTrendItem>> getWasteTrends({int months = 3});
  Future<WasteSummary> getSummary();
  Future<UserSegment> getSegment();
  Future<RecipeImpactResponse> getRecipeImpact({int? month, int? year});
}

class AnalyticsServiceImpl implements AnalyticsService {
  final ApiClient _client;

  AnalyticsServiceImpl(this._client);

  @override
  Future<DashboardResponse> getDashboard({int? month, int? year}) async {
    final params = <String, String>{};
    if (month != null) params['month'] = '$month';
    if (year != null) params['year'] = '$year';
    final response = await _client.get(
      ApiConfig.analyticsDashboard,
      queryParams: params,
    );
    return DashboardResponse.fromJson(response);
  }

  @override
  Future<SavingsResponse> getSavings({int? month, int? year}) async {
    final params = <String, String>{};
    if (month != null) params['month'] = '$month';
    if (year != null) params['year'] = '$year';
    final response = await _client.get(
      ApiConfig.analyticsSavings,
      queryParams: params,
    );
    return SavingsResponse.fromJson(response);
  }

  @override
  Future<List<WasteTrendItem>> getWasteTrends({int months = 3}) async {
    final response = await _client.get(
      ApiConfig.analyticsWaste,
      queryParams: {'months': '$months'},
    );
    final list = response['data'] as List? ?? [];
    return list
        .map((e) => WasteTrendItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<WasteSummary> getSummary() async {
    final response = await _client.get(ApiConfig.analyticsSummary);
    return WasteSummary.fromJson(response);
  }

  @override
  Future<UserSegment> getSegment() async {
    final response = await _client.get(ApiConfig.analyticsSegment);
    return UserSegment.fromJson(response);
  }

  @override
  Future<RecipeImpactResponse> getRecipeImpact({int? month, int? year}) async {
    final params = <String, String>{};
    if (month != null) params['month'] = '$month';
    if (year != null) params['year'] = '$year';
    final response = await _client.get(
      ApiConfig.analyticsRecipeImpact,
      queryParams: params,
    );
    return RecipeImpactResponse.fromJson(response);
  }
}
