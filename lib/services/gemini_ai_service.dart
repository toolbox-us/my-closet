import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/constants/vocab.dart';
import '../models/ai_suggestion.dart';
import 'ai_service.dart';

/// Real clothing analysis via the Gemini Interactions API.
///
/// ## Why raw HTTP and not a Google SDK
///
/// The `google_generative_ai` Dart SDK was deprecated in favour of the
/// Firebase AI Logic plugin (`firebase_ai`). Firebase AI Logic is the better
/// production answer - it keeps the key off the client - but it requires a
/// Firebase project, which pulls cloud infrastructure into a prototype that
/// is otherwise backend-free. A ~100-line REST client keeps the dependency
/// surface at `http` and makes the whole integration visible in one file,
/// which is also easier to write about.
///
/// ## Known limitation
///
/// The API key is compiled into the app and can be recovered from an APK.
/// Acceptable for a course prototype; not for production. The remedy is a
/// server-side proxy or Firebase AI Logic. This is stated plainly rather
/// than hidden.
///
/// ## API surface churn
///
/// Google replaced the older `:generateContent` endpoint with
/// `/v1beta/interactions` for new projects, and the raw REST response shape
/// is not fully documented (the SDKs expose `output_text` as a convenience
/// property over an `outputs` array). [extractText] therefore tries several
/// shapes, including the legacy one, instead of assuming a single layout.
/// If a future revision breaks it, the debug sheet in the add-item screen
/// shows the raw body so the fix is a one-line change here.
class GeminiAiService implements AiService {
  GeminiAiService({
    required this.client,
    String? apiKey,
    String? model,
    String? endpoint,
    String? apiRevision,
    Duration? timeout,
  })  : apiKey = apiKey ?? AppConfig.geminiApiKey,
        model = model ?? AppConfig.geminiModel,
        endpoint = endpoint ?? AppConfig.geminiEndpoint,
        apiRevision = apiRevision ??
            (AppConfig.hasApiRevision ? AppConfig.geminiApiRevision : null),
        timeout = timeout ?? AppConfig.aiTimeout;

  final http.Client client;

  final String apiKey;
  final String model;
  final String endpoint;
  final String? apiRevision;
  final Duration timeout;

  @override
  bool get isLive => apiKey.trim().isNotEmpty;

  @override
  String get modelName => model;

  @override
  Future<AiSuggestion> analyzeWardrobeItem(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    if (apiKey.trim().isEmpty) {
      return _failure(
        'No API key configured. Pass --dart-define=GEMINI_API_KEY=...',
        null,
      );
    }

    try {
      final http.Response response = await client
          .post(
            Uri.parse(endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
              if (apiRevision != null && apiRevision!.isNotEmpty)
                'Api-Revision': apiRevision!,
            },
            body: jsonEncode(buildRequestBody(imageBytes, mimeType)),
          )
          .timeout(timeout);

      stopwatch.stop();

      if (response.statusCode != 200) {
        return _failure(
          'HTTP ${response.statusCode}. ${_hint(response.statusCode)}',
          _truncate(response.body),
        );
      }

      Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException catch (error) {
        return _failure(
          'Gemini returned invalid JSON: ${error.message}',
          _truncate(response.body),
        );
      }
      if (decoded is! Map) {
        return _failure(
          'Unexpected response: not a JSON object.',
          _truncate(response.body),
        );
      }

      final String? text = extractText(Map<String, dynamic>.from(decoded));
      if (text == null || text.trim().isEmpty) {
        return _failure(
          'Could not find generated text in the response. The API shape may '
          'have changed - check the raw body below.',
          _truncate(response.body),
        );
      }

      final AiSuggestion? parsed = parseSuggestion(text, model: model);
      if (parsed == null) {
        return _failure(
          'The model did not return parseable JSON.',
          _truncate(text),
        );
      }

      if (!parsed.hasContent) {
        return _failure(
          'The model returned no attributes it was confident about.',
          _truncate(text),
        );
      }

      return parsed.copyWith(
        rawResponse: _truncate(response.body),
        elapsed: stopwatch.elapsed,
      );
    } on TimeoutException {
      return _failure(
        'The request timed out after ${timeout.inSeconds}s.',
        null,
      );
    } catch (error) {
      return _failure('Request failed: $error', null);
    }
  }

