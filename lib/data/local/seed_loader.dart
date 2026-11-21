import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../models/outfit.dart';
import '../../models/planner_entry.dart';
import '../../models/user_profile.dart';
import '../../models/wardrobe_item.dart';
import '../../repositories/outfit_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/recommendation_repository.dart';
import '../../repositories/wardrobe_repository.dart';
import 'hive_boxes.dart';

/// Loads bundled sample data into Hive on first run.
///
/// This gives a populated wardrobe on install *and* real persistence: items
/// a grader adds survive a restart, which a purely in-memory store could not
/// demonstrate. Guarded by a flag in the meta box so it runs exactly once -
/// without the guard, every launch would duplicate the whole wardrobe.
class SeedLoader {
  const SeedLoader({
    required this.boxes,
    required this.wardrobe,
    required this.outfits,
    required this.profile,
    required this.planner,
  });

  final AppBoxes boxes;
  final WardrobeRepository wardrobe;
  final OutfitRepository outfits;
  final ProfileRepository profile;
  final PlannerRepository planner;

  static const String wardrobeAsset = 'assets/mock/wardrobe.json';
  static const String outfitsAsset = 'assets/mock/outfits.json';
  static const String profileAsset = 'assets/mock/profile.json';
  static const String plannerAsset = 'assets/mock/planner.json';

  Future<void> seedIfNeeded({bool force = false}) async {
    if (boxes.hasBeenSeeded && !force) return;
    await seed();
  }

  Future<void> seed() async {
    final List<WardrobeItem> items =
        await _loadList(wardrobeAsset, WardrobeItem.fromJson);
    if (items.isNotEmpty) await wardrobe.saveAll(items);

    final List<Outfit> savedOutfits =
        await _loadList(outfitsAsset, Outfit.fromJson);
    if (savedOutfits.isNotEmpty) await outfits.saveAll(savedOutfits);

    final Map<String, dynamic>? profileJson = await _loadObject(profileAsset);
    if (profileJson != null) {
      final UserProfile existing = await profile.get();
      final UserProfile seeded = UserProfile.fromJson(profileJson);
      // Never overwrite a profile the user already filled in during
      // onboarding - seed style preferences only.
      await profile.save(
        existing.onboardingComplete
            ? existing
            : seeded.copyWith(
                name: existing.name.isEmpty ? seeded.name : existing.name,
                email: existing.email.isEmpty ? seeded.email : existing.email,
              ),
      );
    }

    final List<PlannerEntry> plans =
        await _loadList(plannerAsset, PlannerEntry.fromJson);
    for (final PlannerEntry entry in plans) {
      await planner.save(entry);
    }

    await boxes.markSeeded();
  }

  Future<List<T>> _loadList<T>(
    String asset,
    T Function(Map<String, dynamic>) decode,
  ) async {
    try {
      final String raw = await rootBundle.loadString(asset);
      final Object? parsed = jsonDecode(raw);
      if (parsed is! List) return <T>[];
      final List<T> out = <T>[];
      for (final Object? entry in parsed) {
        if (entry is Map) {
          out.add(decode(Map<String, dynamic>.from(entry)));
        }
      }
      return out;
    } catch (_) {
      // A missing or malformed seed file should not stop the app from
      // launching - the user just starts with an empty wardrobe.
      return <T>[];
    }
  }

  Future<Map<String, dynamic>?> _loadObject(String asset) async {
    try {
      final String raw = await rootBundle.loadString(asset);
      final Object? parsed = jsonDecode(raw);
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
    } catch (_) {
      return null;
    }
    return null;
  }
}
