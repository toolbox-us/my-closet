import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider/path_provider.dart';

/// Opens and holds the app's Hive boxes.
///
/// Every box is `Box<String>` holding JSON text, keyed by entity id. That
/// choice is deliberate: it removes the `hive_ce_generator` /
/// `build_runner` step entirely, so the project compiles after
/// `flutter pub get` with no code generation. The cost is that Hive cannot
/// query inside records - filtering happens in Dart - which is fine at
/// prototype scale and is discussed in the plan.
///
/// If the import above fails to resolve on your hive_ce version, try
/// `package:hive_ce/hive.dart` instead; the API is identical.
class AppBoxes {
  AppBoxes({
    required this.wardrobe,
    required this.outfits,
    required this.profile,
    required this.planner,
    required this.feedback,
    required this.auth,
    required this.meta,
  });

  final Box<String> wardrobe;
  final Box<String> outfits;
  final Box<String> profile;
  final Box<String> planner;
  final Box<String> feedback;
  final Box<String> auth;

  /// Flags that are not domain data: whether seeding has run, etc.
  final Box<String> meta;

  static const String wardrobeBox = 'wardrobe';
  static const String outfitsBox = 'outfits';
  static const String profileBox = 'profile';
  static const String plannerBox = 'planner';
  static const String feedbackBox = 'feedback';
  static const String authBox = 'auth';
  static const String metaBox = 'meta';

  /// Single-record boxes use a fixed key.
  static const String singletonKey = 'current';

  static const String seededFlag = 'seeded_v1';

  /// Call once, before `runApp`.
  static Future<AppBoxes> open() async {
    final String path = (await getApplicationDocumentsDirectory()).path;
    Hive.init(path);

    return AppBoxes(
      wardrobe: await Hive.openBox<String>(wardrobeBox),
      outfits: await Hive.openBox<String>(outfitsBox),
      profile: await Hive.openBox<String>(profileBox),
      planner: await Hive.openBox<String>(plannerBox),
      feedback: await Hive.openBox<String>(feedbackBox),
      auth: await Hive.openBox<String>(authBox),
      meta: await Hive.openBox<String>(metaBox),
    );
  }

  /// Boxes for tests. Call `Hive.init(<temp dir>)` first - see
  /// `test/persistence_test.dart`. The suffix keeps test runs isolated from
  /// each other.
  static Future<AppBoxes> openForTests({String suffix = 'test'}) async {
    return AppBoxes(
      wardrobe: await Hive.openBox<String>('${wardrobeBox}_$suffix'),
      outfits: await Hive.openBox<String>('${outfitsBox}_$suffix'),
      profile: await Hive.openBox<String>('${profileBox}_$suffix'),
      planner: await Hive.openBox<String>('${plannerBox}_$suffix'),
      feedback: await Hive.openBox<String>('${feedbackBox}_$suffix'),
      auth: await Hive.openBox<String>('${authBox}_$suffix'),
      meta: await Hive.openBox<String>('${metaBox}_$suffix'),
    );
  }

  bool get hasBeenSeeded => meta.get(seededFlag) == 'true';

  Future<void> markSeeded() => meta.put(seededFlag, 'true');

  /// Wipes domain data but keeps the account, so "Reset demo data" returns a
  /// grader to a known state without forcing another signup.
  Future<void> resetDemoData() async {
    await wardrobe.clear();
    await outfits.clear();
    await planner.clear();
    await feedback.clear();
    await meta.delete(seededFlag);
  }

  Future<void> close() => Hive.close();
}
