import 'json_utils.dart';

/// What the AI proposes for a clothing photo.
///
/// Every field is nullable: the model is allowed to say "I don't know", and
/// anything outside the app's controlled vocabulary is dropped during parsing
/// rather than written through as a junk value.
///
/// [isFallback] is surfaced in the UI. A demo on bad wifi shows an example
/// suggestion labelled as such rather than an error dialog.
class AiSuggestion {
  const AiSuggestion({
    this.category,
    this.subcategory,
    this.primaryColor,
    this.secondaryColor,
    this.pattern,
    this.material,
    this.suggestedTags = const <String>[],
    this.suggestedName,
    this.modelUsed = '',
    this.isFallback = false,
    this.errorMessage,
    this.rawResponse,
    this.elapsed,
  });

  final String? category;
  final String? subcategory;
  final String? primaryColor;
  final String? secondaryColor;
  final String? pattern;
  final String? material;
  final List<String> suggestedTags;
  final String? suggestedName;

  final String modelUsed;

  /// True when this is a canned mock result rather than model output.
  final bool isFallback;

  /// Why the real call failed, when it did. Shown in the debug sheet.
  final String? errorMessage;

  /// Raw response body, kept for the debug sheet. Invaluable when the API
  /// shape changes under you - which it does.
  final String? rawResponse;

  final Duration? elapsed;

  /// Did the model actually return anything usable?
  bool get hasContent =>
      category != null ||
      primaryColor != null ||
      pattern != null ||
      material != null ||
      subcategory != null ||
      suggestedTags.isNotEmpty;

  /// Fields the user would see filled in, for the "Accept all" summary.
  int get fieldCount {
    int n = 0;
    if (category != null) n++;
    if (subcategory != null) n++;
    if (primaryColor != null) n++;
    if (secondaryColor != null) n++;
    if (pattern != null) n++;
    if (material != null) n++;
    if (suggestedTags.isNotEmpty) n++;
    return n;
  }

  static const AiSuggestion none = AiSuggestion();

  factory AiSuggestion.fromJson(Map<String, dynamic> json) => AiSuggestion(
        category: J.strOrNull(json['category']),
        subcategory: J.strOrNull(json['subcategory']),
        primaryColor: J.strOrNull(json['primaryColor']),
        secondaryColor: J.strOrNull(json['secondaryColor']),
        pattern: J.strOrNull(json['pattern']),
        material: J.strOrNull(json['material']),
        suggestedTags: J.strList(json['suggestedTags']),
        suggestedName: J.strOrNull(json['suggestedName']),
        modelUsed: J.str(json['modelUsed']),
        isFallback: J.boolean(json['isFallback']),
        errorMessage: J.strOrNull(json['errorMessage']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'category': category,
        'subcategory': subcategory,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'pattern': pattern,
        'material': material,
        'suggestedTags': suggestedTags,
        'suggestedName': suggestedName,
        'modelUsed': modelUsed,
        'isFallback': isFallback,
        'errorMessage': errorMessage,
      };

  AiSuggestion copyWith({
    bool? isFallback,
    String? errorMessage,
    String? rawResponse,
    String? modelUsed,
    Duration? elapsed,
  }) =>
      AiSuggestion(
        category: category,
        subcategory: subcategory,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        pattern: pattern,
        material: material,
        suggestedTags: suggestedTags,
        suggestedName: suggestedName,
        modelUsed: modelUsed ?? this.modelUsed,
        isFallback: isFallback ?? this.isFallback,
        errorMessage: errorMessage ?? this.errorMessage,
        rawResponse: rawResponse ?? this.rawResponse,
        elapsed: elapsed ?? this.elapsed,
      );
}
