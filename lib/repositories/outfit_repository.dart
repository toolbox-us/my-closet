import '../models/outfit.dart';

abstract class OutfitRepository {
  Future<List<Outfit>> getAll();

  Future<Outfit?> getById(String id);

  Future<void> save(Outfit outfit);

  Future<void> saveAll(List<Outfit> outfits);

  Future<void> delete(String id);

  Future<void> clear();
}
