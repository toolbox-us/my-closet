import '../models/weather.dart';

abstract class WeatherService {
  Future<Weather> getCurrentWeather(String location);

  /// Presets the user can switch between.
  List<Weather> get scenarios;
}

/// Mocked weather.
///
/// Stays mocked on purpose: the course requirements do not call for a weather
/// API, and switchable presets demo *better* than a live one, because you can
/// show cold-weather recommendations in July. Replacing this with a
/// `RealWeatherService` touches no recommendation screen.
class MockWeatherService implements WeatherService {
  const MockWeatherService({this.latency = const Duration(milliseconds: 250)});

  final Duration latency;

  static const Weather sunny = Weather(
    temperatureF: 78,
    condition: 'Sunny',
    wind: 'Low Wind',
    humidityPercent: 40,
    scenarioName: 'Sunny',
  );

  static const Weather cold = Weather(
    temperatureF: 38,
    condition: 'Cloudy',
    wind: 'Moderate Wind',
    humidityPercent: 55,
    scenarioName: 'Cold',
  );

  static const Weather rain = Weather(
    temperatureF: 52,
    condition: 'Light Rain',
    wind: 'Moderate Wind',
    humidityPercent: 80,
    scenarioName: 'Rain',
  );

  static const Weather hot = Weather(
    temperatureF: 94,
    condition: 'Sunny',
    wind: 'Low Wind',
    humidityPercent: 75,
    scenarioName: 'Hot',
  );

  /// The default is the Rain preset so the app's first recommendation matches
  /// the worked example in the implementation plan (52 degrees, light rain).
  /// Reproducible demos beat realistic ones.
  static const Weather defaultScenario = rain;

  @override
  List<Weather> get scenarios =>
      const <Weather>[sunny, cold, rain, hot];

  @override
  Future<Weather> getCurrentWeather(String location) async {
    await Future<void>.delayed(latency);
    return defaultScenario.copyWith(location: location);
  }
}
