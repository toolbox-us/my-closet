import '../models/recommendation.dart';

/// Scoring weights.
///
/// Held in one configurable object rather than scattered through widgets, so
/// the engine's behaviour can be tuned - and tested - in one place. The
/// weights sum to 100 so a score reads directly as a percentage match.
class ScoringConfig {
  const ScoringConfig({
    this.occasion = 25,
    this.color = 20,
    this.weather = 20,
    this.style = 15,
    this.season = 10,
    this.diversity = 5,
    this.favorite = 5,
    this.feedbackCap = 5,
  });

  final int occasion;
  final int color;
  final int weather;
  final int style;
  final int season;
  final int diversity;
  final int favorite;

  /// Maximum points feedback can add or remove.
  ///
  /// Capped deliberately: without a ceiling, accumulated likes collapse the
  /// engine into recommending one outfit forever.
  final int feedbackCap;

  static const ScoringConfig standard = ScoringConfig();

  int get total =>
      occasion + color + weather + style + season + diversity + favorite;

  int weightFor(String key) {
    switch (key) {
      case ScoreKeys.occasion:
        return occasion;
      case ScoreKeys.color:
        return color;
      case ScoreKeys.weather:
        return weather;
      case ScoreKeys.style:
        return style;
      case ScoreKeys.season:
        return season;
      case ScoreKeys.diversity:
        return diversity;
      case ScoreKeys.favorite:
        return favorite;
      case ScoreKeys.feedback:
        return feedbackCap;
      default:
        return 0;
    }
  }
}
