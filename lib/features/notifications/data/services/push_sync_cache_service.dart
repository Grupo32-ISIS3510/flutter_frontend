import 'package:shared_preferences/shared_preferences.dart';

enum PushSyncStatus { idle, synced, pending, failed }

class PushSyncState {
  const PushSyncState({
    required this.status,
    required this.token,
    required this.lastSyncedAt,
    required this.pendingSince,
    required this.lastErrorMessage,
  });

  const PushSyncState.initial()
      : status = PushSyncStatus.idle,
        token = null,
        lastSyncedAt = null,
        pendingSince = null,
        lastErrorMessage = null;

  final PushSyncStatus status;
  final String? token;
  final DateTime? lastSyncedAt;
  final DateTime? pendingSince;
  final String? lastErrorMessage;

  bool get hasPending =>
      status == PushSyncStatus.pending && token != null && token!.isNotEmpty;
}

class PushSyncCacheService {
  static const String _kToken = 'pushSync.token';
  static const String _kStatus = 'pushSync.status';
  static const String _kLastSyncedAt = 'pushSync.lastSyncedAt';
  static const String _kPendingSince = 'pushSync.pendingSince';
  static const String _kLastError = 'pushSync.lastError';

  Future<PushSyncState> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? statusName = prefs.getString(_kStatus);
    final PushSyncStatus status = PushSyncStatus.values.firstWhere(
      (PushSyncStatus s) => s.name == statusName,
      orElse: () => PushSyncStatus.idle,
    );
    return PushSyncState(
      status: status,
      token: prefs.getString(_kToken),
      lastSyncedAt: _parseDate(prefs.getString(_kLastSyncedAt)),
      pendingSince: _parseDate(prefs.getString(_kPendingSince)),
      lastErrorMessage: prefs.getString(_kLastError),
    );
  }

  Future<void> markSynced(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kStatus, PushSyncStatus.synced.name);
    await prefs.setString(_kLastSyncedAt, DateTime.now().toIso8601String());
    await prefs.remove(_kPendingSince);
    await prefs.remove(_kLastError);
  }

  Future<void> markPending(String token, {String? error}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? pendingSinceRaw = prefs.getString(_kPendingSince);
    await prefs.setString(_kToken, token);
    await prefs.setString(_kStatus, PushSyncStatus.pending.name);
    if (pendingSinceRaw == null) {
      await prefs.setString(_kPendingSince, DateTime.now().toIso8601String());
    }
    if (error != null && error.isNotEmpty) {
      await prefs.setString(_kLastError, error);
    }
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
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
