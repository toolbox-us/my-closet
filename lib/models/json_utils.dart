/// Defensive JSON readers shared by every model.
///
/// Seed files are hand-written and persisted records may have been written by
/// an older build, so parsing never assumes a field is present or correctly
/// typed. A bad field degrades to a default rather than throwing and taking
/// the whole wardrobe down with it.
class J {
  J._();

  static String str(Object? value, [String fallback = '']) {
    if (value is String) return value;
    if (value == null) return fallback;
    return value.toString();
  }

  static String? strOrNull(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  static bool boolean(Object? value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return fallback;
  }

  static int integer(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double? doubleOrNull(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<String> strList(Object? value) {
    if (value is! List) return const <String>[];
    final List<String> out = <String>[];
    for (final Object? entry in value) {
      if (entry is String && entry.trim().isNotEmpty) out.add(entry);
    }
    return out;
  }

  static Map<String, String> strMap(Object? value) {
    if (value is! Map) return const <String, String>{};
    final Map<String, String> out = <String, String>{};
    value.forEach((Object? k, Object? v) {
      if (k is String && v != null) out[k] = v.toString();
    });
    return out;
  }

  static DateTime? date(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  static String? dateToJson(DateTime? value) => value?.toIso8601String();
}
