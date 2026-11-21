import 'dart:typed_data';

import '../models/ai_suggestion.dart';
import 'ai_service.dart';

/// Canned clothing analysis.
///
/// Two jobs:
///   1. Test double - widget and unit tests never hit the network.
///
/// The returned values are all inside the app's controlled vocabulary, which
/// is also what makes this a useful fixture for the accept/modify flow.
class MockAiService implements AiService {
  const MockAiService({this.latency = const Duration(milliseconds: 600)});

  final Duration latency;

  @override
  bool get isLive => false;

  @override
  String get modelName => 'mock';

  @override
  Future<AiSuggestion> analyzeWardrobeItem(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    await Future<void>.delayed(latency);
    return const AiSuggestion(
      category: 'Tops',
      subcategory: 'Oxford Shirt',
      primaryColor: 'White',
      pattern: 'Solid',
      material: 'Cotton',
      suggestedTags: <String>['business-casual', 'work', 'smart-casual'],
      suggestedName: 'White Oxford Shirt',
      modelUsed: 'mock',
      isFallback: true,
    );
  }
}
