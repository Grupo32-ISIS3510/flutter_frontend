import 'dart:async';

import '../data/models/weather_snapshot.dart';
import '../data/services/location_service.dart';
import '../data/services/weather_cache_service.dart';
import '../data/services/weather_service.dart';
import '../domain/storage_recommendation_engine.dart';

class ContextAwareState {
  const ContextAwareState({
    required this.weather,
    required this.recommendation,
    required this.statusMessage,
    required this.fromCache,
    required this.usingFallback,
  });

  final WeatherSnapshot? weather;
  final StorageRecommendation recommendation;
  final String statusMessage;
  final bool fromCache;
  final bool usingFallback;
}

class ContextAwareService {
  ContextAwareService({
    required LocationService locationService,
    required WeatherService weatherService,
    required WeatherCacheService cacheService,
    required StorageRecommendationEngine recommendationEngine,
  })  : _locationService = locationService,
        _weatherService = weatherService,
        _cacheService = cacheService,
        _recommendationEngine = recommendationEngine;

  final LocationService _locationService;
  final WeatherService _weatherService;
  final WeatherCacheService _cacheService;
  final StorageRecommendationEngine _recommendationEngine;

  Future<ContextAwareState> loadContextAwareState() async {
    try {
      final WeatherSnapshot? cachedSnapshot = await _cacheService.readValidSnapshot();
      if (cachedSnapshot != null) {
        return ContextAwareState(
          weather: cachedSnapshot,
          recommendation: _recommendationEngine.buildForWeather(cachedSnapshot),
          statusMessage: 'Clima obtenido desde caché (< 1 hora).',
          fromCache: true,
          usingFallback: false,
        );
      }

      final position = await _locationService
          .getCurrentPosition()
          .timeout(const Duration(seconds: 8));
      final WeatherSnapshot weather = await _weatherService.fetchCurrentWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      await _cacheService.saveSnapshot(weather);

      return ContextAwareState(
        weather: weather,
        recommendation: _recommendationEngine.buildForWeather(weather),
        statusMessage: 'Clima actualizado en tiempo real por ubicación GPS.',
        fromCache: false,
        usingFallback: false,
      );
    } catch (error) {
      return ContextAwareState(
        weather: null,
        recommendation: _recommendationEngine.buildForWeather(null),
        statusMessage: error is TimeoutException
            ? 'No se pudo obtener ubicación a tiempo. Se muestran tips base.'
            : error.toString(),
        fromCache: false,
        usingFallback: true,
      );
    }
  }
}
