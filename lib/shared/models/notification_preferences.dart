class NotificationPreferences {
  final int daysBeforeExpiry;
  final int? quietHoursStart;
  final int? quietHoursEnd;
  final bool pushEnabled;

  const NotificationPreferences({
    required this.daysBeforeExpiry,
    this.quietHoursStart,
    this.quietHoursEnd,
    required this.pushEnabled,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      daysBeforeExpiry: json['days_before_expiry'] as int,
      quietHoursStart: json['quiet_hours_start'] as int?,
      quietHoursEnd: json['quiet_hours_end'] as int?,
      pushEnabled: json['push_enabled'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'days_before_expiry': daysBeforeExpiry,
        'quiet_hours_start': quietHoursStart,
        'quiet_hours_end': quietHoursEnd,
        'push_enabled': pushEnabled,
      };

  NotificationPreferences copyWith({
    int? daysBeforeExpiry,
    int? quietHoursStart,
    int? quietHoursEnd,
    bool? pushEnabled,
  }) {
    return NotificationPreferences(
      daysBeforeExpiry: daysBeforeExpiry ?? this.daysBeforeExpiry,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      pushEnabled: pushEnabled ?? this.pushEnabled,
    );
  }
}
