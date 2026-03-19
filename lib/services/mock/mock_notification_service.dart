import 'package:second_serving_frontend/models/notification_preferences.dart';
import 'package:second_serving_frontend/services/mock/mock_data.dart';
import 'package:second_serving_frontend/services/notification_service.dart';

class MockNotificationApiService implements NotificationApiService {
  NotificationPreferences _prefs = MockData.notificationPrefs;

  @override
  Future<void> registerDevice({required String fcmToken, String platform = 'android_flutter'}) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<NotificationPreferences> getPreferences() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _prefs;
  }

  @override
  Future<NotificationPreferences> updatePreferences(Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _prefs = _prefs.copyWith(
      daysBeforeExpiry: data['days_before_expiry'] as int? ?? _prefs.daysBeforeExpiry,
      quietHoursStart: data['quiet_hours_start'] as int? ?? _prefs.quietHoursStart,
      quietHoursEnd: data['quiet_hours_end'] as int? ?? _prefs.quietHoursEnd,
      pushEnabled: data['push_enabled'] as bool? ?? _prefs.pushEnabled,
    );
    return _prefs;
  }
}
