import 'package:shared_preferences/shared_preferences.dart';

enum WeatherSyncStatus { idle, synced, pending, failed }

class WeatherSyncState {
  const WeatherSyncState({
    required this.status,
    required this.lastSyncedAt,
    required this.pendingSince,
    required this.lastErrorMessage,
  });

  const WeatherSyncState.initial()
      : status = WeatherSyncStatus.idle,
        lastSyncedAt = null,
        pendingSince = null,
        lastErrorMessage = null;

  final WeatherSyncStatus status;
  final DateTime? lastSyncedAt;
  final DateTime? pendingSince;
  final String? lastErrorMessage;

  bool get hasPending =>
      status == WeatherSyncStatus.pending && pendingSince != null;
}

class WeatherSyncCacheService {
  static const String _kStatus = 'weatherSync.status';
  static const String _kLastSyncedAt = 'weatherSync.lastSyncedAt';
  static const String _kPendingSince = 'weatherSync.pendingSince';
  static const String _kLastError = 'weatherSync.lastError';

  Future<WeatherSyncState> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? statusName = prefs.getString(_kStatus);
    final WeatherSyncStatus status = WeatherSyncStatus.values.firstWhere(
      (WeatherSyncStatus s) => s.name == statusName,
      orElse: () => WeatherSyncStatus.idle,
    );
    return WeatherSyncState(
      status: status,
      lastSyncedAt: _parseDate(prefs.getString(_kLastSyncedAt)),
      pendingSince: _parseDate(prefs.getString(_kPendingSince)),
      lastErrorMessage: prefs.getString(_kLastError),
    );
  }

  Future<void> markSynced() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStatus, WeatherSyncStatus.synced.name);
    await prefs.setString(_kLastSyncedAt, DateTime.now().toIso8601String());
    await prefs.remove(_kPendingSince);
    await prefs.remove(_kLastError);
  }

  Future<void> markPending({String? error}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? pendingSinceRaw = prefs.getString(_kPendingSince);
    await prefs.setString(_kStatus, WeatherSyncStatus.pending.name);
    if (pendingSinceRaw == null) {
      await prefs.setString(_kPendingSince, DateTime.now().toIso8601String());
    }
    if (error != null && error.isNotEmpty) {
      await prefs.setString(_kLastError, error);
    }
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStatus);
    await prefs.remove(_kLastSyncedAt);
    await prefs.remove(_kPendingSince);
    await prefs.remove(_kLastError);
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw);
  }
}
