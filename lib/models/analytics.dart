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

class DashboardResponse {
  final SavingsResponse savings;
  final WasteSummary wasteSummary;
  final UserSegment segment;

  const DashboardResponse({
    required this.savings,
    required this.wasteSummary,
    required this.segment,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    return DashboardResponse(
      savings: SavingsResponse.fromJson(json['savings'] as Map<String, dynamic>),
      wasteSummary: WasteSummary.fromJson(json['waste_summary'] as Map<String, dynamic>),
      segment: UserSegment.fromJson(json['segment'] as Map<String, dynamic>),
    );
  }
}