  // ---------------------------------------------------------------------------
  // Request
  // ---------------------------------------------------------------------------

  /// Interactions API body: a typed `input` array with the text instruction
  /// first and the image second, which is the ordering the image-
  /// understanding docs use for a single image plus a prompt.
  Map<String, dynamic> buildRequestBody(
    Uint8List imageBytes,
    String mimeType,
  ) {
    return <String, dynamic>{
      'model': model,
      'input': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'text',
          'text': buildPrompt(),
        },
        <String, dynamic>{
          'type': 'image',
          'data': base64Encode(imageBytes),
          'mime_type': mimeType,
        },
      ],
      // If a future revision documents a stable structured-output field for
      // interactions, set it here and the prompt can be shortened. Until
      // then the prompt asks for JSON and `parseSuggestion` is tolerant,
      // which works regardless of whether the field is supported.
    };
  }

  /// Constrains every field to the app's own vocabulary.
  ///
  /// Without these enumerations the model returns "sage" and "ecru" while the
  /// filter chips only know "green" and "beige", and the suggestion fails
  /// silently. Values outside the lists are dropped at parse time as a second
  /// line of defence.
  static String buildPrompt() {
    final String categories = Vocab.categories.join(', ');
    final String colors = Vocab.colors.join(', ');
    final String patterns = Vocab.patterns.join(', ');
    final String materials = Vocab.materials.join(', ');
    final String tags = Vocab.suggestableTags.join(', ');

    return '''
You are tagging ONE clothing item for a personal wardrobe app.

Return ONLY a JSON object. No markdown, no code fences, no commentary.

Use exactly these keys:
{
  "suggestedName": string,
  "category": string,
  "subcategory": string,
  "primaryColor": string,
  "secondaryColor": string,
  "pattern": string,
  "material": string,
  "suggestedTags": [string]
}

Rules:
- "category" MUST be one of: $categories
- "primaryColor" and "secondaryColor" MUST be one of: $colors
- "pattern" MUST be one of: $patterns
- "material" MUST be one of: $materials
- "suggestedTags" MUST be up to 4 values from: $tags
- "subcategory" is a short free-text garment type, e.g. "Oxford Shirt",
  "Chinos", "Chelsea Boots". Two words maximum.
- "suggestedName" is a short display name combining colour and garment type,
  e.g. "Navy Linen Shirt". Four words maximum.
- Use null for any field you cannot determine with confidence. Do not guess.
- Material is inferred from visual texture only and is the least reliable
  field; prefer null over a guess.
- If the photo shows more than one garment, describe the most prominent one.
''';
  }

  // ---------------------------------------------------------------------------
  // Response
  // ---------------------------------------------------------------------------

  /// Pulls the model's text out of a response body.
  ///
  /// Tries, in order:
  ///   1. `output_text` (if the REST surface exposes the SDK convenience key)
  ///   2. `outputs[].text`, last first (the documented raw accessor is
  ///      `outputs[-1].text`)
  ///   3. `outputs[].content[].text`
  ///   4. `candidates[0].content.parts[].text` (legacy generateContent)
  ///
  /// Static and public so tests can exercise every shape with no network.
  static String? extractText(Map<String, dynamic> body) {
    final Object? direct = body['output_text'];
    if (direct is String && direct.trim().isNotEmpty) return direct;

    final Object? outputs = body['outputs'];
    if (outputs is List) {
      for (final Object? entry in outputs.reversed) {
        if (entry is! Map) continue;

        final Object? text = entry['text'];
        if (text is String && text.trim().isNotEmpty) return text;

        final Object? content = entry['content'];
        if (content is List) {
          for (final Object? part in content.reversed) {
            if (part is Map) {
              final Object? partText = part['text'];
              if (partText is String && partText.trim().isNotEmpty) {
                return partText;
              }
            }
          }
        }
      }
    }

    final Object? candidates = body['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final Object? first = candidates.first;
      if (first is Map) {
        final Object? content = first['content'];
        if (content is Map) {
          final Object? parts = content['parts'];
          if (parts is List) {
            for (final Object? part in parts) {
              if (part is Map) {
                final Object? partText = part['text'];
                if (partText is String && partText.trim().isNotEmpty) {
                  return partText;
                }
              }
            }
          }
        }
      }
    }

    return null;
  }

  /// Parses the model's text into an [AiSuggestion], dropping any value
  /// outside the controlled vocabulary.
  ///
  /// Returns null when no JSON object could be recovered at all.
  static AiSuggestion? parseSuggestion(String text, {String model = ''}) {
    final String? jsonText = firstJsonObject(text);
    if (jsonText == null) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;

    final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);

    final String? category = Vocab.match(map['category'], Vocab.categories);
    final String? primary = Vocab.match(map['primaryColor'], Vocab.colors);
    final String? secondary = Vocab.match(map['secondaryColor'], Vocab.colors);

    return AiSuggestion(
      category: category,
      // Subcategory is intentionally free text - it is a label, not something
      // the app filters or scores on. Length-capped so a chatty model cannot
      // push a sentence into a form field.
      subcategory: _shortText(map['subcategory'], 40),
      primaryColor: primary,
      // Guard against the model repeating the primary colour.
      secondaryColor: secondary == primary ? null : secondary,
      pattern: Vocab.match(map['pattern'], Vocab.patterns),
      material: Vocab.match(map['material'], Vocab.materials),
      suggestedTags:
          Vocab.matchAll(map['suggestedTags'], Vocab.suggestableTags, limit: 4),
      suggestedName: _shortText(map['suggestedName'], 48),
      modelUsed: model,
    );
  }

  /// Finds the first balanced JSON object in [text].
  ///
  /// Models wrap JSON in prose or fences even when told not to, so this
  /// scans for a brace-balanced span rather than trusting the whole string.
  /// String literals are tracked so a brace inside a value does not throw
  /// off the depth count.
  static String? firstJsonObject(String text) {
    final int start = text.indexOf('{');
    if (start < 0) return null;

    int depth = 0;
    bool inString = false;
    bool escaped = false;

    for (int i = start; i < text.length; i++) {
      final String ch = text[i];

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }

      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          return text.substring(start, i + 1);
        }
      }
    }

    return null;
  }

  static String? _shortText(Object? value, int maxLength) {
    if (value == null) return null;
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    if (text.toLowerCase() == 'null') return null;
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength).trim();
  }

  static String _truncate(String value, [int maxLength = 600]) =>
      value.length <= maxLength
          ? value
          : '${value.substring(0, maxLength)}...[truncated]';

  /// Turns a status code into something actionable rather than a number.
  static String _hint(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'The request was rejected. The model name may be wrong, or '
            'this model may not accept image input.';
      case 401:
      case 403:
        return 'The API key was rejected. Check the key and that the Gemini '
            'API is enabled for it.';
      case 404:
        return 'Model or endpoint not found. Confirm the current model name '
            'at ai.google.dev/gemini-api/docs/models.';
      case 429:
        return 'Rate limit or quota exceeded. Wait and retry.';
      case 500:
      case 503:
        return 'The service is unavailable. Retry shortly.';
      default:
        return 'See the raw response below.';
    }
  }

  AiSuggestion _failure(String reason, String? raw) {
    return AiSuggestion(
      modelUsed: model,
      errorMessage: reason,
      rawResponse: raw,
    );
  }
}
