import '../data/models/weather_snapshot.dart';

class StorageRecommendation {
  const StorageRecommendation({
    required this.storageLabel,
    required this.alertText,
    required this.tips,
  });

  final String storageLabel;
  final String alertText;
  final List<String> tips;
}

class StorageRecommendationEngine {
  const StorageRecommendationEngine();

  StorageRecommendation buildForWeather(WeatherSnapshot? weather) {
    if (weather == null) {
      return const StorageRecommendation(
        storageLabel: 'Neutro',
        alertText: 'Clima no disponible — usa conservación estándar.',
        tips: <String>[
          'Si ya está maduro, guárdalo en la nevera para ralentizar el proceso.',
          'Mantén frutas delicadas lejos del sol y fuentes de calor.',
          'Revisa golpes o manchas y prioriza consumir las piezas más maduras.',
        ],
      );
    }

    final double temperature = weather.temperatureCelsius;
    final int humidity = weather.humidity;

    if (temperature >= 28 || humidity >= 80) {
      return const StorageRecommendation(
        storageLabel: 'Nevera',
        alertText: 'Hace calor/humedad alta — refrigera para conservar más.',
        tips: <String>[
          'Si ya está maduro, guárdalo en la nevera para detener la maduración.',
          'Evita dejarlo junto a plátanos o manzanas para no acelerar el proceso.',
          'Sécalo antes de guardarlo para reducir humedad superficial.',
        ],
      );
    }

    if (temperature <= 12) {
      return const StorageRecommendation(
        storageLabel: 'Ambiente fresco',
        alertText: 'Temperatura baja — conserva a temperatura ambiente estable.',
        tips: <String>[
          'No lo expongas a cambios bruscos de temperatura.',
          'Si está verde, mantenlo fuera de la nevera para que madure mejor.',
          'Al madurar, pásalo a la nevera para extender 1–2 días su vida útil.',
        ],
      );
    }

    return const StorageRecommendation(
      storageLabel: 'Mixto',
      alertText: 'Clima templado — combina ambiente y refrigeración según madurez.',
      tips: <String>[
        'Si está firme, mantenlo fuera de la nevera en un lugar ventilado.',
        'Cuando ceda al tacto, pásalo a nevera para frenar la maduración.',
        'Evita golpes para prevenir manchas internas y oxidación temprana.',
      ],
    );
  }
}
