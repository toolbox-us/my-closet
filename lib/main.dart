import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/local/hive_boxes.dart';
import 'data/local/seed_loader.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open persistence before the first frame. The app is useless without it,
  // so there is no value in showing UI first and failing later.
  final AppBoxes boxes = await AppBoxes.open();

  // A container built here (rather than letting ProviderScope create one)
  // lets the seed run through the very same repository instances the UI will
  // use, instead of a throwaway set.
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appBoxesProvider.overrideWithValue(boxes),
    ],
  );

  final SeedLoader seeder = SeedLoader(
    boxes: boxes,
    wardrobe: container.read(wardrobeRepositoryProvider),
    outfits: container.read(outfitRepositoryProvider),
    profile: container.read(profileRepositoryProvider),
    planner: container.read(plannerRepositoryProvider),
  );
  await seeder.seedIfNeeded();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyClosetApp(),
    ),
  );
}
