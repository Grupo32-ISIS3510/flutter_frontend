import 'dart:convert';
// alias `as http` para distinguir http.Client (paquete) de cualquier otro Client.
import 'package:http/http.dart' as http;
import 'package:second_serving_frontend/core/config/api_config.dart';

// EXCEPCIÓN DE DOMINIO: en vez de propagar errores HTTP crudos, los wrappeamos
// en una excepción tipada con info útil para mostrar al usuario.
class ApiException implements Exception {
  final int statusCode;
  final String code;          // Código semántico del backend (e.g. "INVALID_CREDENTIALS")
  final String message;       // Mensaje listo para mostrar al usuario

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  // Factory: parsea el body de error del backend y construye la excepción.
  // Si el body no es JSON válido (e.g. HTML de error 502), cae al fallback.
  factory ApiException.fromResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiException(
        statusCode: response.statusCode,
        code: body['code'] as String? ?? 'UNKNOWN_ERROR',
        message: body['message'] as String? ?? 'Error desconocido',
      );
    } catch (_) {
      // Fallback: respuesta no-JSON (servidor caído, proxy, etc.)
      return ApiException(
        statusCode: response.statusCode,
        code: 'UNKNOWN_ERROR',
        message: 'Error ${response.statusCode}',
      );
    }
  }

  // Helper semántico: 401 = token expirado/inválido → trigger logout.
  bool get isUnauthorized => statusCode == 401;

  // Cuando AuthProvider hace `_error = e.toString()`, este es el texto que se ve.
  @override
  String toString() => message;
}

// CLIENTE HTTP CENTRALIZADO: una sola instancia compartida por toda la app.
// Inyecta el header Authorization automáticamente cuando hay token.
class ApiClient {
  // http.Client mantiene un pool de conexiones reutilizables (HTTP keep-alive).
  // Mucho más eficiente que crear una conexión nueva por cada request.
  final http.Client _client = http.Client();
  String? _token;

  // Setter sintetizado con arrow. AuthService lo llama tras login exitoso.
  void setToken(String? token) => _token = token;
  String? get token => _token;

  // GETTER (no campo): se evalúa en CADA llamada → siempre refleja el token actual.
  // Si fuera campo final, quedaría con el token inicial aunque cambiara después.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        // Collection-if: solo agrega Authorization si hay token
        // (evita mandar "Authorization: Bearer null" en /auth/login).
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? queryParams}) async {
    // Uri.parse + replace permite agregar ?key=value de forma limpia y segura
    // (escapa caracteres automáticamente).
    final uri = Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: queryParams);

    // .timeout() es CRÍTICO en mobile: sin esto, una red mala dejaría el
    // Future colgado para siempre → spinner eterno en la UI.
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    // jsonEncode convierte el Map de Dart en string JSON.
    // Solo serializamos si hay body (algunos POST son sin payload).
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

  // Manejo centralizado de respuesta HTTP: éxito → decodificar; error → throw.
  Map<String, dynamic> _handleResponse(http.Response response) {
    // Códigos 2xx = éxito (200 OK, 201 Created, 204 No Content...).
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};        // 204 No Content
      final decoded = jsonDecode(response.body);
      // Si la respuesta es array crudo (e.g. [item1, item2]), lo envolvemos
      // en {'data': [...]} para que la firma del método siga siendo Map.
      if (decoded is List) return {'data': decoded};
      return decoded as Map<String, dynamic>;
    }
    // Cualquier otro código = error → lanza excepción tipada.
    // Las capas superiores (service, provider) hacen try/catch.
    throw ApiException.fromResponse(response);
  }

  // Llamado al cerrar la app o al hacer hot-restart en desarrollo.
  // Cierra el pool de conexiones para liberar sockets.
  void dispose() => _client.close();
}
