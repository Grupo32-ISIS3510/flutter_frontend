import 'dart:convert';

import 'package:http/http.dart' as http;

class NotificationsApiService {
  NotificationsApiService({
    required String baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl,
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Future<void> registerDevice({
    required String authToken,
    required String fcmToken,
    required String platform,
  }) async {
    final Uri uri = Uri.parse('$_baseUrl/api/v1/notifications/device');

    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(<String, String>{
        'fcm_token': fcmToken,
        'platform': platform,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Error registrando dispositivo (${response.statusCode}): ${response.body}',
      );
    }
  }
}
