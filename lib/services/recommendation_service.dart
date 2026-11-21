import '../core/utils/app_utils.dart';
import '../models/feedback_entry.dart';
import '../models/outfit.dart';
import '../models/recommendation.dart';
import '../models/wardrobe_item.dart';
import '../models/weather.dart';
import 'color_rules.dart';
import 'scoring_config.dart';

abstract class RecommendationService {
  /// Best complete outfits for the request.
  List<ScoredOutfit> recommend(RecommendationRequest request, {int limit = 5});

  /// Outfits that all contain [anchor]. The anchor is never dropped.
  List<ScoredOutfit> matchItem(
    WardrobeItem anchor,
    RecommendationRequest request, {
    int limit = 3,
  });

  /// One complete outfit built around [anchor].
  ScoredOutfit? buildAround(
    WardrobeItem anchor,
    RecommendationRequest request,
  );

  /// Re-solves a single slot, holding every other slot fixed.
  ScoredOutfit? replaceSlot(
    Outfit current,
    OutfitSlot slot,
    RecommendationRequest request,
  );

  /// Scores an outfit the user assembled by hand.
  ScoredOutfit scoreOutfit(Outfit outfit, RecommendationRequest request);
}

/// Deterministic, rule-based recommendation engine.
///
/// Deliberately not an LLM call. Three reasons, all of which are arguments
/// worth making in the paper:
///
///   1. It is testable. `test/recommendation_test.dart` asserts that a
///      rain-appropriate outfit outscores shorts at 52 degrees. That test is
///      unwritable against a non-deterministic model.
///   2. It is explainable by construction. Every line in "Why this works"
///      traces to a scoring dimension that actually fired - no model is asked
///      to narrate its own reasoning.
///   3. It is free and instant. The AI budget is spent where a model has a
///      real advantage (visual classification), not on constraint scoring,
///      which rules do better.
class LocalRecommendationService implements RecommendationService {
  const LocalRecommendationService({this.config = ScoringConfig.standard});

  final ScoringConfig config;

  /// How many candidates to keep per slot before combining. Small on
  /// purpose: the product of the pools is what bounds the work.
  static const Map<OutfitSlot, int> _poolDepth = <OutfitSlot, int>{
    OutfitSlot.top: 3,
    OutfitSlot.bottom: 3,
    OutfitSlot.dress: 3,
    OutfitSlot.footwear: 3,
    OutfitSlot.outerwear: 2,
    OutfitSlot.accessory: 2,
  };

  static const int _maxCombinations = 400;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  @override
  List<ScoredOutfit> recommend(
    RecommendationRequest request, {
    int limit = 5,
  }) {
    final List<ScoredOutfit> results = <ScoredOutfit>[
      ..._solve(request, fixed: const <OutfitSlot, String>{}, dressFamily: false),
      ..._solve(request, fixed: const <OutfitSlot, String>{}, dressFamily: true),
    ];
    return _rank(results, limit);
  }

  @override
  List<ScoredOutfit> matchItem(
    WardrobeItem anchor,
    RecommendationRequest request, {
    int limit = 3,
  }) {
    final OutfitSlot? anchorSlot = slotForCategory(anchor.category);
    if (anchorSlot == null) return const <ScoredOutfit>[];

    final Map<OutfitSlot, String> fixed = <OutfitSlot, String>{
      anchorSlot: anchor.id,
    };

    // A dress excludes top/bottom and vice versa, so only the compatible
    // family is worth solving.
    final List<bool> families;
    if (anchorSlot == OutfitSlot.dress) {
      families = const <bool>[true];
    } else if (anchorSlot == OutfitSlot.top ||
        anchorSlot == OutfitSlot.bottom) {
      families = const <bool>[false];
    } else {
      families = const <bool>[false, true];
    }

    final List<ScoredOutfit> results = <ScoredOutfit>[];
    for (final bool dressFamily in families) {
      results.addAll(
        _solve(request, fixed: fixed, dressFamily: dressFamily),
      );
    }

    // Safety net for the invariant the plan calls out: the selected item must
    // always remain in the recommendation.
    final List<ScoredOutfit> withAnchor = results
        .where((ScoredOutfit s) => s.outfit.containsItem(anchor.id))
        .toList();

    return _rank(withAnchor, limit);
  }

