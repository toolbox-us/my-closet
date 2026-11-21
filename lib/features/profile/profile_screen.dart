import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/common.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/local/seed_loader.dart';
import '../../models/user.dart';
import '../../models/user_profile.dart';
import '../../providers/providers.dart';
import '../../services/ai_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<UserProfile> profileAsync =
        ref.watch(profileControllerProvider);
    final AppUser? user = ref.watch(authControllerProvider).valueOrNull;
    final AiService ai = ref.read(aiServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit profile',
            onPressed: () => context.push(Routes.editProfile),
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: profileAsync.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stack) => ErrorView(message: '$error'),
        data: (UserProfile profile) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _initials(profile.name),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        profile.name.isEmpty ? 'Unnamed' : profile.name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (profile.email.isNotEmpty)
                        Text(
                          profile.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _Section(
              title: 'Personal information',
              rows: <_Row>[
                _Row('Name', profile.name),
                _Row('Email', profile.email),
                _Row('Phone', profile.phone),
                _Row('Location', profile.location),
                _Row('Clothing preference', profile.genderPreference),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Style preferences',
              subtitle: 'These weight every recommendation.',
              rows: <_Row>[
                _Row('Preferred styles', profile.preferredStyles.join(', ')),
                _Row('Favorite colors', profile.favoriteColors.join(', ')),
                _Row('Colors to avoid', profile.avoidedColors.join(', ')),
                _Row('Preferred brands', profile.preferredBrands.join(', ')),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Lifestyle',
              rows: <_Row>[
                _Row('Activities', profile.hobbies.join(', ')),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Sizes',
              rows: profile.sizes.entries
                  .map((MapEntry<String, String> e) => _Row(e.key, e.value))
                  .toList(),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SectionHeader(
                    title: 'AI integration',
                    subtitle:
                        'Status of Gemini clothing analysis and outfit advice.',
                  ),
                  Row(
                    children: <Widget>[
                      Pill(
                        label: ai.isLive ? 'Live' : 'Not configured',
                        icon: ai.isLive ? Icons.bolt : Icons.cloud_off,
                        background: ai.isLive
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        foreground: ai.isLive
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ai.isLive
                              ? 'Model: ${ai.modelName}'
                              : 'Gemini API key is missing.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ai.isLive
                        ? 'Clothing photos are sent to Gemini for item '
                            'analysis. Outfit requests send candidate clothing '
                            'details, occasion, style preferences and weather '
                            'for Gemini to choose and explain a suggestion. '
                            'Your name, email and other account details are '
                            'not sent.'
                        : 'Pass --dart-define=GEMINI_API_KEY=... at run time '
                            'to enable real analysis. See the README.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (AppConfig.hasApiRevision) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'API revision pinned: ${AppConfig.geminiApiRevision}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SectionHeader(
                    title: 'Prototype tools',
                    subtitle: 'Useful during a demo.',
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('Reset demo data'),
                    subtitle: const Text(
                      'Restore the sample wardrobe and clear your changes',
                    ),
                    onTap: () => _resetDemoData(context, ref),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    subtitle: Text(
                      user == null
                          ? 'Not signed in'
                          : 'Signed in as ${user.email}',
                    ),
                    onTap: () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                      if (!context.mounted) return;
                      context.go(Routes.signup);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'My Closet prototype. All data is stored on this device; there '
              'is no server.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _resetDemoData(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Reset demo data?'),
        content: const Text(
          'Your wardrobe, outfits, planner and feedback will be replaced with '
          'the bundled sample data. Your account and profile are kept.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final AppBoxes boxes = ref.read(appBoxesProvider);
    await boxes.resetDemoData();

    final SeedLoader seeder = SeedLoader(
      boxes: boxes,
      wardrobe: ref.read(wardrobeRepositoryProvider),
      outfits: ref.read(outfitRepositoryProvider),
      profile: ref.read(profileRepositoryProvider),
      planner: ref.read(plannerRepositoryProvider),
    );
    await seeder.seed();

    ref.invalidate(wardrobeControllerProvider);
    ref.invalidate(outfitsControllerProvider);
    ref.invalidate(feedbackControllerProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo data restored.')),
    );
  }
}

class _Row {
  const _Row(this.label, this.value);

  final String label;
  final String value;
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.rows,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_Row> filled =
        rows.where((_Row r) => r.value.trim().isNotEmpty).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(title: title, subtitle: subtitle),
          if (filled.isEmpty)
            Text(
              'Not set yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...filled.map(
              (_Row row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 132,
                      child: Text(
                        row.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
