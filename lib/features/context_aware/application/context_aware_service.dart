import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../data/models/weather_snapshot.dart';
import '../data/services/location_service.dart';
import '../data/services/weather_cache_service.dart';
import '../data/services/weather_service.dart';
import '../data/services/weather_sync_cache_service.dart';
import '../domain/storage_recommendation_engine.dart';

class ContextAwareState {
  const ContextAwareState({
    required this.weather,
    required this.recommendation,
    required this.statusMessage,
    required this.fromCache,
    required this.usingFallback,
    required this.isStale,
  });

  final WeatherSnapshot? weather;
  final StorageRecommendation recommendation;
  final String statusMessage;
  final bool fromCache;
  final bool usingFallback;
  final bool isStale;
}

class ContextAwareService {
  ContextAwareService({
    required LocationService locationService,
    required WeatherService weatherService,
    required WeatherCacheService cacheService,
    required StorageRecommendationEngine recommendationEngine,
    WeatherSyncCacheService? syncCacheService,
    Connectivity? connectivity,
  })  : _locationService = locationService,
        _weatherService = weatherService,
        _cacheService = cacheService,
        _recommendationEngine = recommendationEngine,
        _syncCacheService = syncCacheService ?? WeatherSyncCacheService(),
        _connectivity = connectivity ?? Connectivity() {
    _listenToConnectivity();
  }

  final LocationService _locationService;
  final WeatherService _weatherService;
  final WeatherCacheService _cacheService;
  final StorageRecommendationEngine _recommendationEngine;
  final WeatherSyncCacheService _syncCacheService;
  final Connectivity _connectivity;
  final StreamController<WeatherSyncState> _syncStatusController =
      StreamController<WeatherSyncState>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _retryInFlight = false;

  Stream<WeatherSyncState> get onSyncStatusChanged =>
      _syncStatusController.stream;

  Future<WeatherSyncState> readSyncStatus() => _syncCacheService.read();

  Future<ContextAwareState> loadContextAwareState() async {
    final WeatherSnapshot? cachedSnapshot =
        await _cacheService.readValidSnapshot();
    if (cachedSnapshot != null) {
      await _syncCacheService.markSynced();
      _emitStatusAsync();
      return ContextAwareState(
        weather: cachedSnapshot,
        recommendation: _recommendationEngine.buildForWeather(cachedSnapshot),
        statusMessage: 'Clima obtenido desde caché (< 1 hora).',
        fromCache: true,
        usingFallback: false,
        isStale: false,
      );
    }

    try {
      final position = await _locationService
          .getCurrentPosition()
          .timeout(const Duration(seconds: 8));
      final WeatherSnapshot weather = await _weatherService.fetchCurrentWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      await _cacheService.saveSnapshot(weather);
      await _syncCacheService.markSynced();
      _emitStatusAsync();

      return ContextAwareState(
        weather: weather,
        recommendation: _recommendationEngine.buildForWeather(weather),
        statusMessage: 'Clima actualizado en tiempo real por ubicación GPS.',
        fromCache: false,
        usingFallback: false,
        isStale: false,
      );
    } catch (error) {
      await _syncCacheService.markPending(error: error.toString());
      _emitStatusAsync();

      final WeatherSnapshot? staleSnapshot =
          await _cacheService.readAnySnapshot();
      if (staleSnapshot != null) {
        return ContextAwareState(
          weather: staleSnapshot,
          recommendation: _recommendationEngine.buildForWeather(staleSnapshot),
          statusMessage:
              'Sin conexión. Mostrando clima del ${_formatStaleTime(staleSnapshot.fetchedAt)}. '
              'Se actualizará cuando regrese la conexión.',
          fromCache: true,
          usingFallback: false,
          isStale: true,
        );
      }

      return ContextAwareState(
        weather: null,
        recommendation: _recommendationEngine.buildForWeather(null),
        statusMessage: error is TimeoutException
            ? 'No se pudo obtener ubicación a tiempo. Reintentaremos al recuperar conexión.'
            : 'Sin conexión. Se reintentará automáticamente al recuperar red.',
        fromCache: false,
        usingFallback: true,
        isStale: false,
      );
    }
  }

  Future<void> retryPendingSync() async {
    if (_retryInFlight) {
      return;
    }
    _retryInFlight = true;
    try {
      final WeatherSyncState state = await _syncCacheService.read();
      if (!state.hasPending) {
        return;
      }

      final position = await _locationService
          .getCurrentPosition()
          .timeout(const Duration(seconds: 8));
      final WeatherSnapshot weather = await _weatherService.fetchCurrentWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      await _cacheService.saveSnapshot(weather);
      await _syncCacheService.markSynced();
      _emitStatusAsync();
    } catch (error) {
      await _syncCacheService.markPending(error: error.toString());
      _emitStatusAsync();
    } finally {
      _retryInFlight = false;
    }
  }

  void _listenToConnectivity() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final bool hasConnection = results.any(
        (ConnectivityResult r) => r != ConnectivityResult.none,
      );
      if (hasConnection) {
        unawaited(retryPendingSync());
      }
    });
  }

  void _emitStatusAsync() {
    unawaited(
      _syncCacheService.read().then((WeatherSyncState state) {
        if (!_syncStatusController.isClosed) {
          _syncStatusController.add(state);
        }
      }).catchError((_) {}),
    );
  }

  String _formatStaleTime(DateTime fetchedAt) {
    final Duration elapsed = DateTime.now().difference(fetchedAt);
    if (elapsed.inHours >= 1) {
      final int hours = elapsed.inHours;
      return hours == 1 ? 'hace 1 hora' : 'hace $hours horas';
    }
    final int minutes = elapsed.inMinutes;
    return minutes <= 1 ? 'hace 1 minuto' : 'hace $minutes minutos';
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
  }
}
