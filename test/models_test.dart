import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_closet/core/constants/vocab.dart';
import 'package:my_closet/models/outfit.dart';
import 'package:my_closet/models/wardrobe_item.dart';

void main() {
  group('WardrobeItem JSON', () {
    test('round-trips through encode/decode', () {
      final WardrobeItem original = WardrobeItem(
        id: 'x',
        name: 'Grey Merino Sweater',
        category: 'Tops',
        primaryColor: 'Grey',
        secondaryColor: 'White',
        material: 'Wool',
        pattern: 'Solid',
        occasions: const <String>['Work', 'Dinner'],
        seasons: const <String>['Fall', 'Winter'],
        styles: const <String>['Smart Casual'],
        tags: const <String>['layering'],
        favorite: true,
        timesWorn: 7,
        lastWorn: DateTime.utc(2026, 11, 9),
      );

      final WardrobeItem restored = WardrobeItem.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.secondaryColor, 'White');
      expect(restored.occasions, original.occasions);
      expect(restored.styles, original.styles);
      expect(restored.lastWorn, original.lastWorn);
      expect(restored.favorite, isTrue);
    });

    test('missing optional fields decode to sensible defaults', () {
      final WardrobeItem item = WardrobeItem.fromJson(<String, dynamic>{
        'id': 'minimal',
        'name': 'Plain Tee',
        'category': 'Tops',
        'primaryColor': 'Black',
      });

      expect(item.occasions, isEmpty);
      expect(item.seasons, isEmpty);
      expect(item.indoor, isTrue);
      expect(item.outdoor, isTrue);
      expect(item.timesWorn, 0);
      expect(item.lastWorn, isNull);
      expect(item.attributeSource, AttributeSource.manual);
    });

    test('garbage field types do not throw', () {
      // Defensive parsing matters because seed files are hand-written and
      // stored records may come from an older build.
      final WardrobeItem item = WardrobeItem.fromJson(<String, dynamic>{
        'id': 'weird',
        'name': 123,
        'category': 'Tops',
        'primaryColor': 'Black',
        'occasions': 'not a list',
        'timesWorn': '5',
        'favorite': 'true',
        'purchasePrice': '19.99',
        'lastWorn': 'not a date',
      });

      expect(item.name, '123');
      expect(item.occasions, isEmpty);
      expect(item.timesWorn, 5);
      expect(item.favorite, isTrue);
      expect(item.purchasePrice, 19.99);
      expect(item.lastWorn, isNull);
    });

    test('searchHaystack covers the fields the search box promises', () {
      final WardrobeItem item = WardrobeItem(
        id: 'h',
        name: 'Blue Oxford Shirt',
        category: 'Tops',
        primaryColor: 'Blue',
        brand: 'Brooks Brothers',
        material: 'Cotton',
        tags: const <String>['work'],
        occasions: const <String>['Interview'],
      );

      final String haystack = item.searchHaystack;
      expect(haystack, contains('oxford'));
      expect(haystack, contains('brooks'));
      expect(haystack, contains('cotton'));
      expect(haystack, contains('work'));
      expect(haystack, contains('interview'));
    });
  });

  group('Outfit slots', () {
    test('slot keys round-trip by name', () {
      final Outfit outfit = Outfit(
        id: 'o',
        name: 'Test',
        items: const <OutfitSlot, String>{
          OutfitSlot.top: 't',
          OutfitSlot.footwear: 'f',
        },
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final Outfit restored = Outfit.fromJson(
        jsonDecode(jsonEncode(outfit.toJson())) as Map<String, dynamic>,
      );

      expect(restored.items[OutfitSlot.top], 't');
      expect(restored.items[OutfitSlot.footwear], 'f');
      expect(restored.items.length, 2);
    });

    test('unknown slot keys are ignored', () {
      final Outfit outfit = Outfit.fromJson(<String, dynamic>{
        'id': 'o',
        'name': 'Test',
        'items': <String, dynamic>{'top': 't', 'hat': 'h'},
      });
      expect(outfit.items.length, 1);
      expect(outfit.items[OutfitSlot.top], 't');
    });

    test('signature is order-independent', () {
      final Outfit a = Outfit.draft().copyWith(
        items: const <OutfitSlot, String>{
          OutfitSlot.top: '1',
          OutfitSlot.bottom: '2',
        },
      );
      final Outfit b = Outfit.draft().copyWith(
        items: const <OutfitSlot, String>{
          OutfitSlot.bottom: '2',
          OutfitSlot.top: '1',
        },
      );
      expect(a.signature, b.signature);
    });

    test('adding a dress clears top and bottom', () {
      final Outfit outfit = Outfit.draft()
          .copyWith(
            items: const <OutfitSlot, String>{
              OutfitSlot.top: 't',
              OutfitSlot.bottom: 'b',
              OutfitSlot.footwear: 'f',
            },
          )
          .withSlot(OutfitSlot.dress, 'd');

      expect(outfit.items.containsKey(OutfitSlot.top), isFalse);
      expect(outfit.items.containsKey(OutfitSlot.bottom), isFalse);
      expect(outfit.items[OutfitSlot.dress], 'd');
      expect(
        outfit.items[OutfitSlot.footwear],
        'f',
        reason: 'unrelated slots survive',
      );
    });

    test('adding a top clears a dress', () {
      final Outfit outfit = Outfit.draft()
          .copyWith(items: const <OutfitSlot, String>{OutfitSlot.dress: 'd'})
          .withSlot(OutfitSlot.top, 't');

      expect(outfit.items.containsKey(OutfitSlot.dress), isFalse);
      expect(outfit.items[OutfitSlot.top], 't');
    });

    test('every slot maps to a real wardrobe category', () {
      for (final OutfitSlot slot in OutfitSlot.values) {
        final String? category = kSlotCategory[slot];
        expect(category, isNotNull, reason: '$slot has no category');
        expect(Vocab.categories, contains(category));
        expect(kSlotLabel[slot], isNotNull);
      }
      expect(kSlotOrder.length, OutfitSlot.values.length);
    });

    test('slotForCategory is the inverse of kSlotCategory', () {
      for (final OutfitSlot slot in OutfitSlot.values) {
        expect(slotForCategory(kSlotCategory[slot]!), slot);
      }
      expect(slotForCategory('Nonexistent'), isNull);
    });
  });

  group('Vocab.match', () {
    test('exact and case-insensitive matches', () {
      expect(Vocab.match('Tops', Vocab.categories), 'Tops');
      expect(Vocab.match('tops', Vocab.categories), 'Tops');
      expect(Vocab.match('  TOPS  ', Vocab.categories), 'Tops');
    });

    test('an unambiguous prefix resolves', () {
      expect(Vocab.match('navy blue', Vocab.colors), 'Navy');
    });

    test('unknown values return null rather than a guess', () {
      expect(Vocab.match('chartreuse', Vocab.colors), isNull);
      expect(Vocab.match('', Vocab.colors), isNull);
      expect(Vocab.match(null, Vocab.colors), isNull);
    });

    test('a synonym is only accepted when it is in the allowed list', () {
      // 'sweater' maps to 'Tops', which is a category - so it must not
      // resolve when matching against colours.
      expect(Vocab.match('sweater', Vocab.categories), 'Tops');
      expect(Vocab.match('sweater', Vocab.colors), isNull);
    });

    test('matchAll drops unknowns and de-duplicates', () {
      expect(
        Vocab.matchAll(
          <String>['Work', 'work', 'Brunch', 'Gym'],
          Vocab.occasions,
        ),
        <String>['Work', 'Gym'],
      );
      expect(Vocab.matchAll('not a list', Vocab.occasions), isEmpty);
    });

    test('matchAll honours the limit', () {
      expect(
        Vocab.matchAll(Vocab.occasions, Vocab.occasions, limit: 3).length,
        3,
      );
    });

    test('suggestable tags are derived from styles and occasions', () {
      final List<String> tags = Vocab.suggestableTags;
      expect(tags, contains('business-casual'));
      expect(tags, contains('work'));
      expect(tags.every((String t) => t == t.toLowerCase()), isTrue);
      expect(tags.every((String t) => !t.contains(' ')), isTrue);
    });
  });
}
