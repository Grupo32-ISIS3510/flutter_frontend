import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Servicio centralizado que monitorea la conectividad de red.
///
/// Expone un [Stream<bool>] reactivo y un getter síncrono [isOnline]
/// para que cualquier componente sepa si hay red disponible.
///
/// Estrategia de conectividad eventual:
///   - Al detectar reconexión se emite `true` en el stream.
///   - Los consumidores (ConnectivityProvider) escuchan el cambio
///     y disparan sincronización de operaciones pendientes.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _online = true;

  bool get isOnline => _online;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _online = _hasConnection(results);
    debugPrint('[Connectivity] Initial state: ${_online ? "ONLINE" : "OFFLINE"}');

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final nowOnline = _hasConnection(results);
      if (nowOnline != _online) {
        _online = nowOnline;
        _controller.add(_online);
        debugPrint('[Connectivity] Changed → ${_online ? "ONLINE" : "OFFLINE"}');
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
