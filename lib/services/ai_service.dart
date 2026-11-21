import 'dart:typed_data';

import '../models/ai_suggestion.dart';

/// Clothing analysis.
///
/// The one interface in the app that reaches a real external service. Two
/// implementations exist:
///   * `GeminiAiService` - the real Gemini call (production path)
///   * `MockAiService`   - canned response, used only in tests
///
/// No widget calls the API directly; everything goes through here. When this
/// moves behind a server-side proxy, only the implementation changes.
abstract class AiService {
  /// Analyses a single garment photo and proposes attributes.
  ///
  /// Never throws. Failures return an empty [AiSuggestion] with a populated
  /// `errorMessage`; they must not be presented as model-generated results.
  Future<AiSuggestion> analyzeWardrobeItem(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  });

  /// Whether this implementation talks to a real model. Surfaced in the UI so
  /// the label never claims more than it should.
  bool get isLive;

  /// Model identifier for display and for the provenance record.
  String get modelName;
}
