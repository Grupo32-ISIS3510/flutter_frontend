import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:second_serving_frontend/core/connectivity/connectivity_service.dart';
import 'package:second_serving_frontend/features/inventory/providers/inventory_provider.dart';
import 'package:second_serving_frontend/features/inventory/services/expiry_telemetry_service.dart';
import 'package:second_serving_frontend/features/inventory/services/screen_analytics_service.dart';
import 'package:second_serving_frontend/features/inventory/services/scan_telemetry_service.dart';
import 'package:second_serving_frontend/features/analytics/services/feature_usage_telemetry_service.dart';

/// ViewModel de conectividad (patrón MVVM).
///
/// Estrategia de Conectividad Eventual:
///   - Escucha cambios de red vía [ConnectivityService].
///   - Al pasar de offline → online, ejecuta automáticamente:
///     1. syncPendingOperations() → reintenta CRUD que falló offline
///     2. flush de telemetría (scan, expiry, screen analytics)
///     3. recarga del inventario para obtener datos frescos
///   - Expone [isOnline] para que la UI muestre un banner offline.
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _service;
  final InventoryProvider _inventoryProvider;
  final ExpiryTelemetryService _expiryTelemetry;
  final ScreenAnalyticsService _screenAnalytics;
  final ScanTelemetryService _scanTelemetry;
  final FeatureUsageTelemetryService _featureUsage;

  StreamSubscription<bool>? _subscription;
  bool _isOnline = true;
  bool _isSyncing = false;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  ConnectivityProvider({
    required ConnectivityService connectivityService,
    required InventoryProvider inventoryProvider,
    required ExpiryTelemetryService expiryTelemetry,
    required ScreenAnalyticsService screenAnalytics,
    required ScanTelemetryService scanTelemetry,
    required FeatureUsageTelemetryService featureUsage,
  })  : _service = connectivityService,
        _inventoryProvider = inventoryProvider,
        _expiryTelemetry = expiryTelemetry,
        _screenAnalytics = screenAnalytics,
        _scanTelemetry = scanTelemetry,
        _featureUsage = featureUsage {
    _isOnline = _service.isOnline;
    _subscription = _service.onStatusChange.listen(_onChanged);
  }

  void _onChanged(bool online) {
    final wasOffline = !_isOnline;
    _isOnline = online;
    notifyListeners();

    if (online && wasOffline) {
      debugPrint('[ConnectivityProvider] Back online → triggering sync');
      _syncAll();
    }
  }

  Future<void> _syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      await _inventoryProvider.syncPendingOperations();

      await Future.wait([
        _scanTelemetry.flushPendingToBackend(),
        _expiryTelemetry.flushToBackend(),
        _screenAnalytics.flushToBackend(),
        _featureUsage.flushToBackend(),
      ]);

      await _inventoryProvider.loadItems();
    } catch (e) {
      debugPrint('[ConnectivityProvider] Sync error: $e');
    }

    _isSyncing = false;
    notifyListeners();
  }

  /// Permite forzar una sincronización manual desde la UI.
  Future<void> forceSync() async {
    if (!_isOnline || _isSyncing) return;
    await _syncAll();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
