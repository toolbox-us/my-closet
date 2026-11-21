import 'package:flutter_test/flutter_test.dart';
import 'package:my_closet/services/color_rules.dart';

void main() {
  group('compatibility is symmetric', () {
    test('a pair listed one way matches both ways', () {
      // 'Brown' is in Navy's list; 'Navy' is in Brown's. The lookup must not
      // depend on which argument comes first either way.
      expect(ColorRules.compatible('Navy', 'Brown'), isTrue);
      expect(ColorRules.compatible('Brown', 'Navy'), isTrue);
    });

    test('a pair listed only one way still matches both ways', () {
      // 'Khaki' appears in Blue's list.
      expect(ColorRules.compatible('Blue', 'Khaki'), isTrue);
      expect(ColorRules.compatible('Khaki', 'Blue'), isTrue);
    });

    test('an identical colour is compatible with itself', () {
      expect(ColorRules.compatible('Green', 'Green'), isTrue);
    });
  });

  group('the rules from the plan hold', () {
    test('white goes with almost anything', () {
      for (final String color in <String>[
        'Black',
        'Grey',
        'Navy',
        'Blue',
        'Green',
        'Beige',
        'Brown',
        'Red',
        'Pink',
        'Yellow',
        'Purple',
      ]) {
        expect(
          ColorRules.compatible('White', color),
          isTrue,
          reason: 'White should pair with $color',
        );
      }
    });

    test('black pairs with white, grey, blue, beige and red', () {
      for (final String color in <String>[
        'White',
        'Grey',
        'Blue',
        'Beige',
        'Red',
      ]) {
        expect(ColorRules.compatible('Black', color), isTrue);
      }
    });

    test('navy pairs with white, grey, beige and brown', () {
      for (final String color in <String>[
        'White',
        'Grey',
        'Beige',
        'Brown',
      ]) {
        expect(ColorRules.compatible('Navy', color), isTrue);
      }
    });

    test('green pairs with beige, white, brown and black', () {
      for (final String color in <String>[
        'Beige',
        'White',
        'Brown',
        'Black',
      ]) {
        expect(ColorRules.compatible('Green', color), isTrue);
      }
    });
  });

  group('clashes score lower than matches', () {
    test('two unrelated loud colours score poorly', () {
      expect(ColorRules.pairScore('Red', 'Green'), lessThan(0.5));
      expect(ColorRules.pairScore('Purple', 'Orange'), lessThan(0.5));
    });

    test('a listed pair scores at the top', () {
      expect(ColorRules.pairScore('Navy', 'White'), 1.0);
    });

    test('two neutrals always score at the top', () {
      expect(ColorRules.pairScore('Grey', 'Beige'), 1.0);
      expect(ColorRules.pairScore('Black', 'Tan'), 1.0);
    });

    test('monochrome is good but not maximal', () {
      final double same = ColorRules.pairScore('Green', 'Green');
      expect(same, lessThan(1.0));
      expect(same, greaterThan(0.7));
    });

    test('a loud colour beside a neutral still scores decently', () {
      expect(ColorRules.pairScore('Purple', 'Grey'), greaterThanOrEqualTo(0.8));
    });
  });

  group('whole-outfit scoring', () {
    test('a single colour is unproblematic', () {
      expect(ColorRules.outfitScore(<String>['Navy']), 1.0);
      expect(ColorRules.outfitScore(<String>[]), 1.0);
    });

    test('an all-neutral outfit scores perfectly', () {
      expect(
        ColorRules.outfitScore(<String>['White', 'Navy', 'Brown', 'Grey']),
        1.0,
      );
    });

    test('three or more loud colours are penalised', () {
      // Each pair may be individually acceptable and the combination still
      // be something nobody would wear.
      final double two =
          ColorRules.outfitScore(<String>['White', 'Red', 'Navy']);
      final double four = ColorRules.outfitScore(
        <String>['Red', 'Green', 'Purple', 'Orange'],
      );
      expect(four, lessThan(two));
      expect(four, lessThan(0.5));
    });

    test('a clash drags the outfit score below a clean one', () {
      final double clean =
          ColorRules.outfitScore(<String>['White', 'Navy', 'Brown']);
      final double clashing =
          ColorRules.outfitScore(<String>['Red', 'Green', 'Purple']);
      expect(clean, greaterThan(clashing));
    });

    test('scores stay inside 0..1', () {
      final List<List<String>> cases = <List<String>>[
        <String>['White'],
        <String>['Red', 'Green'],
        <String>['Red', 'Green', 'Purple', 'Orange', 'Yellow', 'Pink'],
        <String>['Black', 'Black', 'Black'],
      ];
      for (final List<String> colors in cases) {
        final double score = ColorRules.outfitScore(colors);
        expect(score, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('allCompatible gates the explanation line', () {
    test('true for a clean set', () {
      expect(
        ColorRules.allCompatible(<String>['White', 'Navy', 'Brown']),
        isTrue,
      );
    });

    test('false when any single pair clashes', () {
      expect(
        ColorRules.allCompatible(<String>['White', 'Red', 'Green']),
        isFalse,
      );
    });
  });

  group('neutrals', () {
    test('the expected set is treated as neutral', () {
      for (final String color in <String>[
        'White',
        'Black',
        'Grey',
        'Beige',
        'Cream',
        'Tan',
        'Navy',
        'Khaki',
        'Brown',
      ]) {
        expect(ColorRules.isNeutral(color), isTrue, reason: color);
      }
    });

    test('loud colours are not neutral', () {
      for (final String color in <String>[
        'Red',
        'Green',
        'Yellow',
        'Purple',
        'Orange',
        'Pink',
      ]) {
        expect(ColorRules.isNeutral(color), isFalse, reason: color);
      }
    });
  });
}
