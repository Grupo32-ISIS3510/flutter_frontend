import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/connectivity/connectivity_service.dart';

/// Envuelve a un [child] mostrando una franja superior cuando no hay red.
///
/// Se inserta en `MaterialApp.router(builder: ...)` para que se muestre por
/// encima de cualquier ruta sin afectar la navegación.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final service = context.read<ConnectivityService>();

    return Material(
      type: MaterialType.transparency,
      child: StreamBuilder<bool>(
        stream: service.onStatusChange,
        initialData: service.isOnline,
        builder: (context, snapshot) {
          final isOnline = snapshot.data ?? true;
          return Column(
            children: [
              if (!isOnline) const _OfflineStrip(),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        color: const Color(0xFF424242),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'Sin conexión — modo offline',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
