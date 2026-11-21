import 'json_utils.dart';

/// Where an item's attributes came from.
///
/// Stored per item so the UI can show a provenance marker. This is the
/// concrete transparency mechanism behind the paper's ethics section: a user
/// can always tell which attributes a model proposed and which they set
/// themselves.
enum AttributeSource { manual, aiAccepted, aiEdited }

extension AttributeSourceX on AttributeSource {
  String get label {
    switch (this) {
      case AttributeSource.manual:
        return 'Entered by you';
      case AttributeSource.aiAccepted:
        return 'AI-suggested, accepted';
      case AttributeSource.aiEdited:
        return 'AI-suggested, edited by you';
    }
  }

  bool get involvedAi => this != AttributeSource.manual;
}

class WardrobeItem {
  const WardrobeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.primaryColor,
    this.subcategory,
    this.brand,
    this.secondaryColor,
    this.pattern,
    this.material,
    this.size,
    this.fit,
    this.occasions = const <String>[],
    this.seasons = const <String>[],
    this.styles = const <String>[],
    this.indoor = true,
    this.outdoor = true,
    this.tags = const <String>[],
    this.notes,
    this.purchasePrice,
    this.favorite = false,
    this.imagePath,
    this.timesWorn = 0,
    this.lastWorn,
    this.attributeSource = AttributeSource.manual,
  });

  final String id;

  // Required trio - everything else is optional, per the plan.
  final String name;
  final String category;
  final String primaryColor;

  final String? subcategory;
  final String? brand;
  final String? secondaryColor;
  final String? pattern;
  final String? material;
  final String? size;
  final String? fit;

  final List<String> occasions;
  final List<String> seasons;

  /// Style labels drawn from `Vocab.styles`. Scored against the user's
  /// preferred styles and the style requested for a recommendation.
  final List<String> styles;

  final bool indoor;
  final bool outdoor;

  final List<String> tags;
  final String? notes;
  final double? purchasePrice;
  final bool favorite;

  /// Absolute path to a copy of the photo inside the app documents
  /// directory. Null means "render a colour swatch".
  ///
  /// Never store the raw `image_picker` cache path here: the OS clears that
  /// directory and the photo silently disappears after a restart.
  final String? imagePath;

  final int timesWorn;
  final DateTime? lastWorn;
  final AttributeSource attributeSource;

  /// Everything searchable about the item, lowercased, for the wardrobe
  /// search box.
  String get searchHaystack => <String?>[
        name,
        category,
        subcategory,
        brand,
        primaryColor,
        secondaryColor,
        pattern,
        material,
        notes,
        ...tags,
        ...occasions,
        ...styles,
      ].whereType<String>().join(' ').toLowerCase();

  List<String> get allColors => <String>[
        primaryColor,
        if (secondaryColor != null && secondaryColor!.isNotEmpty)
          secondaryColor!,
      ];

  factory WardrobeItem.fromJson(Map<String, dynamic> json) => WardrobeItem(
        id: J.str(json['id']),
        name: J.str(json['name'], 'Untitled'),
        category: J.str(json['category'], 'Tops'),
        primaryColor: J.str(json['primaryColor'], 'Black'),
        subcategory: J.strOrNull(json['subcategory']),
        brand: J.strOrNull(json['brand']),
        secondaryColor: J.strOrNull(json['secondaryColor']),
        pattern: J.strOrNull(json['pattern']),
        material: J.strOrNull(json['material']),
        size: J.strOrNull(json['size']),
        fit: J.strOrNull(json['fit']),
        occasions: J.strList(json['occasions']),
        seasons: J.strList(json['seasons']),
        styles: J.strList(json['styles']),
        indoor: J.boolean(json['indoor'], true),
        outdoor: J.boolean(json['outdoor'], true),
        tags: J.strList(json['tags']),
        notes: J.strOrNull(json['notes']),
        purchasePrice: J.doubleOrNull(json['purchasePrice']),
        favorite: J.boolean(json['favorite']),
        imagePath: J.strOrNull(json['imagePath']),
        timesWorn: J.integer(json['timesWorn']),
        lastWorn: J.date(json['lastWorn']),
        attributeSource: AttributeSource.values.firstWhere(
          (AttributeSource s) => s.name == J.str(json['attributeSource']),
          orElse: () => AttributeSource.manual,
        ),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'category': category,
        'primaryColor': primaryColor,
        'subcategory': subcategory,
        'brand': brand,
        'secondaryColor': secondaryColor,
        'pattern': pattern,
        'material': material,
        'size': size,
        'fit': fit,
        'occasions': occasions,
        'seasons': seasons,
        'styles': styles,
        'indoor': indoor,
        'outdoor': outdoor,
        'tags': tags,
        'notes': notes,
        'purchasePrice': purchasePrice,
        'favorite': favorite,
        'imagePath': imagePath,
        'timesWorn': timesWorn,
        'lastWorn': J.dateToJson(lastWorn),
        'attributeSource': attributeSource.name,
      };

  /// Note: cannot set a nullable field back to null. Edit flows rebuild the
  /// item from form state instead, which is clearer than a sentinel object.
  WardrobeItem copyWith({
    String? name,
    String? category,
    String? primaryColor,
    String? subcategory,
    String? brand,
    String? secondaryColor,
    String? pattern,
    String? material,
    String? size,
    String? fit,
    List<String>? occasions,
    List<String>? seasons,
    List<String>? styles,
    bool? indoor,
    bool? outdoor,
    List<String>? tags,
    String? notes,
    double? purchasePrice,
    bool? favorite,
    String? imagePath,
    int? timesWorn,
    DateTime? lastWorn,
    AttributeSource? attributeSource,
  }) =>
      WardrobeItem(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        primaryColor: primaryColor ?? this.primaryColor,
        subcategory: subcategory ?? this.subcategory,
        brand: brand ?? this.brand,
        secondaryColor: secondaryColor ?? this.secondaryColor,
        pattern: pattern ?? this.pattern,
        material: material ?? this.material,
        size: size ?? this.size,
        fit: fit ?? this.fit,
        occasions: occasions ?? this.occasions,
        seasons: seasons ?? this.seasons,
        styles: styles ?? this.styles,
        indoor: indoor ?? this.indoor,
        outdoor: outdoor ?? this.outdoor,
        tags: tags ?? this.tags,
        notes: notes ?? this.notes,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        favorite: favorite ?? this.favorite,
        imagePath: imagePath ?? this.imagePath,
        timesWorn: timesWorn ?? this.timesWorn,
        lastWorn: lastWorn ?? this.lastWorn,
        attributeSource: attributeSource ?? this.attributeSource,
      );

  @override
  String toString() => 'WardrobeItem($id, $name, $category, $primaryColor)';
}
