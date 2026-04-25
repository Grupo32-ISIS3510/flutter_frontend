import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Fuente única de verdad sobre la conectividad de red del dispositivo.
///
/// Detecta cambios entre WiFi/datos/ethernet/VPN y "sin red", y los expone
/// como un [Stream<bool>] para que cualquier widget pueda reaccionar.
///
/// Nota: solo verifica si hay un transporte físico activo. No hace ping a un
/// host real, por lo que un WiFi conectado a un router sin internet aparecerá
/// como "online". Una verificación más estricta queda para una fase posterior.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;

  /// Estado actual cacheado en memoria. Sincrónico para evitar awaits en builds.
  bool get isOnline => _isOnline;

  /// Stream broadcast de cambios de conectividad. Solo emite cuando el estado
  /// realmente cambia (deduplicado por igualdad).
  Stream<bool> get onStatusChange => _controller.stream;

  /// Lee el estado inicial y se suscribe a cambios. Llamar UNA vez en `main()`.
  Future<void> initialize() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      _isOnline = _mapResult(initial);
    } catch (e) {
      debugPrint('[ConnectivityService] checkConnectivity failed: $e');
      _isOnline = true; // Fallback optimista: asumimos online si no podemos saber.
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        final next = _mapResult(results);
        if (next != _isOnline) {
          _isOnline = next;
          _controller.add(next);
        }
      },
      onError: (Object e) {
        debugPrint('[ConnectivityService] stream error: $e');
      },
    );
  }

  bool _mapResult(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
