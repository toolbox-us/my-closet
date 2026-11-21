import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_closet/features/wardrobe/widgets/ai_suggestion_card.dart';
import 'package:my_closet/models/ai_suggestion.dart';

/// The AI card is the one piece of UI the whole graded integration hangs on,
/// so its paths - accept, dismiss, and honest unavailable state - are
/// asserted directly.
void main() {
  Widget harness(
    AiSuggestion suggestion, {
    VoidCallback? onAccept,
    VoidCallback? onDismiss,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AiSuggestionCard(
            suggestion: suggestion,
            onAcceptAll: onAccept ?? () {},
            onDismiss: onDismiss ?? () {},
          ),
        ),
      ),
    );
  }

  const AiSuggestion live = AiSuggestion(
    category: 'Tops',
    subcategory: 'Oxford Shirt',
    primaryColor: 'White',
    pattern: 'Solid',
    material: 'Cotton',
    suggestedTags: <String>['work', 'business-casual'],
    suggestedName: 'White Oxford Shirt',
    modelUsed: 'test-model',
    elapsed: Duration(milliseconds: 820),
  );

  testWidgets('is labelled "Suggested Details", never "Detected"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(live));

    expect(find.text('Suggested Details'), findsOneWidget);
    expect(find.textContaining('Detected'), findsNothing);
    expect(find.textContaining('Identified'), findsNothing);
  });

  testWidgets('lists the proposed values', (WidgetTester tester) async {
    await tester.pumpWidget(harness(live));

    expect(find.text('White Oxford Shirt'), findsOneWidget);
    expect(find.text('Tops'), findsOneWidget);
    expect(find.text('Oxford Shirt'), findsOneWidget);
    expect(find.text('Cotton'), findsOneWidget);
    expect(find.text('work, business-casual'), findsOneWidget);
  });

  testWidgets('warns that material is a guess', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(live));
    expect(find.textContaining('material in particular'), findsOneWidget);
  });

  testWidgets('accept reports how many fields it will fill', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(live));
    // name, category, type, primary color, pattern, material, tags = 7
    expect(find.text('Accept 7 fields'), findsOneWidget);
  });

  testWidgets('accept and dismiss both fire', (WidgetTester tester) async {
    int accepted = 0;
    int dismissed = 0;

    await tester.pumpWidget(
      harness(
        live,
        onAccept: () => accepted++,
        onDismiss: () => dismissed++,
      ),
    );

    await tester.tap(find.text('Accept 7 fields'));
    await tester.pump();
    expect(accepted, 1);

    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(dismissed, 1);
  });

  testWidgets('a mock result is labelled as an example, not as AI output', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const AiSuggestion(
          category: 'Tops',
          primaryColor: 'White',
          isFallback: true,
          errorMessage: 'HTTP 429. Rate limit or quota exceeded.',
          rawResponse: '{"error":"quota"}',
          modelUsed: 'test-model (fallback)',
        ),
      ),
    );

    expect(find.text('Example'), findsOneWidget);
    expect(find.textContaining('This is an example'), findsOneWidget);
  });

  testWidgets('a Gemini error shows no fabricated suggestion or accept action',
      (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const AiSuggestion(
          errorMessage: 'No API key configured.',
          modelUsed: 'test-model',
        ),
      ),
    );

    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('No API key configured.'), findsOneWidget);
    expect(find.textContaining('Accept'), findsNothing);
  });

  testWidgets('technical details expose the raw response for debugging', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const AiSuggestion(
          category: 'Tops',
          primaryColor: 'White',
          isFallback: true,
          errorMessage: 'HTTP 404. Model or endpoint not found.',
          rawResponse: '{"error":"not found"}',
        ),
      ),
    );

    expect(find.text('Technical details'), findsOneWidget);
    expect(find.text('{"error":"not found"}'), findsNothing);

    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();

    expect(find.text('{"error":"not found"}'), findsOneWidget);
    expect(
      find.textContaining('Model or endpoint not found'),
      findsOneWidget,
    );
  });

  testWidgets('the privacy disclosure names the model and the trade-offs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiDisclosureDialog(modelName: 'test-model'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('test-model'), findsOneWidget);
    expect(find.textContaining('only the image is sent'), findsOneWidget);
    expect(find.textContaining('candidate garment details'), findsNWidgets(2));
    expect(find.textContaining('This step is optional'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
