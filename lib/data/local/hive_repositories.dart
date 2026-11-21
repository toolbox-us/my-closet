import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';

import '../../models/feedback_entry.dart';
import '../../models/outfit.dart';
import '../../models/planner_entry.dart';
import '../../models/user_profile.dart';
import '../../models/wardrobe_item.dart';
import '../../repositories/outfit_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/recommendation_repository.dart';
import '../../repositories/wardrobe_repository.dart';
import 'hive_boxes.dart';

/// Shared JSON-in-a-box plumbing.
///
/// A record that fails to decode is skipped rather than thrown, so one bad
/// row written by an older build cannot brick the whole wardrobe screen.
class _JsonBox<T> {
  _JsonBox({
    required this.box,
    required this.decode,
    required this.encode,
    required this.idOf,
  });

  final Box<String> box;
  final T Function(Map<String, dynamic>) decode;
  final Map<String, dynamic> Function(T) encode;
  final String Function(T) idOf;

  List<T> readAll() {
    final List<T> out = <T>[];
    for (final String raw in box.values) {
      final T? decoded = _tryDecode(raw);
      if (decoded != null) out.add(decoded);
    }
    return out;
  }

  T? readOne(String key) {
    final String? raw = box.get(key);
    if (raw == null) return null;
    return _tryDecode(raw);
  }

  Future<void> write(T value) =>
      box.put(idOf(value), jsonEncode(encode(value)));

  Future<void> writeAll(List<T> values) => box.putAll(<String, String>{
        for (final T v in values) idOf(v): jsonEncode(encode(v)),
      });

  Future<void> remove(String key) => box.delete(key);

  Future<void> removeAll() => box.clear();

  T? _tryDecode(String raw) {
    try {
      final Object? parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return decode(parsed);
      if (parsed is Map) {
        return decode(Map<String, dynamic>.from(parsed));
      }
    } catch (_) {
      // Corrupt or outdated record - skip it.
    }
    return null;
  }
}

class HiveWardrobeRepository implements WardrobeRepository {
  HiveWardrobeRepository(Box<String> box)
      : _store = _JsonBox<WardrobeItem>(
          box: box,
          decode: WardrobeItem.fromJson,
          encode: (WardrobeItem i) => i.toJson(),
          idOf: (WardrobeItem i) => i.id,
        );

  final _JsonBox<WardrobeItem> _store;

  @override
  Future<List<WardrobeItem>> getAll() async => _store.readAll();

  @override
  Future<WardrobeItem?> getById(String id) async => _store.readOne(id);

  @override
  Future<void> save(WardrobeItem item) => _store.write(item);

  @override
  Future<void> saveAll(List<WardrobeItem> items) => _store.writeAll(items);

  @override
  Future<void> delete(String id) => _store.remove(id);

  @override
  Future<void> clear() => _store.removeAll();
}

class HiveOutfitRepository implements OutfitRepository {
  HiveOutfitRepository(Box<String> box)
      : _store = _JsonBox<Outfit>(
          box: box,
          decode: Outfit.fromJson,
          encode: (Outfit o) => o.toJson(),
          idOf: (Outfit o) => o.id,
        );

  final _JsonBox<Outfit> _store;

  @override
  Future<List<Outfit>> getAll() async {
    final List<Outfit> all = _store.readAll();
    all.sort((Outfit a, Outfit b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Future<Outfit?> getById(String id) async => _store.readOne(id);

  @override
  Future<void> save(Outfit outfit) => _store.write(outfit);

  @override
  Future<void> saveAll(List<Outfit> outfits) => _store.writeAll(outfits);

  @override
  Future<void> delete(String id) => _store.remove(id);

  @override
  Future<void> clear() => _store.removeAll();
}

class HiveProfileRepository implements ProfileRepository {
  HiveProfileRepository(this._box);

  final Box<String> _box;

  @override
  Future<UserProfile> get() async {
    final String? raw = _box.get(AppBoxes.singletonKey);
    if (raw == null) return UserProfile.empty;
    try {
      final Object? parsed = jsonDecode(raw);
      if (parsed is Map) {
        return UserProfile.fromJson(Map<String, dynamic>.from(parsed));
      }
    } catch (_) {
      // Fall through to the empty profile.
    }
    return UserProfile.empty;
  }

  @override
  Future<void> save(UserProfile profile) =>
      _box.put(AppBoxes.singletonKey, jsonEncode(profile.toJson()));

  @override
  Future<void> clear() => _box.clear();
}

class HiveFeedbackRepository implements FeedbackRepository {
  HiveFeedbackRepository(Box<String> box)
      : _store = _JsonBox<FeedbackEntry>(
          box: box,
          decode: FeedbackEntry.fromJson,
          encode: (FeedbackEntry f) => f.toJson(),
          idOf: (FeedbackEntry f) => f.id,
        );

  final _JsonBox<FeedbackEntry> _store;

  @override
  Future<List<FeedbackEntry>> getAll() async => _store.readAll();

  @override
  Future<void> save(FeedbackEntry entry) => _store.write(entry);

  @override
  Future<void> clear() => _store.removeAll();
}

class HivePlannerRepository implements PlannerRepository {
  HivePlannerRepository(Box<String> box)
      : _store = _JsonBox<PlannerEntry>(
          box: box,
          decode: PlannerEntry.fromJson,
          encode: (PlannerEntry p) => p.toJson(),
          idOf: (PlannerEntry p) => p.dateKey,
        );

  final _JsonBox<PlannerEntry> _store;

  @override
  Future<List<PlannerEntry>> getAll() async => _store.readAll();

  @override
  Future<PlannerEntry?> forDate(String dateKey) async =>
      _store.readOne(dateKey);

  @override
  Future<void> save(PlannerEntry entry) => _store.write(entry);

  @override
  Future<void> delete(String dateKey) => _store.remove(dateKey);

  @override
  Future<void> clear() => _store.removeAll();
}