  @override
  ScoredOutfit? buildAround(
    WardrobeItem anchor,
    RecommendationRequest request,
  ) {
    final List<ScoredOutfit> matches =
        matchItem(anchor, request, limit: 1);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  ScoredOutfit? replaceSlot(
    Outfit current,
    OutfitSlot slot,
    RecommendationRequest request,
  ) {
    final Map<String, WardrobeItem> byId = _indexById(request.items);

    // Hold every other slot exactly as it is.
    final Map<OutfitSlot, String> fixed = <OutfitSlot, String>{};
    current.items.forEach((OutfitSlot s, String id) {
      if (s != slot) fixed[s] = id;
    });

    final String? currentId = current.items[slot];
    final Set<String> blocked = <String>{
      ...request.excludeItemIds,
      ...fixed.values,
      if (currentId != null) currentId,
    };

    final List<WardrobeItem> pool = _poolFor(
      request.items,
      slot,
      blocked: blocked,
    );
    if (pool.isEmpty) return null;

    ScoredOutfit? best;
    for (final WardrobeItem candidate in pool) {
      final Map<OutfitSlot, String> combo = <OutfitSlot, String>{
        ...fixed,
        slot: candidate.id,
      };
      final ScoredOutfit scored = _scoreCombination(combo, byId, request);
      if (best == null || scored.score > best.score) best = scored;
    }
    return best;
  }

  @override
  ScoredOutfit scoreOutfit(Outfit outfit, RecommendationRequest request) {
    final Map<String, WardrobeItem> byId = _indexById(request.items);
    return _scoreCombination(outfit.items, byId, request, existing: outfit);
  }

  // ---------------------------------------------------------------------------
  // Candidate generation
  // ---------------------------------------------------------------------------

  List<ScoredOutfit> _solve(
    RecommendationRequest request, {
    required Map<OutfitSlot, String> fixed,
    required bool dressFamily,
  }) {
    final Map<String, WardrobeItem> byId = _indexById(request.items);

    // Slots this family fills, excluding anything already fixed.
    final List<OutfitSlot> candidateSlots = <OutfitSlot>[
      if (dressFamily) OutfitSlot.dress else OutfitSlot.top,
      if (!dressFamily) OutfitSlot.bottom,
      OutfitSlot.footwear,
      OutfitSlot.outerwear,
      OutfitSlot.accessory,
    ];

    // A fixed slot from the other family makes this family invalid.
    for (final OutfitSlot slot in fixed.keys) {
      if (!candidateSlots.contains(slot)) return const <ScoredOutfit>[];
    }

    final Set<String> blocked = <String>{
      ...request.excludeItemIds,
      ...fixed.values,
    };

    final Map<OutfitSlot, List<WardrobeItem>> pools =
        <OutfitSlot, List<WardrobeItem>>{};
    for (final OutfitSlot slot in candidateSlots) {
      if (fixed.containsKey(slot)) continue;
      final List<WardrobeItem> pool =
          _poolFor(request.items, slot, blocked: blocked);
      if (pool.isEmpty) continue;

      pool.sort((WardrobeItem a, WardrobeItem b) =>
          _itemScore(b, request).compareTo(_itemScore(a, request)));

      final int depth = _poolDepth[slot] ?? 2;
      pools[slot] = pool.take(depth).toList();
    }

    // What a complete outfit means for this wardrobe. Being driven by pool
    // availability rather than a hard-coded list means a sparse wardrobe
    // still produces suggestions instead of nothing.
    final Set<OutfitSlot> required = <OutfitSlot>{};
    void requireIfAvailable(OutfitSlot slot) {
      if (fixed.containsKey(slot) || pools.containsKey(slot)) {
        required.add(slot);
      }
    }

    if (dressFamily) {
      requireIfAvailable(OutfitSlot.dress);
    } else {
      requireIfAvailable(OutfitSlot.top);
      requireIfAvailable(OutfitSlot.bottom);
    }
    requireIfAvailable(OutfitSlot.footwear);
    if (request.weather.needsOuterwear) {
      requireIfAvailable(OutfitSlot.outerwear);
    }

    if (required.isEmpty) return const <ScoredOutfit>[];

    // Build the combinations. Optional slots carry a null option so the
    // engine can also propose the outfit without them.
    List<Map<OutfitSlot, String>> combos = <Map<OutfitSlot, String>>[
      Map<OutfitSlot, String>.from(fixed),
    ];

    for (final OutfitSlot slot in candidateSlots) {
      final List<WardrobeItem>? pool = pools[slot];
      if (pool == null) continue;

      final bool optional = !required.contains(slot);
      final List<Map<OutfitSlot, String>> next =
          <Map<OutfitSlot, String>>[];

      for (final Map<OutfitSlot, String> combo in combos) {
        if (optional) next.add(combo);
        for (final WardrobeItem item in pool) {
          if (combo.containsValue(item.id)) continue;
          next.add(<OutfitSlot, String>{...combo, slot: item.id});
        }
      }

      combos = next.length > _maxCombinations
          ? next.sublist(0, _maxCombinations)
          : next;
    }

    final List<ScoredOutfit> scored = <ScoredOutfit>[];
    for (final Map<OutfitSlot, String> combo in combos) {
      if (!required.every(combo.containsKey)) continue;
      if (combo.length < 2) continue;
      scored.add(_scoreCombination(combo, byId, request));
    }
    return scored;
  }

  List<WardrobeItem> _poolFor(
    List<WardrobeItem> items,
    OutfitSlot slot, {
    required Set<String> blocked,
  }) {
    final String category = kSlotCategory[slot]!;
    return items
        .where((WardrobeItem i) =>
            i.category == category && !blocked.contains(i.id))
        .toList();
  }

  List<ScoredOutfit> _rank(List<ScoredOutfit> candidates, int limit) {
    candidates.sort((ScoredOutfit a, ScoredOutfit b) {
      final int byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      // Stable tie-break: prefer the more complete outfit, then by signature
      // so results do not reshuffle between identical calls.
      final int byCount = b.items.length.compareTo(a.items.length);
      if (byCount != 0) return byCount;
      return a.signature.compareTo(b.signature);
    });

    final List<ScoredOutfit> out = <ScoredOutfit>[];
    final Set<String> seen = <String>{};
    for (final ScoredOutfit candidate in candidates) {
      if (seen.add(candidate.signature)) out.add(candidate);
      if (out.length >= limit) break;
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Scoring
  // ---------------------------------------------------------------------------

  ScoredOutfit _scoreCombination(
    Map<OutfitSlot, String> combo,
    Map<String, WardrobeItem> byId,
    RecommendationRequest request, {
    Outfit? existing,
  }) {
    final Map<OutfitSlot, String> resolved = <OutfitSlot, String>{};
    final List<WardrobeItem> items = <WardrobeItem>[];

    for (final OutfitSlot slot in kSlotOrder) {
      final String? id = combo[slot];
      if (id == null) continue;
      final WardrobeItem? item = byId[id];
      if (item == null) continue;
      resolved[slot] = id;
      items.add(item);
    }

    if (items.isEmpty) {
      final Outfit empty = existing ?? Outfit.draft();
      return ScoredOutfit(
        outfit: empty.copyWith(items: resolved),
        items: const <WardrobeItem>[],
        score: 0,
        breakdown: const <String, int>{},
        reasons: const <String>[],
      );
    }

    final double occasionFit = _mean(
      items.map((WardrobeItem i) => _occasionFit(i, request.occasion)),
    );
    final double weatherFit = _mean(
      items.map((WardrobeItem i) =>
          _weatherFit(i, request.weather, request.environment)),
    );
    final double styleFit = _mean(
      items.map((WardrobeItem i) => _styleFit(i, request)),
    );
    final double seasonFit = _mean(
      items.map((WardrobeItem i) => _seasonFit(i, request.weather)),
    );
    final double diversityFit = _mean(
      items.map(_diversityFit),
    );
    final double favoriteFit = _mean(
      items.map((WardrobeItem i) => i.favorite ? 1.0 : 0.35),
    );
    final double colorFit = _colorFit(items, request);

    final Map<String, int> breakdown = <String, int>{
      ScoreKeys.occasion: (config.occasion * occasionFit).round(),
      ScoreKeys.color: (config.color * colorFit).round(),
      ScoreKeys.weather: (config.weather * weatherFit).round(),
      ScoreKeys.style: (config.style * styleFit).round(),
      ScoreKeys.season: (config.season * seasonFit).round(),
      ScoreKeys.diversity: (config.diversity * diversityFit).round(),
      ScoreKeys.favorite: (config.favorite * favoriteFit).round(),
    };

    final Outfit outfit = (existing ?? Outfit.draft()).copyWith(
      items: resolved,
      occasion: existing?.occasion ?? request.occasion,
      style: existing?.style ?? request.style,
    );

    final int feedbackAdjustment = _feedbackAdjustment(outfit, request);
    if (feedbackAdjustment != 0) {
      breakdown[ScoreKeys.feedback] = feedbackAdjustment;
    }

    int total = 0;
    breakdown.forEach((String _, int points) => total += points);
    total = total.clamp(0, 100);

    return ScoredOutfit(
      outfit: outfit,
      items: items,
      score: total,
      breakdown: breakdown,
      reasons: _reasons(
        items: items,
        request: request,
        occasionFit: occasionFit,
        weatherFit: weatherFit,
        styleFit: styleFit,
        seasonFit: seasonFit,
        diversityFit: diversityFit,
        colorFit: colorFit,
      ),
    );
  }

  /// Item-level score used only to rank slot pools before combining.
  /// Excludes colour, which is a property of the whole outfit.
  double _itemScore(WardrobeItem item, RecommendationRequest request) {
    return config.occasion * _occasionFit(item, request.occasion) +
        config.weather *
            _weatherFit(item, request.weather, request.environment) +
        config.style * _styleFit(item, request) +
        config.season * _seasonFit(item, request.weather) +
        config.diversity * _diversityFit(item) +
        config.favorite * (item.favorite ? 1.0 : 0.35);
  }

  // --- dimensions ------------------------------------------------------------

  static const Map<String, String> _occasionGroup = <String, String>{
    'Work': 'smart',
    'Interview': 'smart',
    'Wedding': 'smart',
    'Dinner': 'smart',
    'Date': 'smart',
    'Party': 'smart',
    'Casual': 'relaxed',
    'Travel': 'relaxed',
    'Gym': 'active',
    'Hiking': 'active',
  };

  double _occasionFit(WardrobeItem item, String occasion) {
    if (item.occasions.isEmpty) return 0.5;
    if (item.occasions.contains(occasion)) return 1.0;

    final String? wanted = _occasionGroup[occasion];
    if (wanted != null) {
      for (final String owned in item.occasions) {
        if (_occasionGroup[owned] == wanted) return 0.55;
      }
    }
    return 0.15;
  }

  /// 1 = light, 2 = mid, 3 = warm. Inferred from material, bumped for
  /// outerwear. Material is the weakest signal available, which is why
  /// `seasons` carries its own dimension.
  static int warmthOf(WardrobeItem item) {
    int base;
    switch (item.material) {
      case 'Linen':
      case 'Silk':
      case 'Nylon':
        base = 1;
        break;
      case 'Wool':
      case 'Knit':
      case 'Fleece':
      case 'Down':
      case 'Leather':
      case 'Suede':
        base = 3;
        break;
      case 'Cotton':
      case 'Denim':
      case 'Polyester':
        base = 2;
        break;
      default:
        base = 2;
    }
    if (item.category == 'Outerwear') {
      base = base + 1 > 3 ? 3 : base + 1;
    }
    return base;
  }

  double _weatherFit(
    WardrobeItem item,
    Weather weather,
    String environment,
  ) {
    final int demand = weather.warmthDemand;
    final int warmth = warmthOf(item);
    final int diff = (warmth - demand).abs();

    double fit;
    if (diff == 0) {
      fit = 1.0;
    } else if (diff == 1) {
      fit = 0.65;
    } else {
      fit = 0.2;
    }

    if (weather.isRaining) {
      if (item.category == 'Footwear' &&
          (item.material == 'Suede' || item.material == 'Silk')) {
        fit *= 0.4;
      }
      if (item.category == 'Outerwear') {
        fit = fit + 0.3;
      }
    }

    if (environment == 'Outdoor' && !item.outdoor) {
      fit *= 0.5;
    } else if (environment == 'Indoor' && !item.indoor) {
      fit *= 0.7;
    }

    return fit.clamp(0.0, 1.0);
  }

  /// Which seasons the current weather actually feels like.
  static Set<String> seasonsFor(Weather weather) {
    if (weather.temperatureF >= 78) return <String>{'Summer'};
    if (weather.temperatureF >= 62) return <String>{'Spring', 'Fall'};
    if (weather.temperatureF >= 45) return <String>{'Fall'};
    return <String>{'Winter'};
  }

  double _seasonFit(WardrobeItem item, Weather weather) {
    if (item.seasons.isEmpty) return 0.6;
    final Set<String> wanted = seasonsFor(weather);
    for (final String season in item.seasons) {
      if (wanted.contains(season)) return 1.0;
    }
    return 0.3;
  }

  double _styleFit(WardrobeItem item, RecommendationRequest request) {
    final String? requested = request.style;
    final List<String> preferred = request.profile.preferredStyles;

    if (item.styles.isEmpty) return 0.5;

    if (requested != null && requested.isNotEmpty) {
      if (item.styles.contains(requested)) return 1.0;
      for (final String style in item.styles) {
        if (preferred.contains(style)) return 0.6;
      }
      return 0.3;
    }

    if (preferred.isEmpty) return 0.5;
    for (final String style in item.styles) {
      if (preferred.contains(style)) return 1.0;
    }
    return 0.45;
  }

  double _diversityFit(WardrobeItem item) {
    double base;
    if (item.timesWorn == 0) {
      base = 1.0;
    } else if (item.timesWorn <= 3) {
      base = 0.8;
    } else if (item.timesWorn <= 9) {
      base = 0.6;
    } else if (item.timesWorn <= 19) {
      base = 0.4;
    } else {
      base = 0.25;
    }

    final DateTime? lastWorn = item.lastWorn;
    if (lastWorn != null) {
      final int days = DateTime.now().difference(lastWorn).inDays;
      if (days <= 3) base *= 0.5;
    }

    return base.clamp(0.0, 1.0);
  }

  double _colorFit(
    List<WardrobeItem> items,
    RecommendationRequest request,
  ) {
    final List<String> colors =
        items.map((WardrobeItem i) => i.primaryColor).toList();
    double score = ColorRules.outfitScore(colors);

    final List<String> avoided = request.profile.avoidedColors;
    if (avoided.isNotEmpty) {
      for (final WardrobeItem item in items) {
        if (avoided.contains(item.primaryColor)) score *= 0.7;
      }
    }

    final List<String> favorites = request.profile.favoriteColors;
    if (favorites.isNotEmpty) {
      for (final WardrobeItem item in items) {
        if (favorites.contains(item.primaryColor)) {
          score += 0.05;
          break;
        }
      }
    }

    return score.clamp(0.0, 1.0);
  }

  /// Nudges scores from accumulated like/dislike feedback, within
  /// [ScoringConfig.feedbackCap].
  int _feedbackAdjustment(Outfit outfit, RecommendationRequest request) {
    if (request.feedback.isEmpty) return 0;

    final int cap = config.feedbackCap;
    final Set<String> ids = outfit.itemIds.toSet();
    double adjustment = 0;

    for (final FeedbackEntry entry in request.feedback) {
      if (entry.signature == outfit.signature) {
        adjustment += entry.liked ? cap : -cap;
        continue;
      }
      final int overlap =
          entry.itemIds.where(ids.contains).length;
      if (overlap >= 2) {
        adjustment += entry.liked ? cap * 0.5 : -cap * 0.6;
      }
    }

    return adjustment.clamp(-cap.toDouble(), cap.toDouble()).round();
  }

  // --- explanation -----------------------------------------------------------

  /// Builds "Why this works".
  ///
  /// Every line is gated on a dimension that actually scored well, so the
  /// explanation cannot claim something the score does not support.
  List<String> _reasons({
    required List<WardrobeItem> items,
    required RecommendationRequest request,
    required double occasionFit,
    required double weatherFit,
    required double styleFit,
    required double seasonFit,
    required double diversityFit,
    required double colorFit,
  }) {
    final List<String> reasons = <String>[];
    final Weather weather = request.weather;

    if (occasionFit >= 0.75) {
      reasons.add('Appropriate for ${request.occasion.toLowerCase()}');
    }

    if (weatherFit >= 0.7) {
      reasons.add(
        'Suitable for ${weather.temperatureF}°F '
        '${weather.condition.toLowerCase()}',
      );
    }

    if (colorFit >= 0.85 &&
        ColorRules.allCompatible(
          items.map((WardrobeItem i) => i.primaryColor).toList(),
        )) {
      reasons.add('Colors complement each other');
    }

    if (styleFit >= 0.75) {
      final String? requested = request.style;
      reasons.add(
        requested != null && requested.isNotEmpty
            ? 'Matches a $requested look'
            : 'Matches your style preferences',
      );
    }

    if (seasonFit >= 0.8) {
      final Set<String> seasons = seasonsFor(weather);
      reasons.add('Right for ${seasons.join(' / ').toLowerCase()}');
    }

    final bool hasOuterwear =
        items.any((WardrobeItem i) => i.category == 'Outerwear');
    if (weather.isRaining && hasOuterwear) {
      reasons.add('Layered for the rain');
    }

    if (request.environment == 'Outdoor' &&
        items.every((WardrobeItem i) => i.outdoor)) {
      reasons.add(
        'Works outdoors for ${request.occasion.toLowerCase()}',
      );
    }

    if (diversityFit >= 0.8) {
      reasons.add("Uses items you haven't worn recently");
    }

    final List<String> favorites = request.profile.favoriteColors;
    if (favorites.isNotEmpty &&
        items.any((WardrobeItem i) => favorites.contains(i.primaryColor))) {
      reasons.add('Includes a color you like');
    }

    if (reasons.isEmpty) {
      reasons.add('Best available match in your wardrobe');
    }

    return reasons;
  }

  // --- helpers ---------------------------------------------------------------

  static Map<String, WardrobeItem> _indexById(List<WardrobeItem> items) =>
      <String, WardrobeItem>{
        for (final WardrobeItem i in items) i.id: i,
      };

  static double _mean(Iterable<double> values) {
    if (values.isEmpty) return 0;
    double sum = 0;
    int count = 0;
    for (final double v in values) {
      sum += v;
      count++;
    }
    return sum / count;
  }
}

/// Gives a saved/draft outfit a real id when the user stores it.
Outfit materializeOutfit(Outfit outfit, {String? name}) => outfit.copyWith(
      id: outfit.id.isEmpty ? Ids.generate('outfit') : outfit.id,
      name: name ?? outfit.name,
    );
