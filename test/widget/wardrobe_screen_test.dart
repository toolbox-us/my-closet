import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_closet/data/memory/in_memory_repositories.dart';
import 'package:my_closet/features/wardrobe/wardrobe_screen.dart';
import 'package:my_closet/models/wardrobe_item.dart';
import 'package:my_closet/providers/providers.dart';

import '../helpers/fixtures.dart';

void main() {
  Widget harness(List<WardrobeItem> items) {
    return ProviderScope(
      overrides: [
        wardrobeRepositoryProvider
            .overrideWithValue(InMemoryWardrobeRepository(items)),
      ],
      child: const MaterialApp(home: WardrobeScreen()),
    );
  }

  final List<WardrobeItem> items = <WardrobeItem>[
    Fixtures.whiteShirt,
    Fixtures.navyChinos,
    Fixtures.brownLoafers,
    Fixtures.yellowShorts,
  ];

  testWidgets('shows every item once loaded', (WidgetTester tester) async {
    await tester.pumpWidget(harness(items));
    await tester.pumpAndSettle();

    expect(find.text('White Shirt'), findsOneWidget);
    expect(find.text('Navy Chinos'), findsOneWidget);
    expect(find.text('Brown Loafers'), findsOneWidget);
    expect(find.text('4 of 4 items'), findsOneWidget);
  });

  testWidgets('an empty wardrobe shows the empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(<WardrobeItem>[]));
    await tester.pumpAndSettle();

    expect(find.text('Your wardrobe is empty'), findsOneWidget);
  });

  testWidgets('a category chip filters the grid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(items));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Footwear'));
    await tester.pumpAndSettle();

    expect(find.text('Brown Loafers'), findsOneWidget);
    expect(find.text('White Shirt'), findsNothing);
    expect(find.text('1 of 4 items'), findsOneWidget);
  });

  testWidgets('search narrows by name', (WidgetTester tester) async {
    await tester.pumpWidget(harness(items));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'chinos');
    await tester.pumpAndSettle();

    expect(find.text('Navy Chinos'), findsOneWidget);
    expect(find.text('White Shirt'), findsNothing);
  });

  testWidgets('search matches material, not just the name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(items));
    await tester.pumpAndSettle();

    // Brown Loafers are the only Leather item in the fixture set.
    await tester.enterText(find.byType(TextField).first, 'leather');
    await tester.pumpAndSettle();

    expect(find.text('Brown Loafers'), findsOneWidget);
    expect(find.text('Navy Chinos'), findsNothing);
  });

  testWidgets('a search with no results offers to clear filters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(items));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('Nothing matches'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('White Shirt'), findsOneWidget);
  });

  testWidgets('tapping the heart persists the favorite', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(items));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsNothing);

    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });
}
