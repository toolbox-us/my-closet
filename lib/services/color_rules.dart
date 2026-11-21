/// Colour matching rules.
///
/// These do not represent perfect fashion science and are not meant to. Their
/// purpose is to demonstrate the recommendation architecture with rules that
/// are legible, testable and arguable - which is more than an opaque model
/// score would give. The limitation is stated in the plan rather than papered
/// over.
///
/// The core table is the one from the plan; the remaining vocabulary colours
/// are filled in consistently. Lookups are symmetric: A-matches-B is tested
/// in both directions, so the table does not need to be exhaustive.
class ColorRules {
  ColorRules._();

  /// Colours that go with nearly anything and do not count toward the
  /// "too many colours" penalty.
  static const Set<String> neutrals = <String>{
    'White',
    'Black',
    'Grey',
    'Beige',
    'Cream',
    'Tan',
    'Navy',
    'Khaki',
    'Brown',
  };

  static const Map<String, List<String>> compatibility =
      <String, List<String>>{
    'White': <String>[
      'Black', 'Grey', 'Navy', 'Blue', 'Green', 'Olive', 'Beige', 'Cream',
      'Tan', 'Khaki', 'Brown', 'Red', 'Maroon', 'Pink', 'Yellow', 'Orange',
      'Purple',
    ],
    'Black': <String>[
      'White', 'Grey', 'Blue', 'Beige', 'Red', 'Cream', 'Pink', 'Olive',
      'Maroon',
    ],
    'Navy': <String>[
      'White', 'Grey', 'Beige', 'Brown', 'Cream', 'Tan', 'Khaki', 'Pink',
      'Maroon',
    ],
    'Blue': <String>[
      'White', 'Grey', 'Khaki', 'Navy', 'Beige', 'Brown', 'Tan', 'Black',
    ],
    'Green': <String>[
      'Beige', 'White', 'Brown', 'Black', 'Cream', 'Tan', 'Khaki', 'Grey',
    ],
    'Olive': <String>[
      'Beige', 'White', 'Brown', 'Cream', 'Tan', 'Black', 'Khaki',
    ],
    'Brown': <String>[
      'Beige', 'White', 'Blue', 'Green', 'Cream', 'Olive', 'Navy', 'Khaki',
      'Tan',
    ],
    'Grey': <String>[
      'Black', 'White', 'Blue', 'Navy', 'Maroon', 'Pink', 'Green', 'Yellow',
    ],
    'Beige': <String>[
      'White', 'Navy', 'Brown', 'Green', 'Olive', 'Blue', 'Black', 'Maroon',
    ],
    'Cream': <String>[
      'Navy', 'Brown', 'Olive', 'Green', 'Black', 'Maroon', 'Tan',
    ],
    'Tan': <String>[
      'White', 'Navy', 'Brown', 'Green', 'Olive', 'Blue', 'Cream',
    ],
    'Khaki': <String>[
      'White', 'Navy', 'Blue', 'Green', 'Olive', 'Brown', 'Black',
    ],
    'Red': <String>['White', 'Black', 'Grey', 'Navy', 'Cream', 'Beige'],
    'Maroon': <String>['White', 'Grey', 'Navy', 'Cream', 'Beige', 'Black'],
    'Pink': <String>['White', 'Grey', 'Navy', 'Black', 'Cream', 'Beige'],
    'Yellow': <String>['White', 'Grey', 'Navy', 'Blue', 'Brown'],
    'Orange': <String>['White', 'Navy', 'Brown', 'Cream', 'Beige'],
    'Purple': <String>['White', 'Grey', 'Black', 'Cream'],
  };

  static bool isNeutral(String color) => neutrals.contains(color);

  /// Symmetric compatibility test.
  static bool compatible(String a, String b) {
    if (a == b) return true;
    final List<String>? forward = compatibility[a];
    if (forward != null && forward.contains(b)) return true;
    final List<String>? backward = compatibility[b];
    if (backward != null && backward.contains(a)) return true;
    return false;
  }

  /// 0..1 for a single pair.
  static double pairScore(String a, String b) {
    if (a == b) {
      // Monochrome reads as deliberate but is not the maximum.
      return 0.85;
    }
    if (isNeutral(a) && isNeutral(b)) return 1.0;
    if (compatible(a, b)) return 1.0;
    if (isNeutral(a) || isNeutral(b)) return 0.8;
    return 0.3;
  }

  /// 0..1 for a whole outfit's colours.
  ///
  /// Mean pairwise compatibility, with a penalty once three or more
  /// non-neutral colours appear - individually fine pairs can still add up to
  /// something nobody would wear.
  static double outfitScore(List<String> colors) {
    final List<String> present =
        colors.where((String c) => c.trim().isNotEmpty).toList();
    if (present.length < 2) return 1.0;

    double sum = 0;
    int pairs = 0;
    for (int i = 0; i < present.length; i++) {
      for (int j = i + 1; j < present.length; j++) {
        sum += pairScore(present[i], present[j]);
        pairs++;
      }
    }
    double score = pairs == 0 ? 1.0 : sum / pairs;

    final Set<String> loudColors =
        present.where((String c) => !isNeutral(c)).toSet();
    if (loudColors.length >= 4) {
      score *= 0.7;
    } else if (loudColors.length == 3) {
      score *= 0.85;
    }

    return score.clamp(0.0, 1.0);
  }

  /// True when every pair in the outfit is compatible. Used for the
  /// "Colors complement each other" reason line.
  static bool allCompatible(List<String> colors) {
    for (int i = 0; i < colors.length; i++) {
      for (int j = i + 1; j < colors.length; j++) {
        if (!compatible(colors[i], colors[j])) return false;
      }
    }
    return true;
  }
}
