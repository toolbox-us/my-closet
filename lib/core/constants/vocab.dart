/// The app's controlled vocabulary.
///
/// Every attribute the user can filter, sort or score on must come from these
/// lists. This matters most for the AI integration: an unconstrained model
/// happily returns "sage" and "ecru" while the filter chips only know "green"
/// and "beige", and the suggestion then fails silently. [Vocab.match] maps a
/// free-text value onto the vocabulary and returns null when it cannot.
class Vocab {
  Vocab._();

  static const List<String> categories = <String>[
    'Tops',
    'Bottoms',
    'Dresses',
    'Outerwear',
    'Footwear',
    'Accessories',
  ];

  static const List<String> colors = <String>[
    'Black',
    'White',
    'Grey',
    'Navy',
    'Blue',
    'Green',
    'Olive',
    'Beige',
    'Cream',
    'Tan',
    'Khaki',
    'Brown',
    'Red',
    'Maroon',
    'Pink',
    'Yellow',
    'Orange',
    'Purple',
  ];

  static const List<String> patterns = <String>[
    'Solid',
    'Striped',
    'Checked',
    'Plaid',
    'Floral',
    'Printed',
    'Textured',
  ];

  static const List<String> materials = <String>[
    'Cotton',
    'Linen',
    'Wool',
    'Denim',
    'Leather',
    'Suede',
    'Polyester',
    'Nylon',
    'Silk',
    'Knit',
    'Fleece',
    'Down',
  ];

  static const List<String> occasions = <String>[
    'Work',
    'Casual',
    'Interview',
    'Wedding',
    'Date',
    'Party',
    'Gym',
    'Travel',
    'Dinner',
    'Hiking',
  ];

  static const List<String> seasons = <String>[
    'Spring',
    'Summer',
    'Fall',
    'Winter',
  ];

  static const List<String> styles = <String>[
    'Casual',
    'Business Casual',
    'Smart Casual',
    'Formal',
    'Athletic',
    'Streetwear',
    'Minimalist',
    'Outdoor',
    'Party',
  ];

  static const List<String> fits = <String>[
    'Slim',
    'Regular',
    'Relaxed',
    'Oversized',
  ];

  static const List<String> environments = <String>[
    'Indoor',
    'Outdoor',
    'Mixed',
  ];

  static const List<String> hobbies = <String>[
    'Office',
    'Gym',
    'Running',
    'Hiking',
    'Travel',
    'Parties',
    'Business Events',
    'Outdoor Activities',
  ];

  static const List<String> sizeKinds = <String>[
    'Shirt',
    'T-Shirt',
    'Pants',
    'Jacket',
    'Shoes',
  ];

  static const List<String> weatherConditions = <String>[
    'Sunny',
    'Cloudy',
    'Light Rain',
    'Heavy Rain',
    'Snow',
    'Windy',
  ];

  static const List<String> windLevels = <String>[
    'Low Wind',
    'Moderate Wind',
    'High Wind',
  ];

  /// Common model-speak mapped onto the app's own colour names.
  ///
  /// Not exhaustive and not meant to be - anything unmapped is dropped rather
  /// than guessed at, which is the safer failure for a suggestion the user is
  /// about to accept.
  static const Map<String, String> _colorSynonyms = <String, String>{
    'sage': 'Green',
    'mint': 'Green',
    'emerald': 'Green',
    'forest': 'Green',
    'teal': 'Green',
    'ecru': 'Beige',
    'oatmeal': 'Beige',
    'sand': 'Beige',
    'camel': 'Tan',
    'taupe': 'Tan',
    'ivory': 'Cream',
    'off-white': 'Cream',
    'offwhite': 'Cream',
    'charcoal': 'Grey',
    'gray': 'Grey',
    'slate': 'Grey',
    'silver': 'Grey',
    'indigo': 'Navy',
    'denim': 'Blue',
    'sky': 'Blue',
    'cobalt': 'Blue',
    'burgundy': 'Maroon',
    'wine': 'Maroon',
    'rust': 'Orange',
    'terracotta': 'Orange',
    'mustard': 'Yellow',
    'gold': 'Yellow',
    'blush': 'Pink',
    'rose': 'Pink',
    'lavender': 'Purple',
    'violet': 'Purple',
    'chocolate': 'Brown',
    'coffee': 'Brown',
  };

  static const Map<String, String> _categorySynonyms = <String, String>{
    'top': 'Tops',
    'shirt': 'Tops',
    'tshirt': 'Tops',
    't-shirt': 'Tops',
    'blouse': 'Tops',
    'sweater': 'Tops',
    'polo': 'Tops',
    'bottom': 'Bottoms',
    'pants': 'Bottoms',
    'trousers': 'Bottoms',
    'jeans': 'Bottoms',
    'shorts': 'Bottoms',
    'skirt': 'Bottoms',
    'chinos': 'Bottoms',
    'dress': 'Dresses',
    'gown': 'Dresses',
    'jacket': 'Outerwear',
    'coat': 'Outerwear',
    'blazer': 'Outerwear',
    'outerwear': 'Outerwear',
    'shoes': 'Footwear',
    'shoe': 'Footwear',
    'sneakers': 'Footwear',
    'boots': 'Footwear',
    'loafers': 'Footwear',
    'footwear': 'Footwear',
    'accessory': 'Accessories',
    'accessories': 'Accessories',
    'watch': 'Accessories',
    'belt': 'Accessories',
    'bag': 'Accessories',
    'sunglasses': 'Accessories',
    'hat': 'Accessories',
    'scarf': 'Accessories',
  };

  /// Maps [raw] onto [allowed], case- and whitespace-insensitively, applying
  /// the synonym tables. Returns null when there is no confident match.
  static String? match(Object? raw, List<String> allowed) {
    if (raw == null) return null;
    final String value = raw.toString().trim();
    if (value.isEmpty) return null;
    final String key = value.toLowerCase();

    for (final String option in allowed) {
      if (option.toLowerCase() == key) return option;
    }

    // Try both synonym tables and accept only a result that is actually a
    // member of `allowed`. Checking membership rather than which list was
    // passed keeps this correct if the lists are ever copied or extended.
    final String? colorHit = _colorSynonyms[key];
    if (colorHit != null && allowed.contains(colorHit)) return colorHit;

    final String? categoryHit = _categorySynonyms[key];
    if (categoryHit != null && allowed.contains(categoryHit)) {
      return categoryHit;
    }

    // Last resort: a single unambiguous prefix match ("navy blue" -> "Navy").
    final List<String> prefixHits = allowed
        .where((String o) => key.startsWith(o.toLowerCase()))
        .toList();
    if (prefixHits.length == 1) return prefixHits.first;

    return null;
  }

  /// Maps each entry of [raw] onto [allowed], dropping anything unrecognised
  /// and de-duplicating what survives.
  static List<String> matchAll(Object? raw, List<String> allowed,
      {int limit = 8}) {
    if (raw is! List) return const <String>[];
    final List<String> out = <String>[];
    for (final Object? entry in raw) {
      final String? hit = match(entry, allowed);
      if (hit != null && !out.contains(hit)) out.add(hit);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Tags the AI is allowed to suggest: styles and occasions, lowercased and
  /// hyphenated, which is how tags are stored on items.
  static List<String> get suggestableTags {
    final Set<String> all = <String>{};
    for (final String s in styles) {
      all.add(s.toLowerCase().replaceAll(' ', '-'));
    }
    for (final String o in occasions) {
      all.add(o.toLowerCase().replaceAll(' ', '-'));
    }
    return all.toList()..sort();
  }
}
