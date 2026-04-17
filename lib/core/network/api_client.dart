import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:second_serving_frontend/core/config/api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  factory ApiException.fromResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiException(
        statusCode: response.statusCode,
        code: body['code'] as String? ?? 'UNKNOWN_ERROR',
        message: body['message'] as String? ?? 'Error desconocido',
      );
    } catch (_) {
      return ApiException(
        statusCode: response.statusCode,
        code: 'UNKNOWN_ERROR',
        message: 'Error ${response.statusCode}',
      );
    }
  }

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _client = http.Client();
  String? _token;

  void setToken(String? token) => _token = token;
  String? get token => _token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: queryParams);

    final response = await _client
        .get(uri, headers: _headers)
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final response = await _client
        .post(uri, headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String path,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final response = await _client
        .put(uri, headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(String path,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final response = await _client
        .patch(uri, headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  Future<void> delete(String path) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final response = await _client
        .delete(uri, headers: _headers)
        .timeout(ApiConfig.timeout);

    if (response.statusCode != 204 && response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw ApiException.fromResponse(response);
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(response.body);
      if (decoded is List) return {'data': decoded};
      return decoded as Map<String, dynamic>;
    }
    throw ApiException.fromResponse(response);
  }

  void dispose() => _client.close();
}
