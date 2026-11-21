import 'json_utils.dart';

/// Outfit slots.
///
/// Modelling an outfit as slot -> itemId (rather than six named fields) is
/// what makes "Build Around This" and per-slot Replace generic: the engine
/// holds every other slot fixed and re-solves one key.
enum OutfitSlot { top, bottom, dress, outerwear, footwear, accessory }

/// Which wardrobe category can fill each slot.
const Map<OutfitSlot, String> kSlotCategory = <OutfitSlot, String>{
  OutfitSlot.top: 'Tops',
  OutfitSlot.bottom: 'Bottoms',
  OutfitSlot.dress: 'Dresses',
  OutfitSlot.outerwear: 'Outerwear',
  OutfitSlot.footwear: 'Footwear',
  OutfitSlot.accessory: 'Accessories',
};

const Map<OutfitSlot, String> kSlotLabel = <OutfitSlot, String>{
  OutfitSlot.top: 'Top',
  OutfitSlot.bottom: 'Bottom',
  OutfitSlot.dress: 'Dress',
  OutfitSlot.outerwear: 'Outerwear',
  OutfitSlot.footwear: 'Shoes',
  OutfitSlot.accessory: 'Accessory',
};

/// Display order.
const List<OutfitSlot> kSlotOrder = <OutfitSlot>[
  OutfitSlot.top,
  OutfitSlot.bottom,
  OutfitSlot.dress,
  OutfitSlot.outerwear,
  OutfitSlot.footwear,
  OutfitSlot.accessory,
];

OutfitSlot? slotForCategory(String category) {
  for (final MapEntry<OutfitSlot, String> entry in kSlotCategory.entries) {
    if (entry.value == category) return entry.key;
  }
  return null;
}

class Outfit {
  const Outfit({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    this.occasion,
    this.style,
    this.favorite = false,
    this.lastWorn,
    this.timesWorn = 0,
  });

  final String id;
  final String name;

  /// Only occupied slots are present.
  final Map<OutfitSlot, String> items;

  final String? occasion;
  final String? style;
  final bool favorite;
  final DateTime createdAt;
  final DateTime? lastWorn;
  final int timesWorn;

  List<String> get itemIds => items.values.toList();

  bool get isEmpty => items.isEmpty;

  /// Order-independent identity for an outfit's contents. Used to match
  /// feedback to future recommendations without storing whole outfits.
  String get signature {
    final List<String> ids = items.values.toList()..sort();
    return ids.join('|');
  }

  bool containsItem(String itemId) => items.containsValue(itemId);

  static Outfit draft({String name = 'New outfit'}) => Outfit(
        id: '',
        name: name,
        items: const <OutfitSlot, String>{},
        createdAt: DateTime.now(),
      );

  factory Outfit.fromJson(Map<String, dynamic> json) {
    final Map<OutfitSlot, String> parsed = <OutfitSlot, String>{};
    final Object? rawItems = json['items'];
    if (rawItems is Map) {
      rawItems.forEach((Object? key, Object? value) {
        if (key is! String || value == null) return;
        for (final OutfitSlot slot in OutfitSlot.values) {
          if (slot.name == key) {
            final String id = value.toString();
            if (id.isNotEmpty) parsed[slot] = id;
          }
        }
      });
    }

    return Outfit(
      id: J.str(json['id']),
      name: J.str(json['name'], 'Untitled outfit'),
      items: parsed,
      occasion: J.strOrNull(json['occasion']),
      style: J.strOrNull(json['style']),
      favorite: J.boolean(json['favorite']),
      createdAt: J.date(json['createdAt']) ?? DateTime.now(),
      lastWorn: J.date(json['lastWorn']),
      timesWorn: J.integer(json['timesWorn']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'items': <String, String>{
          for (final MapEntry<OutfitSlot, String> e in items.entries)
            e.key.name: e.value,
        },
        'occasion': occasion,
        'style': style,
        'favorite': favorite,
        'createdAt': J.dateToJson(createdAt),
        'lastWorn': J.dateToJson(lastWorn),
        'timesWorn': timesWorn,
      };

  Outfit copyWith({
    String? id,
    String? name,
    Map<OutfitSlot, String>? items,
    String? occasion,
    String? style,
    bool? favorite,
    DateTime? lastWorn,
    int? timesWorn,
  }) =>
      Outfit(
        id: id ?? this.id,
        name: name ?? this.name,
        items: items ?? this.items,
        occasion: occasion ?? this.occasion,
        style: style ?? this.style,
        favorite: favorite ?? this.favorite,
        createdAt: createdAt,
        lastWorn: lastWorn ?? this.lastWorn,
        timesWorn: timesWorn ?? this.timesWorn,
      );

  /// Returns a copy with [slot] set to [itemId].
  Outfit withSlot(OutfitSlot slot, String itemId) {
    final Map<OutfitSlot, String> next =
        Map<OutfitSlot, String>.from(items);
    next[slot] = itemId;
    // A dress and a top/bottom are mutually exclusive.
    if (slot == OutfitSlot.dress) {
      next.remove(OutfitSlot.top);
      next.remove(OutfitSlot.bottom);
    } else if (slot == OutfitSlot.top || slot == OutfitSlot.bottom) {
      next.remove(OutfitSlot.dress);
    }
    return copyWith(items: next);
  }

  /// Returns a copy with [slot] cleared.
  Outfit withoutSlot(OutfitSlot slot) {
    final Map<OutfitSlot, String> next =
        Map<OutfitSlot, String>.from(items);
    next.remove(slot);
    return copyWith(items: next);
  }
}
