import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../models/user.dart';
import '../../models/user_profile.dart';
import '../../providers/providers.dart';

/// Decides where a launch should land.
///
/// This replaces a GoRouter `redirect`: it can read providers directly, so
/// the auth and profile state does not need bridging into a
/// `refreshListenable`. Navigation happens in a post-frame callback because
/// `context.go` during build is not allowed.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  void _routeOnce(AppUser? user, UserProfile? profile) {
    if (_navigated) return;
    _navigated = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (user == null) {
        context.go(Routes.signup);
      } else if (profile == null || !profile.onboardingComplete) {
        context.go(Routes.onboarding);
      } else {
        context.go(Routes.home);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppUser?> auth = ref.watch(authControllerProvider);
    final AsyncValue<UserProfile> profile =
        ref.watch(profileControllerProvider);

    final bool settled = !auth.isLoading && !profile.isLoading;
    if (settled) {
      // An error reading local state is not worth blocking on - send the
      // user to signup, which is recoverable.
      _routeOnce(auth.valueOrNull, profile.valueOrNull);
    }

    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(
                Icons.door_sliding_outlined,
                size: 42,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'My Closet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your wardrobe, organized',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
