import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/config/app_theme.dart';
import 'package:second_serving_frontend/features/analytics/services/feature_usage_telemetry_service.dart';
import 'package:second_serving_frontend/shared/models/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pantalla básica de configuración de alertas de vencimiento.
///
/// Persiste las preferencias localmente (SharedPreferences, Tier 1 de la
/// estrategia de almacenamiento local) usando el modelo
/// [NotificationPreferences]. Funciona offline y sin backend.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  static const String _pushEnabledKey = 'notif.push_enabled';
  static const String _daysBeforeExpiryKey = 'notif.days_before_expiry';

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const List<int> _dayOptions = [1, 2, 3, 5, 7];

  NotificationPreferences _prefs = const NotificationPreferences(
    daysBeforeExpiry: 3,
    pushEnabled: true,
  );
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // BQ T4.1 — registrar el uso de la pantalla de notificaciones.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<FeatureUsageTelemetryService>()
          .recordFeatureUse(FeatureIds.notifications);
    });
  }

  Future<void> _load() async {
    final store = await SharedPreferences.getInstance();
    setState(() {
      _prefs = NotificationPreferences(
        pushEnabled:
            store.getBool(NotificationSettingsScreen._pushEnabledKey) ?? true,
        daysBeforeExpiry:
            store.getInt(NotificationSettingsScreen._daysBeforeExpiryKey) ?? 3,
      );
      _isLoading = false;
    });
  }

  Future<void> _save(NotificationPreferences updated) async {
    setState(() => _prefs = updated);
    final store = await SharedPreferences.getInstance();
    await store.setBool(
      NotificationSettingsScreen._pushEnabledKey,
      updated.pushEnabled,
    );
    await store.setInt(
      NotificationSettingsScreen._daysBeforeExpiryKey,
      updated.daysBeforeExpiry,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferencias guardadas'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    value: _prefs.pushEnabled,
                    activeThumbColor: AppColors.primary,
                    title: const Text(
                      'Notificaciones push',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Recibe alertas cuando tus alimentos estén por vencer',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onChanged: (value) =>
                        _save(_prefs.copyWith(pushEnabled: value)),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Avisarme con anticipación',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Días antes del vencimiento para enviar la alerta',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: _dayOptions.map((days) {
                            final isSelected = _prefs.daysBeforeExpiry == days;
                            return ChoiceChip(
                              label: Text('$days día${days == 1 ? '' : 's'}'),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: _prefs.pushEnabled
                                  ? (_) => _save(
                                        _prefs.copyWith(daysBeforeExpiry: days),
                                      )
                                  : null,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
