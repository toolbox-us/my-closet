import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/signup_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/outfits/outfit_builder_screen.dart';
import '../features/outfits/saved_outfits_screen.dart';
import '../features/planner/planner_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/recommendations/match_item_screen.dart';
import '../features/recommendations/style_screen.dart';
import '../features/recommendations/what_to_wear_screen.dart';
import '../features/wardrobe/add_item_screen.dart';
import '../features/wardrobe/item_detail_screen.dart';
import '../features/wardrobe/wardrobe_screen.dart';
import 'shell.dart';

/// Route paths, in one place so no screen hard-codes a string.
class Routes {
  Routes._();

  static const String splash = '/';
  static const String signup = '/signup';
  static const String onboarding = '/onboarding';

  // Shell branches
  static const String home = '/home';
  static const String wardrobe = '/wardrobe';
  static const String style = '/style';
  static const String planner = '/planner';
  static const String profile = '/profile';

  // Full-screen routes.
  //
  // Given distinct prefixes rather than nesting under a branch path, so
  // there is never any ambiguity between `/wardrobe` the tab and
  // `/wardrobe/add` the pushed screen.
  static const String addItem = '/add-item';
  static const String editItem = '/edit-item';
  static const String itemDetail = '/item';
  static const String whatToWear = '/what-to-wear';
  static const String matchItem = '/match';
  static const String buildAround = '/build';
  static const String newOutfit = '/new-outfit';
  static const String savedOutfits = '/saved-outfits';
  static const String editProfile = '/edit-profile';

  static String itemDetailFor(String id) => '$itemDetail/$id';

  static String editItemFor(String id) => '$editItem/$id';

  static String matchItemFor(String id) => '$matchItem/$id';

  static String buildAroundFor(String id) => '$buildAround/$id';
}

/// The app router.
///
/// Deliberately has no `redirect`: the startup decision (signup vs
/// onboarding vs home) is made by [SplashScreen], which can read providers
/// directly. A redirect would need a `refreshListenable` bridged out of
/// Riverpod for no real benefit at this size.
final GoRouter appRouter = GoRouter(
  initialLocation: Routes.splash,
  routes: <RouteBase>[
    GoRoute(
      path: Routes.splash,
      builder: (BuildContext context, GoRouterState state) =>
          const SplashScreen(),
    ),
    GoRoute(
      path: Routes.signup,
      builder: (BuildContext context, GoRouterState state) =>
          const SignupScreen(),
    ),
    GoRoute(
      path: Routes.onboarding,
      builder: (BuildContext context, GoRouterState state) =>
          const OnboardingScreen(),
    ),

    // Five-tab shell. An IndexedStack shell keeps each tab's scroll position
    // and form state when switching tabs.
    StatefulShellRoute.indexedStack(
      builder: (
        BuildContext context,
        GoRouterState state,
        StatefulNavigationShell navigationShell,
      ) =>
          AppShell(navigationShell: navigationShell),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.home,
              builder: (BuildContext context, GoRouterState state) =>
                  const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.wardrobe,
              builder: (BuildContext context, GoRouterState state) =>
                  const WardrobeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.style,
              builder: (BuildContext context, GoRouterState state) =>
                  const StyleScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.planner,
              builder: (BuildContext context, GoRouterState state) =>
                  const PlannerScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.profile,
              builder: (BuildContext context, GoRouterState state) =>
                  const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    GoRoute(
      path: Routes.addItem,
      builder: (BuildContext context, GoRouterState state) =>
          const AddItemScreen(),
    ),
    GoRoute(
      path: '${Routes.editItem}/:id',
      builder: (BuildContext context, GoRouterState state) =>
          AddItemScreen(itemId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '${Routes.itemDetail}/:id',
      builder: (BuildContext context, GoRouterState state) =>
          ItemDetailScreen(itemId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: Routes.whatToWear,
      builder: (BuildContext context, GoRouterState state) =>
          const WhatToWearScreen(),
    ),
    GoRoute(
      path: '${Routes.matchItem}/:id',
      builder: (BuildContext context, GoRouterState state) => MatchItemScreen(
        itemId: state.pathParameters['id'] ?? '',
        mode: MatchMode.matches,
      ),
    ),
    GoRoute(
      path: '${Routes.buildAround}/:id',
      builder: (BuildContext context, GoRouterState state) => MatchItemScreen(
        itemId: state.pathParameters['id'] ?? '',
        mode: MatchMode.buildAround,
      ),
    ),
    GoRoute(
      path: Routes.newOutfit,
      builder: (BuildContext context, GoRouterState state) =>
          const OutfitBuilderScreen(),
    ),
    GoRoute(
      path: Routes.savedOutfits,
      builder: (BuildContext context, GoRouterState state) =>
          const SavedOutfitsScreen(),
    ),
    GoRoute(
      path: Routes.editProfile,
      builder: (BuildContext context, GoRouterState state) =>
          const EditProfileScreen(),
    ),
  ],
);
