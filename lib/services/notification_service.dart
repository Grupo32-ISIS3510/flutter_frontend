import 'package:second_serving_frontend/config/api_config.dart';
import 'package:second_serving_frontend/models/notification_preferences.dart';
import 'package:second_serving_frontend/services/api_client.dart';

abstract class NotificationApiService {
  Future<void> registerDevice({required String fcmToken, String platform = 'android_flutter'});
  Future<NotificationPreferences> getPreferences();
  Future<NotificationPreferences> updatePreferences(Map<String, dynamic> data);
}

class NotificationApiServiceImpl implements NotificationApiService {
  final ApiClient _client;

  NotificationApiServiceImpl(this._client);

  @override
  Future<void> registerDevice({required String fcmToken, String platform = 'android_flutter'}) async {
    await _client.post(ApiConfig.notificationDevice, body: {
      'fcm_token': fcmToken,
      'platform': platform,
    });
  }

  @override
  Future<NotificationPreferences> getPreferences() async {
    final response = await _client.get(ApiConfig.notificationPreferences);
    return NotificationPreferences.fromJson(response);
  }

  @override
  Future<NotificationPreferences> updatePreferences(Map<String, dynamic> data) async {
    final response = await _client.put(ApiConfig.notificationPreferences, body: data);
    return NotificationPreferences.fromJson(response);
  }
}
