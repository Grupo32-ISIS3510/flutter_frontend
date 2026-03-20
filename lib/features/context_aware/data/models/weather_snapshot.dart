class WeatherSnapshot {
  const WeatherSnapshot({
    required this.latitude,
    required this.longitude,
    required this.temperatureCelsius,
    required this.humidity,
    required this.fetchedAt,
  });

  final double latitude;
  final double longitude;
  final double temperatureCelsius;
  final int humidity;
  final DateTime fetchedAt;

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      temperatureCelsius: (json['temperatureCelsius'] as num).toDouble(),
      humidity: (json['humidity'] as num).toInt(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'temperatureCelsius': temperatureCelsius,
      'humidity': humidity,
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }
}
