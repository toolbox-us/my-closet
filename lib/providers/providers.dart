import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/local/hive_boxes.dart';
import '../data/local/hive_repositories.dart';
import '../data/local/mock_auth_repository.dart';
import '../models/feedback_entry.dart';
import '../models/outfit.dart';
import '../models/recommendation.dart';
import '../models/user.dart';
import '../models/user_profile.dart';
import '../models/wardrobe_item.dart';
import '../models/weather.dart';
import '../repositories/auth_repository.dart';
import '../repositories/outfit_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/recommendation_repository.dart';
import '../repositories/wardrobe_repository.dart';
import '../services/ai_service.dart';
import '../services/gemini_ai_service.dart';
import '../services/recommendation_service.dart';
import '../services/weather_service.dart';

// =============================================================================
// Infrastructure
// =============================================================================

/// Overridden in `main()` with the opened boxes. Throwing here rather than
/// returning a dummy means a missing override fails loudly at startup instead
/// of silently writing to nowhere.
final Provider<AppBoxes> appBoxesProvider = Provider<AppBoxes>((ref) {
  throw UnimplementedError(
    'appBoxesProvider must be overridden in main() with AppBoxes.open()',
  );
});

// =============================================================================
// Repositories - the only place concrete implementations are named
// =============================================================================

final Provider<WardrobeRepository> wardrobeRepositoryProvider =
    Provider<WardrobeRepository>(
  (ref) => HiveWardrobeRepository(ref.watch(appBoxesProvider).wardrobe),
);

final Provider<OutfitRepository> outfitRepositoryProvider =
    Provider<OutfitRepository>(
  (ref) => HiveOutfitRepository(ref.watch(appBoxesProvider).outfits),
);

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>(
  (ref) => HiveProfileRepository(ref.watch(appBoxesProvider).profile),
);

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
  (ref) => MockAuthRepository(ref.watch(appBoxesProvider).auth),
);

final Provider<FeedbackRepository> feedbackRepositoryProvider =
    Provider<FeedbackRepository>(
  (ref) => HiveFeedbackRepository(ref.watch(appBoxesProvider).feedback),
);

final Provider<PlannerRepository> plannerRepositoryProvider =
    Provider<PlannerRepository>(
  (ref) => HivePlannerRepository(ref.watch(appBoxesProvider).planner),
);

// =============================================================================
// Services
// =============================================================================

/// The real Gemini service is always selected for garment analysis and outfit
/// advice. Without a configured key or when a request fails, it reports an
/// error instead of returning mock data.
final Provider<AiService> aiServiceProvider = Provider<AiService>((ref) {
  final http.Client client = http.Client();
  ref.onDispose(client.close);

  return GeminiAiService(client: client);
});

final Provider<RecommendationService> recommendationServiceProvider =
    Provider<RecommendationService>(
  (ref) => const LocalRecommendationService(),
);

final Provider<WeatherService> weatherServiceProvider =
    Provider<WeatherService>((ref) => const MockWeatherService());

// =============================================================================
// Controllers
// =============================================================================

class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() => ref.read(authRepositoryProvider).currentUser();

  Future<void> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String genderPreference,
  }) async {
    state = const AsyncValue<AppUser?>.loading();
    try {
      final AppUser user = await ref.read(authRepositoryProvider).signUp(
            name: name,
            email: email,
            phone: phone,
            password: password,
            genderPreference: genderPreference,
          );

      // Seed the profile from signup so onboarding starts pre-filled.
      final ProfileRepository profiles = ref.read(profileRepositoryProvider);
      final UserProfile existing = await profiles.get();
      await profiles.save(
        existing.copyWith(
          name: user.name,
          email: user.email,
          phone: user.phone,
          genderPreference: user.genderPreference,
        ),
      );
      ref.invalidate(profileControllerProvider);

      state = AsyncValue<AppUser?>.data(user);
    } on AuthException catch (error, stack) {
      state = AsyncValue<AppUser?>.error(error, stack);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncValue<AppUser?>.data(null);
  }
}

final AsyncNotifierProvider<AuthController, AppUser?> authControllerProvider =
    AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);

class ProfileController extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() => ref.read(profileRepositoryProvider).get();

  Future<void> save(UserProfile profile) async {
    final ProfileRepository repo = ref.read(profileRepositoryProvider);
    await repo.save(profile);
    state = AsyncValue<UserProfile>.data(await repo.get());
  }

  Future<void> completeOnboarding(UserProfile profile) =>
      save(profile.copyWith(onboardingComplete: true));
}

final AsyncNotifierProvider<ProfileController, UserProfile>
    profileControllerProvider =
    AsyncNotifierProvider<ProfileController, UserProfile>(
  ProfileController.new,
);

class WardrobeController extends AsyncNotifier<List<WardrobeItem>> {
  @override
  Future<List<WardrobeItem>> build() =>
      ref.read(wardrobeRepositoryProvider).getAll();

  Future<void> save(WardrobeItem item) async {
    final WardrobeRepository repo = ref.read(wardrobeRepositoryProvider);
    await repo.save(item);
    state = AsyncValue<List<WardrobeItem>>.data(await repo.getAll());
  }

  Future<void> delete(String id) async {
    final WardrobeRepository repo = ref.read(wardrobeRepositoryProvider);
    await repo.delete(id);
    state = AsyncValue<List<WardrobeItem>>.data(await repo.getAll());
  }

