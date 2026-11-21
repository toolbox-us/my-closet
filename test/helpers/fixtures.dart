import 'package:my_closet/models/user_profile.dart';
import 'package:my_closet/models/wardrobe_item.dart';
import 'package:my_closet/models/weather.dart';

/// Hand-built fixtures for the engine tests.
///
/// Deliberately separate from `assets/mock/*.json`: a test that depends on
/// seed data breaks whenever someone adds a shirt. These are the minimum
/// wardrobe each assertion needs.
class Fixtures {
  Fixtures._();

  static WardrobeItem item({
    required String id,
    required String name,
    required String category,
    required String color,
    String? material,
    List<String> occasions = const <String>[],
    List<String> seasons = const <String>[],
    List<String> styles = const <String>[],
    bool favorite = false,
    bool indoor = true,
    bool outdoor = true,
    int timesWorn = 0,
    DateTime? lastWorn,
  }) {
    return WardrobeItem(
      id: id,
      name: name,
      category: category,
      primaryColor: color,
      material: material,
      occasions: occasions,
      seasons: seasons,
      styles: styles,
      favorite: favorite,
      indoor: indoor,
      outdoor: outdoor,
      timesWorn: timesWorn,
      lastWorn: lastWorn,
      pattern: 'Solid',
    );
  }

  // --- The wardrobe from the plan's worked example -------------------------

  static final WardrobeItem whiteShirt = item(
    id: 'white_shirt',
    name: 'White Shirt',
    category: 'Tops',
    color: 'White',
    material: 'Cotton',
    occasions: <String>['Work', 'Dinner', 'Interview'],
    seasons: <String>['Spring', 'Fall'],
    styles: <String>['Business Casual', 'Smart Casual'],
  );

  static final WardrobeItem navyChinos = item(
    id: 'navy_chinos',
    name: 'Navy Chinos',
    category: 'Bottoms',
    color: 'Navy',
    material: 'Cotton',
    occasions: <String>['Work', 'Dinner'],
    seasons: <String>['Spring', 'Fall', 'Winter'],
    styles: <String>['Business Casual'],
  );

  static final WardrobeItem brownLoafers = item(
    id: 'brown_loafers',
    name: 'Brown Loafers',
    category: 'Footwear',
    color: 'Brown',
    material: 'Leather',
    occasions: <String>['Work', 'Dinner'],
    seasons: <String>['Spring', 'Fall'],
    styles: <String>['Business Casual'],
  );

  static final WardrobeItem greyJacket = item(
    id: 'grey_jacket',
    name: 'Grey Jacket',
    category: 'Outerwear',
    color: 'Grey',
    material: 'Wool',
    occasions: <String>['Work', 'Dinner'],
    seasons: <String>['Fall', 'Winter'],
    styles: <String>['Business Casual'],
  );

  static final WardrobeItem yellowShorts = item(
    id: 'yellow_shorts',
    name: 'Yellow Shorts',
    category: 'Bottoms',
    color: 'Yellow',
    material: 'Cotton',
    occasions: <String>['Casual'],
    seasons: <String>['Summer'],
    styles: <String>['Casual'],
  );

  /// Extra pieces so accessory and alternative-slot paths have something to
  /// choose from.
  static final WardrobeItem brownWatch = item(
    id: 'brown_watch',
    name: 'Brown Watch',
    category: 'Accessories',
    color: 'Brown',
    material: 'Leather',
    occasions: <String>['Work', 'Dinner', 'Casual'],
    seasons: <String>['Spring', 'Summer', 'Fall', 'Winter'],
    styles: <String>['Business Casual', 'Smart Casual'],
  );

  static final WardrobeItem suedeBoots = item(
    id: 'suede_boots',
    name: 'Suede Boots',
    category: 'Footwear',
    color: 'Brown',
    material: 'Suede',
    occasions: <String>['Casual', 'Dinner'],
    seasons: <String>['Fall', 'Winter'],
    styles: <String>['Smart Casual'],
  );

  static final WardrobeItem beigeChinos = item(
    id: 'beige_chinos',
    name: 'Beige Chinos',
    category: 'Bottoms',
    color: 'Beige',
    material: 'Cotton',
    occasions: <String>['Work', 'Casual', 'Dinner'],
    seasons: <String>['Spring', 'Fall'],
    styles: <String>['Business Casual', 'Smart Casual'],
  );

  static List<WardrobeItem> get planScenarioWardrobe => <WardrobeItem>[
        whiteShirt,
        navyChinos,
        brownLoafers,
        greyJacket,
        yellowShorts,
      ];

  static List<WardrobeItem> get fullWardrobe => <WardrobeItem>[
        ...planScenarioWardrobe,
        brownWatch,
        suedeBoots,
        beigeChinos,
      ];

  // --- Other inputs --------------------------------------------------------

  static const Weather rainy52 = Weather(
    temperatureF: 52,
    condition: 'Light Rain',
    wind: 'Moderate Wind',
    scenarioName: 'Rain',
  );

  static const Weather hot94 = Weather(
    temperatureF: 94,
    condition: 'Sunny',
    wind: 'Low Wind',
    humidityPercent: 75,
    scenarioName: 'Hot',
  );

  static const UserProfile profile = UserProfile(
    name: 'Test User',
    preferredStyles: <String>['Business Casual', 'Smart Casual'],
    onboardingComplete: true,
  );
}
