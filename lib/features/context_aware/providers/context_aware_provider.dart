import 'package:flutter/material.dart';

import '../application/context_aware_service.dart';
import '../data/models/weather_snapshot.dart';
import '../data/services/location_service.dart';
import '../data/services/weather_cache_service.dart';
import '../data/services/weather_service.dart';
import '../domain/storage_recommendation_engine.dart';

class ContextAwareProvider extends ChangeNotifier {
  final ContextAwareService _service;
  final StorageRecommendationEngine _engine;

  WeatherSnapshot? _weather;
  StorageRecommendation _recommendation = const StorageRecommendation(
    storageLabel: 'Neutro',
    alertText: 'Cargando recomendaciones...',
    tips: <String>[],
  );
  String _statusMessage = 'Cargando clima local...';
  bool _fromCache = false;
  bool _usingFallback = true;
  bool _isLoading = false;

  ContextAwareProvider({
    ContextAwareService? service,
    StorageRecommendationEngine? engine,
  })  : _engine = engine ?? const StorageRecommendationEngine(),
        _service = service ??
            ContextAwareService(
              locationService: LocationService(),
              weatherService: WeatherService(),
              cacheService: WeatherCacheService(),
              recommendationEngine:
                  engine ?? const StorageRecommendationEngine(),
            ) {
    _recommendation = _engine.buildForWeather(null);
  }

  WeatherSnapshot? get weather => _weather;
  StorageRecommendation get recommendation => _recommendation;
  String get statusMessage => _statusMessage;
  bool get fromCache => _fromCache;
  bool get usingFallback => _usingFallback;
  bool get isLoading => _isLoading;

  Future<void> loadContext() async {
    _isLoading = true;
    notifyListeners();

    final ContextAwareState state = await _service.loadContextAwareState();

    _weather = state.weather;
    _recommendation = state.recommendation;
    _statusMessage = state.statusMessage;
    _fromCache = state.fromCache;
    _usingFallback = state.usingFallback;
    _isLoading = false;

    notifyListeners();
  }
}
