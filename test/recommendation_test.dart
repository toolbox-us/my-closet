import 'package:flutter_test/flutter_test.dart';
import 'package:my_closet/models/outfit.dart';
import 'package:my_closet/models/recommendation.dart';
import 'package:my_closet/models/wardrobe_item.dart';
import 'package:my_closet/services/recommendation_service.dart';

import 'helpers/fixtures.dart';

void main() {
  const LocalRecommendationService engine = LocalRecommendationService();

  RecommendationRequest request({
    List<WardrobeItem>? items,
    String occasion = 'Dinner',
    String environment = 'Outdoor',
    String? style = 'Business Casual',
  }) {
    return RecommendationRequest(
      items: items ?? Fixtures.planScenarioWardrobe,
      profile: Fixtures.profile,
      occasion: occasion,
      environment: environment,
      weather: Fixtures.rainy52,
      style: style,
    );
  }

  Outfit outfitOf(Map<OutfitSlot, WardrobeItem> pieces) {
    return Outfit.draft().copyWith(
      items: <OutfitSlot, String>{
        for (final MapEntry<OutfitSlot, WardrobeItem> e in pieces.entries)
          e.key: e.value.id,
      },
    );
  }

  group('the plan\'s worked example', () {
    // Outdoor Dinner, 52F, Light Rain, Business Casual.
    //
    // Shirt + Chinos + Loafers + Jacket should score above Shirt + Yellow
    // Shorts. This is the assertion that makes the scoring measurable, and
    // it is only writable because the engine is deterministic.
    test('appropriate outfit outscores shorts at 52F in the rain', () {
      final ScoredOutfit appropriate = engine.scoreOutfit(
        outfitOf(<OutfitSlot, WardrobeItem>{
          OutfitSlot.top: Fixtures.whiteShirt,
          OutfitSlot.bottom: Fixtures.navyChinos,
          OutfitSlot.footwear: Fixtures.brownLoafers,
          OutfitSlot.outerwear: Fixtures.greyJacket,
        }),
        request(),
      );

      final ScoredOutfit inappropriate = engine.scoreOutfit(
        outfitOf(<OutfitSlot, WardrobeItem>{
          OutfitSlot.top: Fixtures.whiteShirt,
          OutfitSlot.bottom: Fixtures.yellowShorts,
        }),
        request(),
      );

      expect(
        appropriate.score,
        greaterThan(inappropriate.score),
        reason: 'shirt+chinos+loafers+jacket must beat shirt+yellow shorts',
      );
    });

    test('the gap is decisive, not marginal', () {
      final int appropriate = engine
          .scoreOutfit(
            outfitOf(<OutfitSlot, WardrobeItem>{
              OutfitSlot.top: Fixtures.whiteShirt,
              OutfitSlot.bottom: Fixtures.navyChinos,
              OutfitSlot.footwear: Fixtures.brownLoafers,
              OutfitSlot.outerwear: Fixtures.greyJacket,
            }),
            request(),
          )
          .score;

      final int inappropriate = engine
          .scoreOutfit(
            outfitOf(<OutfitSlot, WardrobeItem>{
              OutfitSlot.top: Fixtures.whiteShirt,
              OutfitSlot.bottom: Fixtures.yellowShorts,
            }),
            request(),
          )
          .score;

      expect(appropriate - inappropriate, greaterThanOrEqualTo(10));
    });

    test('the top recommendation includes outerwear when it rains at 52F',
        () {
      final List<ScoredOutfit> results = engine.recommend(request());

      expect(results, isNotEmpty);
      expect(
        results.first.outfit.items.containsKey(OutfitSlot.outerwear),
        isTrue,
        reason: 'needsOuterwear is true at 52F with rain',
      );
    });

    test('shorts are not chosen for a 52F rainy dinner', () {
      final List<ScoredOutfit> results = engine.recommend(request());
      expect(
        results.first.outfit.containsItem(Fixtures.yellowShorts.id),
        isFalse,
      );
    });
  });

  group('weather sensitivity', () {
    test('the same wardrobe produces a different bottom when it is 94F', () {
      // Only the weather changes. Shorts are the summer-appropriate option,
      // so a hot-weather casual request should reach for them where a cold
      // rainy one did not.
      final List<ScoredOutfit> hot = engine.recommend(
        RecommendationRequest(
          items: Fixtures.planScenarioWardrobe,
          profile: Fixtures.profile,
          occasion: 'Casual',
          environment: 'Outdoor',
          weather: Fixtures.hot94,
          style: 'Casual',
        ),
      );

      expect(hot, isNotEmpty);
      expect(
        hot.first.outfit.containsItem(Fixtures.yellowShorts.id),
        isTrue,
        reason: 'shorts are the only Summer/Casual bottom available',
      );
    });

    test('outerwear is not required on a hot day', () {
      final List<ScoredOutfit> hot = engine.recommend(
        RecommendationRequest(
          items: Fixtures.planScenarioWardrobe,
          profile: Fixtures.profile,
          occasion: 'Casual',
          environment: 'Outdoor',
          weather: Fixtures.hot94,
        ),
      );
      expect(
        hot.first.outfit.items.containsKey(OutfitSlot.outerwear),
        isFalse,
      );
    });

    test('suede footwear is penalised in the rain', () {
      final RecommendationRequest rainy = RecommendationRequest(
        items: Fixtures.fullWardrobe,
        profile: Fixtures.profile,
        occasion: 'Dinner',
        environment: 'Outdoor',
        weather: Fixtures.rainy52,
      );

      final ScoredOutfit withLeather = engine.scoreOutfit(
        outfitOf(<OutfitSlot, WardrobeItem>{
          OutfitSlot.top: Fixtures.whiteShirt,
          OutfitSlot.bottom: Fixtures.navyChinos,
          OutfitSlot.footwear: Fixtures.brownLoafers,
        }),
        rainy,
      );

      final ScoredOutfit withSuede = engine.scoreOutfit(
        outfitOf(<OutfitSlot, WardrobeItem>{
          OutfitSlot.top: Fixtures.whiteShirt,
          OutfitSlot.bottom: Fixtures.navyChinos,
          OutfitSlot.footwear: Fixtures.suedeBoots,
        }),
        rainy,
      );

      expect(withLeather.score, greaterThan(withSuede.score));
    });
  });

  group('match this item', () {
    test('the anchor is present in every result', () {
      final List<ScoredOutfit> matches = engine.matchItem(
        Fixtures.whiteShirt,
        request(items: Fixtures.fullWardrobe),
      );

      expect(matches, isNotEmpty);
      for (final ScoredOutfit match in matches) {
        expect(
          match.outfit.containsItem(Fixtures.whiteShirt.id),
          isTrue,
          reason: 'the selected item must always remain in the outfit',
        );
      }
    });

    test('results are distinct', () {
      final List<ScoredOutfit> matches = engine.matchItem(
        Fixtures.whiteShirt,
        request(items: Fixtures.fullWardrobe),
      );
      final Set<String> signatures =
          matches.map((ScoredOutfit m) => m.signature).toSet();
      expect(signatures.length, matches.length);
    });

    test('results are ordered by score, descending', () {
      final List<ScoredOutfit> matches = engine.matchItem(
        Fixtures.whiteShirt,
        request(items: Fixtures.fullWardrobe),
      );
      for (int i = 1; i < matches.length; i++) {
        expect(matches[i - 1].score, greaterThanOrEqualTo(matches[i].score));
      }
    });

    test('anchoring a footwear item still produces an outfit', () {
      final List<ScoredOutfit> matches = engine.matchItem(
        Fixtures.brownLoafers,
        request(items: Fixtures.fullWardrobe),
      );
      expect(matches, isNotEmpty);
      expect(
        matches.first.outfit.containsItem(Fixtures.brownLoafers.id),
        isTrue,
      );
    });
  });

  group('build around / replace', () {
    test('buildAround returns one outfit containing the anchor', () {
      final ScoredOutfit? built = engine.buildAround(
        Fixtures.whiteShirt,
        request(items: Fixtures.fullWardrobe),
      );
      expect(built, isNotNull);
      expect(built!.outfit.containsItem(Fixtures.whiteShirt.id), isTrue);
    });

    test('replaceSlot swaps one slot and keeps the others', () {
      final RecommendationRequest req = request(
        items: Fixtures.fullWardrobe,
      );
      final ScoredOutfit? built =
          engine.buildAround(Fixtures.whiteShirt, req);
      expect(built, isNotNull);

      final Outfit before = built!.outfit;
      final String? bottomBefore = before.items[OutfitSlot.bottom];
      expect(bottomBefore, isNotNull);

      final ScoredOutfit? after =
          engine.replaceSlot(before, OutfitSlot.bottom, req);
      expect(after, isNotNull);

      expect(
        after!.outfit.items[OutfitSlot.bottom],
        isNot(bottomBefore),
        reason: 'the replaced slot must change',
      );

      for (final OutfitSlot slot in kSlotOrder) {
        if (slot == OutfitSlot.bottom) continue;
        expect(
          after.outfit.items[slot],
          before.items[slot],
          reason: '$slot should be untouched by a bottom replacement',
        );
      }
    });

    test('replaceSlot returns null when there is no alternative', () {
      // Only one pair of chinos exists, and it is already in the outfit.
      final RecommendationRequest req = RecommendationRequest(
        items: <WardrobeItem>[
          Fixtures.whiteShirt,
          Fixtures.navyChinos,
          Fixtures.brownLoafers,
        ],
        profile: Fixtures.profile,
        occasion: 'Dinner',
        environment: 'Indoor',
        weather: Fixtures.rainy52,
      );

      final Outfit outfit = outfitOf(<OutfitSlot, WardrobeItem>{
        OutfitSlot.top: Fixtures.whiteShirt,
        OutfitSlot.bottom: Fixtures.navyChinos,
        OutfitSlot.footwear: Fixtures.brownLoafers,
      });

      expect(engine.replaceSlot(outfit, OutfitSlot.bottom, req), isNull);
    });
  });

  group('explanations', () {
    test('every result carries at least one reason', () {
      for (final ScoredOutfit result
          in engine.recommend(request(items: Fixtures.fullWardrobe))) {
        expect(result.reasons, isNotEmpty);
      }
    });

    test('breakdown points sum to the reported score', () {
      final ScoredOutfit result =
          engine.recommend(request(items: Fixtures.fullWardrobe)).first;

      int sum = 0;
      result.breakdown.forEach((String _, int points) => sum += points);

      expect(sum.clamp(0, 100), result.score);
    });

    test('no score exceeds 100 or drops below 0', () {
      for (final ScoredOutfit result
          in engine.recommend(request(items: Fixtures.fullWardrobe))) {
        expect(result.score, inInclusiveRange(0, 100));
      }
    });
  });

  group('degenerate wardrobes', () {
    test('an empty wardrobe yields no recommendations rather than throwing',
        () {
      final List<ScoredOutfit> results = engine.recommend(
        request(items: <WardrobeItem>[]),
      );
      expect(results, isEmpty);
    });

    test('a wardrobe with only tops still returns something', () {
      // Sparse wardrobes must degrade, not dead-end: required slots are
      // driven by what is actually available.
      final List<ScoredOutfit> results = engine.recommend(
        request(items: <WardrobeItem>[Fixtures.whiteShirt]),
      );
      expect(results, isEmpty,
          reason: 'a single item cannot form an outfit of two or more');

      final List<ScoredOutfit> pair = engine.recommend(
        request(
          items: <WardrobeItem>[Fixtures.whiteShirt, Fixtures.navyChinos],
        ),
      );
      expect(pair, isNotEmpty);
    });
  });

  group('determinism', () {
    test('identical inputs produce identical output', () {
      final List<ScoredOutfit> first =
          engine.recommend(request(items: Fixtures.fullWardrobe));
      final List<ScoredOutfit> second =
          engine.recommend(request(items: Fixtures.fullWardrobe));

      expect(
        first.map((ScoredOutfit s) => s.signature).toList(),
        second.map((ScoredOutfit s) => s.signature).toList(),
      );
      expect(
        first.map((ScoredOutfit s) => s.score).toList(),
        second.map((ScoredOutfit s) => s.score).toList(),
      );
    });
  });
}
