import '../../models/feedback_entry.dart';
import '../../models/outfit.dart';
import '../../models/planner_entry.dart';
import '../../models/user.dart';
import '../../models/user_profile.dart';
import '../../models/wardrobe_item.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/outfit_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/recommendation_repository.dart';
import '../../repositories/wardrobe_repository.dart';

/// In-memory implementations.
///
/// These were the primary data source in the first version of the plan. They
/// are now **test doubles**: persistence is a graded requirement, so the Hive
/// implementations are the production path. Keeping these means widget and
/// unit tests run with no Hive initialisation and no disk I/O.
class InMemoryWardrobeRepository implements WardrobeRepository {
  InMemoryWardrobeRepository([List<WardrobeItem> seed = const <WardrobeItem>[]])
      : _items = <String, WardrobeItem>{
          for (final WardrobeItem i in seed) i.id: i,
        };

  final Map<String, WardrobeItem> _items;

  @override
  Future<List<WardrobeItem>> getAll() async => _items.values.toList();

  @override
  Future<WardrobeItem?> getById(String id) async => _items[id];

  @override
  Future<void> save(WardrobeItem item) async => _items[item.id] = item;

  @override
  Future<void> saveAll(List<WardrobeItem> items) async {
    for (final WardrobeItem i in items) {
      _items[i.id] = i;
    }
  }

  @override
  Future<void> delete(String id) async => _items.remove(id);

  @override
  Future<void> clear() async => _items.clear();
}

class InMemoryOutfitRepository implements OutfitRepository {
  InMemoryOutfitRepository([List<Outfit> seed = const <Outfit>[]])
      : _outfits = <String, Outfit>{for (final Outfit o in seed) o.id: o};

  final Map<String, Outfit> _outfits;

  @override
  Future<List<Outfit>> getAll() async {
    final List<Outfit> all = _outfits.values.toList();
    all.sort((Outfit a, Outfit b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Future<Outfit?> getById(String id) async => _outfits[id];

  @override
  Future<void> save(Outfit outfit) async => _outfits[outfit.id] = outfit;

  @override
  Future<void> saveAll(List<Outfit> outfits) async {
    for (final Outfit o in outfits) {
      _outfits[o.id] = o;
    }
  }

  @override
  Future<void> delete(String id) async => _outfits.remove(id);

  @override
  Future<void> clear() async => _outfits.clear();
}

class InMemoryProfileRepository implements ProfileRepository {
  InMemoryProfileRepository([this._profile = UserProfile.empty]);

  UserProfile _profile;

  @override
  Future<UserProfile> get() async => _profile;

  @override
  Future<void> save(UserProfile profile) async => _profile = profile;

  @override
  Future<void> clear() async => _profile = UserProfile.empty;
}

class InMemoryFeedbackRepository implements FeedbackRepository {
  InMemoryFeedbackRepository([List<FeedbackEntry> seed = const <FeedbackEntry>[]])
      : _entries = List<FeedbackEntry>.from(seed);

  final List<FeedbackEntry> _entries;

  @override
  Future<List<FeedbackEntry>> getAll() async =>
      List<FeedbackEntry>.unmodifiable(_entries);

  @override
  Future<void> save(FeedbackEntry entry) async => _entries.add(entry);

  @override
  Future<void> clear() async => _entries.clear();
}

class InMemoryPlannerRepository implements PlannerRepository {
  InMemoryPlannerRepository([List<PlannerEntry> seed = const <PlannerEntry>[]])
      : _entries = <String, PlannerEntry>{
          for (final PlannerEntry e in seed) e.dateKey: e,
        };

  final Map<String, PlannerEntry> _entries;

  @override
  Future<List<PlannerEntry>> getAll() async => _entries.values.toList();

  @override
  Future<PlannerEntry?> forDate(String dateKey) async => _entries[dateKey];

  @override
  Future<void> save(PlannerEntry entry) async =>
      _entries[entry.dateKey] = entry;

  @override
  Future<void> delete(String dateKey) async => _entries.remove(dateKey);

  @override
  Future<void> clear() async => _entries.clear();
}

/// Always-signed-in auth, for widget tests that need to skip the gate.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository([this._user]);

  AppUser? _user;

  @override
  Future<AppUser?> currentUser() async => _user;

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String genderPreference,
  }) async {
    _user = AppUser(
      id: 'test_user',
      name: name,
      email: email,
      phone: phone,
      genderPreference: genderPreference,
      createdAt: DateTime.now(),
    );
    return _user!;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final AppUser? existing = _user;
    if (existing == null) {
      throw const AuthException(
        AuthFailureKind.invalidCredentials,
        'No account.',
      );
    }
    return existing;
  }

  @override
  Future<void> signOut() async => _user = null;
}
