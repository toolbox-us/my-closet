import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/common.dart';
import '../../models/outfit.dart';
import '../../models/user_profile.dart';
import '../../models/wardrobe_item.dart';
import '../../models/weather.dart';
import '../../providers/providers.dart';
import '../wardrobe/widgets/item_tile.dart';

/// Home.
///
/// Doubles as the lightweight wardrobe-insights surface: composition and
/// wear statistics are computed from local data, so no analytics service is
/// involved.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final UserProfile profile =
        ref.watch(profileControllerProvider).valueOrNull ?? UserProfile.empty;
    final List<WardrobeItem> items =
        ref.watch(wardrobeControllerProvider).valueOrNull ??
            const <WardrobeItem>[];
    final List<Outfit> outfits =
        ref.watch(outfitsControllerProvider).valueOrNull ?? const <Outfit>[];
    final Weather weather = ref.watch(weatherControllerProvider);

    final String firstName =
        profile.name.isEmpty ? 'there' : profile.name.split(' ').first;

    final List<WardrobeItem> mostWorn = List<WardrobeItem>.from(items)
      ..sort((WardrobeItem a, WardrobeItem b) =>
          b.timesWorn.compareTo(a.timesWorn));
    final List<WardrobeItem> neglected = items
        .where((WardrobeItem i) => i.timesWorn == 0)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, $firstName'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add item',
            onPressed: () => context.push(Routes.addItem),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          AppCard(
            color: theme.colorScheme.primaryContainer,
            onTap: () => context.push(Routes.whatToWear),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Not sure what to wear?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'It is ${weather.summary}. Pick an occasion and get a '
                  'scored outfit from what you already own.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Get a recommendation',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatCard(
                  value: '${items.length}',
                  label: 'Items',
                  icon: Icons.grid_view_outlined,
                  onTap: () => context.go(Routes.wardrobe),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: '${outfits.length}',
                  label: 'Outfits',
                  icon: Icons.bookmark_outline,
                  onTap: () => context.push(Routes.savedOutfits),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: '${neglected.length}',
                  label: 'Unworn',
                  icon: Icons.history_toggle_off,
                  onTap: () => context.go(Routes.wardrobe),
                ),
              ),
            ],
          ),

          if (items.isNotEmpty) ...<Widget>[
            const SizedBox(height: 28),
            const SectionHeader(
              title: 'Wardrobe composition',
              subtitle: 'Computed from your own items.',
            ),
            AppCard(child: _Composition(items: items)),
          ],

          if (mostWorn.isNotEmpty && mostWorn.first.timesWorn > 0) ...<Widget>[
            const SizedBox(height: 28),
            const SectionHeader(title: 'Most worn'),
            ...mostWorn.take(3).map(
                  (WardrobeItem item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ItemRowTile(
                      item: item,
                      onTap: () => context.push(Routes.itemDetailFor(item.id)),
                      trailing: Pill(
                        label: '${item.timesWorn} wears',
                        background: theme.colorScheme.surfaceContainerHighest,
                        foreground: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
          ],

          if (neglected.isNotEmpty) ...<Widget>[
            const SizedBox(height: 28),
            SectionHeader(
              title: 'Never worn',
              subtitle: '${neglected.length} items waiting for a turn.',
            ),
            ...neglected.take(3).map(
                  (WardrobeItem item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ItemRowTile(
                      item: item,
                      onTap: () =>
                          context.push(Routes.buildAroundFor(item.id)),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
          ],

          if (items.isEmpty) ...<Widget>[
            const SizedBox(height: 28),
            EmptyView(
              icon: Icons.grid_view_outlined,
              title: 'Nothing in your closet yet',
              message: 'Add a few items and the engine has something to work '
                  'with.',
              actionLabel: 'Add your first item',
              onAction: () => context.push(Routes.addItem),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Category share of the wardrobe, as simple proportional bars.
class _Composition extends StatelessWidget {
  const _Composition({required this.items});

  final List<WardrobeItem> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Map<String, int> counts = <String, int>{};
    for (final WardrobeItem item in items) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }

    final List<MapEntry<String, int>> ordered = counts.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));

    return Column(
      children: ordered.map((MapEntry<String, int> entry) {
        final double share = entry.value / items.length;
        final int percent = (share * 100).round();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    ColorSwatches.iconFor(entry.key),
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: share,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
