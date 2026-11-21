/// Build-time configuration.
///
/// Values come from `--dart-define` so that no API key is ever committed to
/// the repository or baked into a source file. See README.
///
/// Known limitation, documented deliberately: a key supplied this way is
/// still embedded in the compiled binary and can be recovered from an APK.
/// That is acceptable for a course prototype but NOT for production, where
/// the call belongs behind a server-side proxy (or Firebase AI Logic, which
/// keeps the key off the client entirely).
class AppConfig {
  AppConfig._();

  /// Gemini API key. Empty when not supplied; analysis then reports a
  /// configuration error instead of returning sample data.
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Image-capable model id.
  ///
  /// Gemini model names turn over quickly. The 2.5 family is access-limited
  /// to accounts that used it previously, so new projects should use a 3.x
  /// Flash model. Confirm the current name at
  /// https://ai.google.dev/gemini-api/docs/models before a demo.
  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.8-flash',
  );

  /// The Interactions API endpoint. This replaced the older
  /// `:generateContent` endpoint for new projects.
  static const String geminiEndpoint = String.fromEnvironment(
    'GEMINI_ENDPOINT',
    defaultValue:
        'https://generativelanguage.googleapis.com/v1beta/interactions',
  );

  /// Optional API revision pin (e.g. `2026-05-20`).
  ///
  /// Empty means "use the server default". Pin a date here if a future
  /// breaking change alters the request or response shape.
  static const String geminiApiRevision =
      String.fromEnvironment('GEMINI_API_REVISION');

  /// Request timeout for the AI call. Kept short: a demo should fall back to
  /// a mock suggestion rather than leave the user staring at a spinner.
  static const Duration aiTimeout = Duration(seconds: 20);

  static bool get hasApiKey => geminiApiKey.trim().isNotEmpty;

  static bool get hasApiRevision => geminiApiRevision.trim().isNotEmpty;

  /// Longest edge for picked photos. Downscaling at pick time keeps the AI
  /// request small (latency + token cost) with no accuracy loss for
  /// single-garment classification.
  static const double maxImageEdge = 1440;
  static const int imageQuality = 85;
}
