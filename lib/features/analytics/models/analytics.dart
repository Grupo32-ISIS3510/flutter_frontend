class SavingsResponse {
  final double savedCop;
  final double wastedCop;
  final String period;

  const SavingsResponse({
    required this.savedCop,
    required this.wastedCop,
    required this.period,
  });

  double get totalManaged => savedCop + wastedCop;
  double get savingsPercentage =>
      totalManaged > 0 ? (savedCop / totalManaged) * 100 : 0;

  factory SavingsResponse.fromJson(Map<String, dynamic> json) {
    return SavingsResponse(
      savedCop: double.parse(json['saved_cop'].toString()),
      wastedCop: double.parse(json['wasted_cop'].toString()),
      period: json['period'] as String,
    );
  }
}

class WasteTrendItem {
  final String month;
  final String? category;
  final int itemsDiscarded;
  final double valueLostCop;

  const WasteTrendItem({
    required this.month,
    this.category,
    required this.itemsDiscarded,
    required this.valueLostCop,
  });

  factory WasteTrendItem.fromJson(Map<String, dynamic> json) {
    return WasteTrendItem(
      month: json['month'] as String,
      category: json['category'] as String?,
      itemsDiscarded: json['items_discarded'] as int,
      valueLostCop: double.parse(json['value_lost_cop'].toString()),
    );
  }
}

class WasteSummary {
  final int totalConsumed;
  final int totalDiscarded;
  final String? mostWastedCategory;
  final String? mostDiscardedItem;
  final int noWasteStreakDays;

  const WasteSummary({
    required this.totalConsumed,
    required this.totalDiscarded,
    this.mostWastedCategory,
    this.mostDiscardedItem,
    required this.noWasteStreakDays,
  });

  factory WasteSummary.fromJson(Map<String, dynamic> json) {
    return WasteSummary(
      totalConsumed: json['total_consumed'] as int,
      totalDiscarded: json['total_discarded'] as int,
      mostWastedCategory: json['most_wasted_category'] as String?,
      mostDiscardedItem: json['most_discarded_item'] as String?,
      noWasteStreakDays: json['no_waste_streak_days'] as int,
    );
  }
}

class UserSegment {
  final String segment;
  final int recipesCookedLast30Days;
  final double openRate;

  const UserSegment({
    required this.segment,
    required this.recipesCookedLast30Days,
    required this.openRate,
  });

  factory UserSegment.fromJson(Map<String, dynamic> json) {
    return UserSegment(
      segment: json['segment'] as String,
      recipesCookedLast30Days: json['recipes_cooked_last_30_days'] as int,
      openRate: (json['open_rate'] as num).toDouble(),
    );
  }
}

class RecipeRecommendationImpact {
  final String recipeCategory;
  final int totalRecommended;
  final int itemsConsumed;
  final int itemsDiscarded;
  final double wasteReductionPercentage;
  final double estimatedValueSavedCop;

  const RecipeRecommendationImpact({
    required this.recipeCategory,
    required this.totalRecommended,
    required this.itemsConsumed,
    required this.itemsDiscarded,
    required this.wasteReductionPercentage,
    required this.estimatedValueSavedCop,
  });

  factory RecipeRecommendationImpact.fromJson(Map<String, dynamic> json) {
    return RecipeRecommendationImpact(
      recipeCategory:
          (json['recipe_category'] ?? json['category'] ?? 'other') as String,
      totalRecommended: _parseInt(json['total_recommended']),
      itemsConsumed: _parseInt(json['items_consumed']),
      itemsDiscarded: _parseInt(json['items_discarded']),
      wasteReductionPercentage: _parseDouble(
        json['waste_reduction_percentage'] ?? json['reduction_percentage'],
      ),
      estimatedValueSavedCop: _parseDouble(json['estimated_value_saved_cop']),
    );
  }
}

class RecipeImpactResponse {
  final List<RecipeRecommendationImpact> impacts;
  final double totalWasteReductionPercentage;
  final double totalValueSavedCop;

  const RecipeImpactResponse({
    required this.impacts,
    required this.totalWasteReductionPercentage,
    required this.totalValueSavedCop,
  });

  factory RecipeImpactResponse.fromJson(Map<String, dynamic> json) {
    final impactsList =
        (json['impacts'] ?? json['data'] ?? json['recipe_impacts']) as List? ??
        [];
    return RecipeImpactResponse(
      impacts: impactsList
          .map(
            (e) =>
                RecipeRecommendationImpact.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      totalWasteReductionPercentage: _parseDouble(
        json['total_waste_reduction_percentage'] ??
            json['total_reduction_percentage'],
      ),
      totalValueSavedCop: _parseDouble(json['total_value_saved_cop']),
    );
  }
}

class DashboardResponse {
  final SavingsResponse savings;
  final WasteSummary wasteSummary;
  final UserSegment segment;
  final RecipeImpactResponse? recipeImpact;

  const DashboardResponse({
    required this.savings,
    required this.wasteSummary,
    required this.segment,
    this.recipeImpact,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    return DashboardResponse(
      savings: SavingsResponse.fromJson(
        json['savings'] as Map<String, dynamic>,
      ),
      wasteSummary: WasteSummary.fromJson(
        json['waste_summary'] as Map<String, dynamic>,
      ),
      segment: UserSegment.fromJson(json['segment'] as Map<String, dynamic>),
      recipeImpact: json['recipe_impact'] == null
          ? null
          : RecipeImpactResponse.fromJson(
              json['recipe_impact'] as Map<String, dynamic>,
            ),
    );
  }
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
