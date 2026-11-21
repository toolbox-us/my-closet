import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/widgets/common.dart';
import '../../models/outfit.dart';
import '../../models/wardrobe_item.dart';
import '../../models/weather.dart';
import '../../providers/providers.dart';
import '../wardrobe/widgets/item_tile.dart';

/// The Style tab: entry point for every recommendation flow.
class StyleScreen extends ConsumerWidget {
  const StyleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Weather weather = ref.watch(weatherControllerProvider);
    final List<WardrobeItem> items =
        ref.watch(wardrobeControllerProvider).valueOrNull ??
            const <WardrobeItem>[];
    final List<Outfit> outfits =
        ref.watch(outfitsControllerProvider).valueOrNull ?? const <Outfit>[];

    final List<WardrobeItem> favorites =
        items.where((WardrobeItem i) => i.favorite).take(6).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Style')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          AppCard(
            color: theme.colorScheme.primaryContainer,
            child: Row(
              children: <Widget>[
                Icon(
                  weather.isRaining
                      ? Icons.umbrella_outlined
                      : (weather.temperatureF >= 78
                          ? Icons.wb_sunny_outlined
                          : Icons.cloud_outlined),
                  size: 30,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        weather.summary,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        '${weather.wind} - mock weather, editable',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Get a recommendation',
            subtitle:
                'Gemini picks from outfits scored by rules you can inspect.',
          ),
          _ActionTile(
            icon: Icons.auto_awesome,
            title: 'What should I wear?',
            subtitle: 'Pick an occasion and weather, get a full outfit',
            onTap: () => context.push(Routes.whatToWear),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.add_circle_outline,
            title: 'Create an outfit',
            subtitle: 'Build one yourself, slot by slot',
            onTap: () => context.push(Routes.newOutfit),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.bookmark_outline,
            title: 'Saved outfits',
            subtitle: outfits.isEmpty
                ? 'Nothing saved yet'
                : '${outfits.length} saved',
            onTap: () => context.push(Routes.savedOutfits),
          ),
          const SizedBox(height: 28),
          SectionHeader(
            title: 'Start from an item',
            subtitle: favorites.isEmpty
                ? 'Favorite a few items for quick access here.'
                : 'Build an outfit around something you like.',
          ),
          if (favorites.isEmpty)
            AppCard(
              onTap: () => context.go(Routes.wardrobe),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.favorite_border,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Open your wardrobe and tap the heart on items you '
                      'reach for most.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          else
            ...favorites.map(
              (WardrobeItem item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ItemRowTile(
                  item: item,
                  onTap: () => context.push(Routes.buildAroundFor(item.id)),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
