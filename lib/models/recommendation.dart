import 'feedback_entry.dart';
import 'outfit.dart';
import 'user_profile.dart';
import 'wardrobe_item.dart';
import 'weather.dart';

/// Everything the recommendation engine needs.
///
/// Passed in explicitly rather than read from providers inside the engine, so
/// the engine stays a pure function of its inputs and is therefore unit
/// testable without Flutter, Hive or Riverpod.
class RecommendationRequest {
  const RecommendationRequest({
    required this.items,
    required this.profile,
    required this.occasion,
    required this.environment,
    required this.weather,
    this.style,
    this.feedback = const <FeedbackEntry>[],
    this.excludeItemIds = const <String>{},
  });

  final List<WardrobeItem> items;
  final UserProfile profile;

  /// One of `Vocab.occasions`.
  final String occasion;

  /// One of `Vocab.environments`.
  final String environment;

  final Weather weather;

  /// Optional requested style, one of `Vocab.styles`.
  final String? style;

  final List<FeedbackEntry> feedback;

  /// Items to keep out of results - used by "Replace" to cycle alternatives.
  final Set<String> excludeItemIds;

  RecommendationRequest copyWith({
    List<WardrobeItem>? items,
    String? occasion,
    String? environment,
    Weather? weather,
    String? style,
    Set<String>? excludeItemIds,
  }) =>
      RecommendationRequest(
        items: items ?? this.items,
        profile: profile,
        occasion: occasion ?? this.occasion,
        environment: environment ?? this.environment,
        weather: weather ?? this.weather,
        style: style ?? this.style,
        feedback: feedback,
        excludeItemIds: excludeItemIds ?? this.excludeItemIds,
      );
}

/// The named scoring dimensions. Kept as constants so tests and the UI
/// reference the same keys rather than duplicating string literals.
class ScoreKeys {
  ScoreKeys._();

  static const String occasion = 'occasion';
  static const String color = 'color';
  static const String weather = 'weather';
  static const String style = 'style';
  static const String season = 'season';
  static const String diversity = 'diversity';
  static const String favorite = 'favorite';
  static const String feedback = 'feedback';

  static const List<String> all = <String>[
    occasion,
    color,
    weather,
    style,
    season,
    diversity,
    favorite,
    feedback,
  ];

  static const Map<String, String> labels = <String, String>{
    occasion: 'Occasion match',
    color: 'Color compatibility',
    weather: 'Weather match',
    style: 'Style preference',
    season: 'Season match',
    diversity: 'Wear diversity',
    favorite: 'Favorites',
    feedback: 'Your feedback',
  };
}

/// A scored outfit plus the reasons behind the score.
///
/// Every entry in [reasons] is derived from a scoring dimension that actually
/// fired, so the "Why this works" list is auditable - no LLM narration.
class ScoredOutfit {
  const ScoredOutfit({
    required this.outfit,
    required this.items,
    required this.score,
    required this.breakdown,
    required this.reasons,
  });

  final Outfit outfit;

  /// Resolved items, in slot order.
  final List<WardrobeItem> items;

  /// 0-100.
  final int score;

  /// Dimension key -> points awarded.
  final Map<String, int> breakdown;

  final List<String> reasons;

  String get signature => outfit.signature;

  ScoredOutfit copyWith({Outfit? outfit, List<WardrobeItem>? items}) =>
      ScoredOutfit(
        outfit: outfit ?? this.outfit,
        items: items ?? this.items,
        score: score,
        breakdown: breakdown,
        reasons: reasons,
      );
}
