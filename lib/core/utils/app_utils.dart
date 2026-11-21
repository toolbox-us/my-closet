import 'dart:math';

import 'package:flutter/material.dart';

/// Small helpers shared across features. Kept dependency-free on purpose:
/// no `intl`, so there is one less package to resolve.
class Ids {
  Ids._();

  static final Random _random = Random();

  /// Good enough for a local-only prototype: time-ordered and collision-safe
  /// in practice without pulling in a uuid package.
  static String generate([String prefix = 'id']) {
    final int now = DateTime.now().microsecondsSinceEpoch;
    final int salt = _random.nextInt(0xFFFF);
    return '${prefix}_${now.toRadixString(36)}${salt.toRadixString(36)}';
  }
}

class Dates {
  Dates._();

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> weekdayShort = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static const List<String> weekdayLong = <String>[
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];

  /// Stable map key for a calendar day: `2026-11-21`.
  static String key(DateTime date) {
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  static String medium(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}, ${date.year}';

  static String short(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}';

  /// "today" / "3 days ago" / "Mar 2" - for last-worn labels.
  static String relative(DateTime? date) {
    if (date == null) return 'Never worn';
    final DateTime now = DateTime.now();
    final int days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    if (days < 30) {
      final int weeks = days ~/ 7;
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    }
    return short(date);
  }

  /// Monday of the week containing [date].
  static DateTime startOfWeek(DateTime date) {
    final DateTime d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }
}

/// Maps the app's colour vocabulary to actual swatches, used for item tiles
/// and colour chips. Items without a photo render as a swatch plus a category
/// icon rather than a grey placeholder, so a seeded wardrobe still reads as a
/// wardrobe.
class ColorSwatches {
  ColorSwatches._();

  static const Map<String, Color> _map = <String, Color>{
    'Black': Color(0xFF1C1B1F),
    'White': Color(0xFFF7F7F5),
    'Grey': Color(0xFF8E9196),
    'Navy': Color(0xFF1F2A44),
    'Blue': Color(0xFF3E6DA8),
    'Green': Color(0xFF4E7B5C),
    'Olive': Color(0xFF6B7050),
    'Beige': Color(0xFFD9C9AE),
    'Cream': Color(0xFFEFE6D4),
    'Tan': Color(0xFFC19A6B),
    'Khaki': Color(0xFFBFB08A),
    'Brown': Color(0xFF6F4E37),
    'Red': Color(0xFFB23A34),
    'Maroon': Color(0xFF6E2B36),
    'Pink': Color(0xFFD79BA6),
    'Yellow': Color(0xFFD9B23A),
    'Orange': Color(0xFFC4703A),
    'Purple': Color(0xFF6B4E71),
  };

  static Color of(String? name) => _map[name] ?? const Color(0xFF9E9E9E);

  /// Readable foreground for a given swatch.
  static Color onOf(String? name) {
    final Color c = of(name);
    return c.computeLuminance() > 0.5
        ? const Color(0xFF1C1B1F)
        : const Color(0xFFFFFFFF);
  }

  static IconData iconFor(String category) {
    switch (category) {
      case 'Tops':
        return Icons.dry_cleaning_outlined;
      case 'Bottoms':
        return Icons.airline_seat_legroom_normal_outlined;
      case 'Dresses':
        return Icons.woman_outlined;
      case 'Outerwear':
        return Icons.ac_unit_outlined;
      case 'Footwear':
        return Icons.ice_skating_outlined;
      case 'Accessories':
        return Icons.watch_outlined;
      default:
        return Icons.category_outlined;
    }
  }
}
