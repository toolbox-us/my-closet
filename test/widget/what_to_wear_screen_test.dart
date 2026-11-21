import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_closet/data/memory/in_memory_repositories.dart';
import 'package:my_closet/features/recommendations/what_to_wear_screen.dart';
import 'package:my_closet/providers/providers.dart';

import '../helpers/fixtures.dart';

void main() {
  testWidgets('saves a named recommendation as the keyboard closes', (
    WidgetTester tester,
  ) async {
    final InMemoryOutfitRepository outfits = InMemoryOutfitRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wardrobeRepositoryProvider.overrideWithValue(
            InMemoryWardrobeRepository(Fixtures.fullWardrobe),
          ),
          outfitRepositoryProvider.overrideWithValue(outfits),
          profileRepositoryProvider.overrideWithValue(
            InMemoryProfileRepository(Fixtures.profile),
          ),
          feedbackRepositoryProvider.overrideWithValue(
            InMemoryFeedbackRepository(),
          ),
        ],
        child: const MaterialApp(home: WhatToWearScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder generate = find.text('Generate Outfit');
    await tester.scrollUntilVisible(generate, 240);
    await tester.tap(generate);
    await tester.pumpAndSettle();

    final Finder save = find.widgetWithText(OutlinedButton, 'Save');
    await tester.scrollUntilVisible(save, 240);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final Finder dialog = find.byType(AlertDialog);
    await tester.enterText(find.byType(TextField), '  Monday Office  ');
    addTearDown(tester.view.resetViewInsets);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: dialog, matching: find.text('Save')),
    );
    await tester.pump();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(dialog, findsNothing);
    expect((await outfits.getAll()).single.name, 'Monday Office');
  });
}
