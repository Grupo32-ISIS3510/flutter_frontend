import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_snapshot.dart';

class WeatherCacheService {
  static const String _snapshotKey = 'contextAware.weatherSnapshot';
  static const Duration _validFor = Duration(hours: 1);

  Future<WeatherSnapshot?> readValidSnapshot() async {
    final WeatherSnapshot? snapshot = await readAnySnapshot();
    if (snapshot == null) {
      return null;
    }

    final DateTime now = DateTime.now();
    if (now.difference(snapshot.fetchedAt) > _validFor) {
      return null;
    }

    return snapshot;
  }

  Future<WeatherSnapshot?> readAnySnapshot() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_snapshotKey);
    if (raw == null) {
      return null;
    }

    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return WeatherSnapshot.fromJson(json);
  }

  Future<void> saveSnapshot(WeatherSnapshot snapshot) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snapshotKey, jsonEncode(snapshot.toJson()));
  }
}
