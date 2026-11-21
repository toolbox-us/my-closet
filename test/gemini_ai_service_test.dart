import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_closet/models/ai_suggestion.dart';
import 'package:my_closet/services/gemini_ai_service.dart';
import 'package:my_closet/services/mock_ai_service.dart';

/// No test here touches the network.
///
/// That is deliberate twice over: tests must pass offline, and they must not
/// burn API quota in CI. Every HTTP interaction is a stubbed client.
void main() {
  final Uint8List fakeImage = Uint8List.fromList(<int>[1, 2, 3, 4]);

  GeminiAiService serviceWith(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return GeminiAiService(
      client: _StubClient(handler),
      apiKey: 'test-key',
      model: 'test-model',
      endpoint: 'https://example.invalid/v1beta/interactions',
      timeout: const Duration(seconds: 2),
    );
  }

  group('extractText handles every response shape', () {
    test('output_text at the top level', () {
      expect(
        GeminiAiService.extractText(<String, dynamic>{
          'output_text': '{"category":"Tops"}',
        }),
        '{"category":"Tops"}',
      );
    });

    test('outputs[].text, reading the last entry first', () {
      // The documented raw accessor is outputs[-1].text.
      expect(
        GeminiAiService.extractText(<String, dynamic>{
          'id': 'int_123',
          'status': 'completed',
          'outputs': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'reasoning', 'text': 'thinking...'},
            <String, dynamic>{'type': 'message', 'text': 'final answer'},
          ],
        }),
        'final answer',
      );
    });

    test('outputs[].content[].text', () {
      expect(
        GeminiAiService.extractText(<String, dynamic>{
          'outputs': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'model_output',
              'content': <Map<String, dynamic>>[
                <String, dynamic>{'type': 'text', 'text': 'nested answer'},
              ],
            },
          ],
        }),
        'nested answer',
      );
    });

    test('legacy generateContent candidates shape', () {
      expect(
        GeminiAiService.extractText(<String, dynamic>{
          'candidates': <Map<String, dynamic>>[
            <String, dynamic>{
              'content': <String, dynamic>{
                'parts': <Map<String, dynamic>>[
                  <String, dynamic>{'text': 'legacy answer'},
                ],
              },
            },
          ],
        }),
        'legacy answer',
      );
    });

    test('returns null when nothing usable is present', () {
      expect(
        GeminiAiService.extractText(<String, dynamic>{
          'id': 'x',
          'usage': <String, dynamic>{'total_tokens': 10},
        }),
        isNull,
      );
      expect(
        GeminiAiService.extractText(<String, dynamic>{
          'outputs': <Map<String, dynamic>>[
            <String, dynamic>{'text': '   '},
          ],
        }),
        isNull,
      );
    });
  });

  group('firstJsonObject survives messy model output', () {
    test('plain object', () {
      expect(GeminiAiService.firstJsonObject('{"a":1}'), '{"a":1}');
    });

    test('markdown fences', () {
      expect(
        GeminiAiService.firstJsonObject('```json\n{"a":1}\n```'),
        '{"a":1}',
      );
    });

    test('surrounding prose', () {
      expect(
        GeminiAiService.firstJsonObject(
          'Sure! Here is the JSON:\n{"a":1}\nLet me know if...',
        ),
        '{"a":1}',
      );
    });

    test('nested objects', () {
      expect(
        GeminiAiService.firstJsonObject('noise {"a":{"b":2}} tail'),
        '{"a":{"b":2}}',
      );
    });

    test('braces inside string values do not confuse the depth count', () {
      expect(
        GeminiAiService.firstJsonObject(r'{"a":"literal } brace"}'),
        r'{"a":"literal } brace"}',
      );
    });

    test('escaped quotes do not confuse the string tracker', () {
      expect(
        GeminiAiService.firstJsonObject(r'{"a":"say \"hi\""}'),
        r'{"a":"say \"hi\""}',
      );
    });

    test('returns null with no object at all', () {
      expect(GeminiAiService.firstJsonObject('no json here'), isNull);
      expect(GeminiAiService.firstJsonObject('{"unterminated":'), isNull);
    });
  });

  group('parseSuggestion enforces the controlled vocabulary', () {
    test('clean values pass through', () {
      final AiSuggestion? parsed = GeminiAiService.parseSuggestion(
        '{"category":"Tops","primaryColor":"White","pattern":"Solid",'
        '"material":"Cotton","subcategory":"Oxford Shirt",'
        '"suggestedName":"White Oxford Shirt",'
        '"suggestedTags":["work","business-casual"]}',
        model: 'test-model',
      );

      expect(parsed, isNotNull);
      expect(parsed!.category, 'Tops');
      expect(parsed.primaryColor, 'White');
      expect(parsed.material, 'Cotton');
      expect(parsed.subcategory, 'Oxford Shirt');
      expect(parsed.suggestedTags, containsAll(<String>['work']));
      expect(parsed.modelUsed, 'test-model');
      expect(parsed.isFallback, isFalse);
    });

    test('model-speak colours map onto the app vocabulary', () {
      // This is the failure the plan called out: an unconstrained model
      // returns "sage" and "ecru" while the filter chips only know "green"
      // and "beige".
      final AiSuggestion? sage = GeminiAiService.parseSuggestion(
        '{"primaryColor":"sage","secondaryColor":"ecru"}',
      );
      expect(sage!.primaryColor, 'Green');
      expect(sage.secondaryColor, 'Beige');
    });

    test('category synonyms map onto real categories', () {
      expect(
        GeminiAiService.parseSuggestion('{"category":"sweater"}')!.category,
        'Tops',
      );
      expect(
        GeminiAiService.parseSuggestion('{"category":"sneakers"}')!.category,
        'Footwear',
      );
      expect(
        GeminiAiService.parseSuggestion('{"category":"watch"}')!.category,
        'Accessories',
      );
    });

    test('unrecognised values are dropped, not written through', () {
      final AiSuggestion? parsed = GeminiAiService.parseSuggestion(
        '{"category":"spacesuit","primaryColor":"ultraviolet",'
        '"material":"velvet","pattern":"houndstooth",'
        '"suggestedTags":["spacewalk","work"]}',
      );

      expect(parsed, isNotNull);
      expect(parsed!.category, isNull);
      expect(parsed.primaryColor, isNull);
      expect(parsed.material, isNull);
      expect(parsed.pattern, isNull);
      expect(
        parsed.suggestedTags,
        <String>['work'],
        reason: 'only vocabulary tags survive',
      );
    });

    test('a repeated primary colour is not stored as the secondary', () {
      final AiSuggestion? parsed = GeminiAiService.parseSuggestion(
        '{"primaryColor":"Navy","secondaryColor":"Navy"}',
      );
      expect(parsed!.secondaryColor, isNull);
    });

    test('literal "null" strings are treated as absent', () {
      final AiSuggestion? parsed = GeminiAiService.parseSuggestion(
        '{"subcategory":"null","suggestedName":""}',
      );
      expect(parsed!.subcategory, isNull);
      expect(parsed.suggestedName, isNull);
    });

    test('over-long free text is capped', () {
      final String long = 'A' * 200;
      final AiSuggestion? parsed = GeminiAiService.parseSuggestion(
        jsonEncode(<String, dynamic>{'subcategory': long}),
      );
      expect(parsed!.subcategory!.length, lessThanOrEqualTo(40));
    });

    test('returns null when the text holds no JSON', () {
      expect(
        GeminiAiService.parseSuggestion('I cannot help with that.'),
        isNull,
      );
    });
  });

  group('request construction', () {
    test('sends the model, the prompt and the inline image', () {
      final GeminiAiService service = serviceWith(
        (http.Request request) async => http.Response('{}', 200),
      );

      final Map<String, dynamic> body =
          service.buildRequestBody(fakeImage, 'image/png');

      expect(body['model'], 'test-model');

      final List<dynamic> input = body['input'] as List<dynamic>;
      expect(input.length, 2);

      final Map<String, dynamic> text = input[0] as Map<String, dynamic>;
      expect(text['type'], 'text');
      expect(text['text'], contains('JSON'));

      final Map<String, dynamic> image = input[1] as Map<String, dynamic>;
      expect(image['type'], 'image');
      expect(image['mime_type'], 'image/png');
      expect(image['data'], base64Encode(fakeImage));
    });

    test('the prompt enumerates the allowed values', () {
      final String prompt = GeminiAiService.buildPrompt();
      expect(prompt, contains('Tops'));
      expect(prompt, contains('Beige'));
      expect(prompt, contains('Solid'));
      expect(prompt, contains('Cotton'));
      expect(prompt, contains('prefer null over a guess'));
    });

    test('the API key travels in the x-goog-api-key header', () async {
      String? seenKey;
      final GeminiAiService service = serviceWith((http.Request request) async {
        seenKey = request.headers['x-goog-api-key'];
        return http.Response(
          jsonEncode(<String, dynamic>{'output_text': '{"category":"Tops"}'}),
          200,
        );
      });

      await service.analyzeWardrobeItem(fakeImage);
      expect(seenKey, 'test-key');
    });
  });

  group('failures return errors instead of fabricated suggestions', () {
    test('a successful call returns a Gemini suggestion', () async {
      final GeminiAiService service = serviceWith(
        (http.Request request) async => http.Response(
          jsonEncode(<String, dynamic>{
            'outputs': <Map<String, dynamic>>[
              <String, dynamic>{
                'text': '{"category":"Footwear","primaryColor":"Brown"}',
              },
            ],
          }),
          200,
        ),
      );

      final AiSuggestion result = await service.analyzeWardrobeItem(fakeImage);
      expect(result.isFallback, isFalse);
      expect(result.category, 'Footwear');
      expect(result.primaryColor, 'Brown');
      expect(result.elapsed, isNotNull);
    });

    test('a 429 reports the quota problem without a suggestion', () async {
      final GeminiAiService service = serviceWith(
        (http.Request request) async => http.Response('{"error":"quota"}', 429),
      );

      final AiSuggestion result = await service.analyzeWardrobeItem(fakeImage);
      expect(result.isFallback, isFalse);
      expect(result.hasContent, isFalse);
      expect(result.errorMessage, contains('429'));
      expect(result.errorMessage, contains('quota'));
      expect(result.rawResponse, isNotNull);
    });

    test('a 404 points at the model name', () async {
      final GeminiAiService service = serviceWith(
        (http.Request request) async => http.Response('not found', 404),
      );

      final AiSuggestion result = await service.analyzeWardrobeItem(fakeImage);
      expect(result.hasContent, isFalse);
      expect(result.errorMessage, contains('model name'));
    });

    test('malformed JSON reports an error rather than crashing', () async {
      final GeminiAiService service = serviceWith(
        (http.Request request) async => http.Response('not json at all', 200),
      );

      final AiSuggestion result = await service.analyzeWardrobeItem(fakeImage);
      expect(result.hasContent, isFalse);
      expect(result.errorMessage, contains('invalid JSON'));
    });

    test('an unrecognised response shape returns an error and raw body',
        () async {
      final GeminiAiService service = serviceWith(
        (http.Request request) async => http.Response(
          jsonEncode(<String, dynamic>{'something': 'unexpected'}),
          200,
        ),
      );

      final AiSuggestion result = await service.analyzeWardrobeItem(fakeImage);
      expect(result.hasContent, isFalse);
      expect(result.errorMessage, contains('API shape'));
      expect(result.rawResponse, contains('unexpected'));
    });

    test('a thrown transport error returns an error', () async {
      final GeminiAiService service = serviceWith(
        (http.Request request) async => throw const _FakeSocketException(),
      );

      final AiSuggestion result = await service.analyzeWardrobeItem(fakeImage);
      expect(result.hasContent, isFalse);
      expect(result.errorMessage, contains('Request failed'));
    });

    test('a timeout returns an error', () async {
      final GeminiAiService service = GeminiAiService(
        client: _StubClient((http.Request request) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return http.Response('{}', 200);
        }),
        apiKey: 'test-key',
        model: 'test-model',
        endpoint: 'https://example.invalid/v1beta/interactions',
        timeout: const Duration(milliseconds: 20),
      );

      final AiSuggestion result = await service.analyzeWardrobeItem(fakeImage);
      expect(result.hasContent, isFalse);
      expect(result.errorMessage, contains('timed out'));
    });

    test('an empty API key short-circuits without a request', () async {
      bool called = false;
      final GeminiAiService service = GeminiAiService(
        client: _StubClient((http.Request request) async {
          called = true;
          return http.Response('{}', 200);
        }),
        apiKey: '   ',
        model: 'test-model',
        endpoint: 'https://example.invalid/v1beta/interactions',
      );

      final AiSuggestion result = await service.analyzeWardrobeItem(fakeImage);
      expect(called, isFalse);
      expect(result.isFallback, isFalse);
      expect(result.hasContent, isFalse);
      expect(result.errorMessage, contains('No API key'));
      expect(service.isLive, isFalse);
    });

    test('a model that answers with no usable attributes reports an error',
        () async {
      final GeminiAiService service = serviceWith(
        (http.Request request) async => http.Response(
          jsonEncode(<String, dynamic>{
            'output_text': '{"category":"spacesuit","material":"velvet"}',
          }),
          200,
        ),
      );

      final AiSuggestion result = await service.analyzeWardrobeItem(fakeImage);
      expect(result.isFallback, isFalse);
      expect(result.hasContent, isFalse);
      expect(result.errorMessage, contains('no attributes'));
    });
  });

  group('MockAiService', () {
    test('returns vocabulary-valid values marked as a fallback', () async {
      const MockAiService mock = MockAiService(latency: Duration.zero);
      final AiSuggestion result = await mock.analyzeWardrobeItem(fakeImage);

      expect(result.isFallback, isTrue);
      expect(result.category, 'Tops');
      expect(result.hasContent, isTrue);
      expect(mock.isLive, isFalse);
    });
  });
}

/// Minimal stubbed http.Client. Avoids a mocking package so the test suite
/// has no extra dependency to resolve.
class _StubClient extends http.BaseClient {
  _StubClient(this.handler);

  final Future<http.Response> Function(http.Request request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final http.Request typed = request as http.Request;
    final http.Response response = await handler(typed);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

class _FakeSocketException implements Exception {
  const _FakeSocketException();

  @override
  String toString() => 'SocketException: host unreachable';
}
