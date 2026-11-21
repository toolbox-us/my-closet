import '../models/wardrobe_item.dart';

/// The wardrobe contract the UI talks to.
///
/// Today this is implemented by `HiveWardrobeRepository` (on-device) and
/// `InMemoryWardrobeRepository` (tests). When a backend arrives, an
/// `ApiWardrobeRepository` implements the same interface and no widget
/// changes.
abstract class WardrobeRepository {
  Future<List<WardrobeItem>> getAll();

  Future<WardrobeItem?> getById(String id);

  Future<void> save(WardrobeItem item);

  Future<void> saveAll(List<WardrobeItem> items);

  Future<void> delete(String id);

  Future<void> clear();
}
