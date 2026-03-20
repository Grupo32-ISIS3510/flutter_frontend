import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_snapshot.dart';

class WeatherService {
  Future<WeatherSnapshot> fetchCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final Uri uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      <String, String>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'temperature_2m,relative_humidity_2m',
      },
    );

    final http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      throw const WeatherException(
        'No fue posible consultar el clima. Se usarán recomendaciones base.',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    final Map<String, dynamic>? current = data['current'] as Map<String, dynamic>?;
    if (current == null ||
        current['temperature_2m'] == null ||
        current['relative_humidity_2m'] == null) {
      throw const WeatherException(
        'La respuesta del clima llegó incompleta. Se usarán recomendaciones base.',
      );
    }

    return WeatherSnapshot(
      latitude: latitude,
      longitude: longitude,
      temperatureCelsius: (current['temperature_2m'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).round(),
      fetchedAt: DateTime.now(),
    );
  }
}

class WeatherException implements Exception {
  const WeatherException(this.message);

  final String message;

  @override
  String toString() => message;
}