  Future<void> toggleFavorite(WardrobeItem item) =>
      save(item.copyWith(favorite: !item.favorite));

  /// Records a wear event, which feeds both Insights and the engine's
  /// wear-diversity score.
  Future<void> markWorn(String itemId) async {
    final WardrobeRepository repo = ref.read(wardrobeRepositoryProvider);
    final WardrobeItem? item = await repo.getById(itemId);
    if (item == null) return;
    await repo.save(
      item.copyWith(
        timesWorn: item.timesWorn + 1,
        lastWorn: DateTime.now(),
      ),
    );
    state = AsyncValue<List<WardrobeItem>>.data(await repo.getAll());
  }

  Future<void> reload() async {
    state = AsyncValue<List<WardrobeItem>>.data(
      await ref.read(wardrobeRepositoryProvider).getAll(),
    );
  }
}

final AsyncNotifierProvider<WardrobeController, List<WardrobeItem>>
    wardrobeControllerProvider =
    AsyncNotifierProvider<WardrobeController, List<WardrobeItem>>(
  WardrobeController.new,
);

class OutfitsController extends AsyncNotifier<List<Outfit>> {
  @override
  Future<List<Outfit>> build() => ref.read(outfitRepositoryProvider).getAll();

  Future<Outfit> save(Outfit outfit, {String? name}) async {
    final OutfitRepository repo = ref.read(outfitRepositoryProvider);
    final Outfit stored = materializeOutfit(outfit, name: name);
    await repo.save(stored);
    state = AsyncValue<List<Outfit>>.data(await repo.getAll());
    return stored;
  }

  Future<void> delete(String id) async {
    final OutfitRepository repo = ref.read(outfitRepositoryProvider);
    await repo.delete(id);
    state = AsyncValue<List<Outfit>>.data(await repo.getAll());
  }

  Future<void> toggleFavorite(Outfit outfit) async {
    final OutfitRepository repo = ref.read(outfitRepositoryProvider);
    await repo.save(outfit.copyWith(favorite: !outfit.favorite));
    state = AsyncValue<List<Outfit>>.data(await repo.getAll());
  }

  /// Marks the outfit and every item in it as worn today.
  Future<void> wearNow(Outfit outfit) async {
    final OutfitRepository repo = ref.read(outfitRepositoryProvider);
    final Outfit stored = materializeOutfit(outfit);
    await repo.save(
      stored.copyWith(
        timesWorn: stored.timesWorn + 1,
        lastWorn: DateTime.now(),
      ),
    );

    final WardrobeController wardrobe =
        ref.read(wardrobeControllerProvider.notifier);
    for (final String itemId in stored.itemIds) {
      await wardrobe.markWorn(itemId);
    }

    state = AsyncValue<List<Outfit>>.data(await repo.getAll());
  }
}

final AsyncNotifierProvider<OutfitsController, List<Outfit>>
    outfitsControllerProvider =
    AsyncNotifierProvider<OutfitsController, List<Outfit>>(
  OutfitsController.new,
);

class FeedbackController extends AsyncNotifier<List<FeedbackEntry>> {
  @override
  Future<List<FeedbackEntry>> build() =>
      ref.read(feedbackRepositoryProvider).getAll();

  Future<void> record(FeedbackEntry entry) async {
    final FeedbackRepository repo = ref.read(feedbackRepositoryProvider);
    await repo.save(entry);
    state = AsyncValue<List<FeedbackEntry>>.data(await repo.getAll());
  }
}

final AsyncNotifierProvider<FeedbackController, List<FeedbackEntry>>
    feedbackControllerProvider =
    AsyncNotifierProvider<FeedbackController, List<FeedbackEntry>>(
  FeedbackController.new,
);

/// Current weather, editable by the user.
///
/// A plain Notifier rather than an AsyncNotifier: the mock is synchronous
/// enough that a loading state would just flicker.
class WeatherController extends Notifier<Weather> {
  @override
  Weather build() => MockWeatherService.defaultScenario;

  void set(Weather weather) => state = weather;

  void applyScenario(Weather scenario) => state = scenario;

  void setTemperature(int temperatureF) => state = state.copyWith(
        temperatureF: temperatureF,
        scenarioName: 'Custom',
      );

  void setCondition(String condition) => state = state.copyWith(
        condition: condition,
        scenarioName: 'Custom',
      );

  void setWind(String wind) => state = state.copyWith(
        wind: wind,
        scenarioName: 'Custom',
      );
}

final NotifierProvider<WeatherController, Weather> weatherControllerProvider =
    NotifierProvider<WeatherController, Weather>(WeatherController.new);

// =============================================================================
// Derived values
// =============================================================================

/// Assembles a [RecommendationRequest] from current state.
///
/// Centralised so every recommendation screen scores against identical
/// inputs - otherwise "What should I wear?" and "Match this item" would
/// quietly disagree.
RecommendationRequest buildRequest({
  required List<WardrobeItem> items,
  required UserProfile profile,
  required Weather weather,
  required List<FeedbackEntry> feedback,
  required String occasion,
  required String environment,
  String? style,
  Set<String> excludeItemIds = const <String>{},
}) {
  return RecommendationRequest(
    items: items,
    profile: profile,
    occasion: occasion,
    environment: environment,
    weather: weather,
    style: style,
    feedback: feedback,
    excludeItemIds: excludeItemIds,
  );
}
