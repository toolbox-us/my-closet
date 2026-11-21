import 'json_utils.dart';

/// Weather used by the recommendation engine.
///
/// Supplied by `MockWeatherService` and editable by the user. A mock with
/// switchable scenarios actually demos better than a live API, because you
/// can show cold-weather recommendations in July.
class Weather {
  const Weather({
    required this.temperatureF,
    required this.condition,
    required this.wind,
    this.humidityPercent,
    this.scenarioName = 'Custom',
    this.location = '',
  });

  final int temperatureF;

  /// One of `Vocab.weatherConditions`.
  final String condition;

  /// One of `Vocab.windLevels`.
  final String wind;

  final int? humidityPercent;

  /// Label of the preset this came from, or 'Custom' once the user edits it.
  final String scenarioName;

  final String location;

  bool get isRaining =>
      condition == 'Light Rain' ||
      condition == 'Heavy Rain' ||
      condition == 'Snow';

  bool get isWet => isRaining;

  bool get isWindy => wind == 'High Wind';

  bool get isHumid => (humidityPercent ?? 0) >= 70;

  /// Needs a layer on top.
  bool get needsOuterwear => temperatureF < 62 || isRaining || isWindy;

  /// 1 = hot, 2 = mild, 3 = cold. Compared against item warmth.
  int get warmthDemand {
    if (temperatureF >= 78) return 1;
    if (temperatureF >= 60) return 2;
    return 3;
  }

  String get summary => '$temperatureF°F, $condition';

  factory Weather.fromJson(Map<String, dynamic> json) => Weather(
        temperatureF: J.integer(json['temperatureF'], 68),
        condition: J.str(json['condition'], 'Sunny'),
        wind: J.str(json['wind'], 'Low Wind'),
        humidityPercent: J.doubleOrNull(json['humidityPercent'])?.round(),
        scenarioName: J.str(json['scenarioName'], 'Custom'),
        location: J.str(json['location']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'temperatureF': temperatureF,
        'condition': condition,
        'wind': wind,
        'humidityPercent': humidityPercent,
        'scenarioName': scenarioName,
        'location': location,
      };

  Weather copyWith({
    int? temperatureF,
    String? condition,
    String? wind,
    int? humidityPercent,
    String? scenarioName,
    String? location,
  }) =>
      Weather(
        temperatureF: temperatureF ?? this.temperatureF,
        condition: condition ?? this.condition,
        wind: wind ?? this.wind,
        humidityPercent: humidityPercent ?? this.humidityPercent,
        scenarioName: scenarioName ?? this.scenarioName,
        location: location ?? this.location,
      );
}
