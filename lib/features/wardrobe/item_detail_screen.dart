import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/common.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/providers.dart';
import 'widgets/item_tile.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<WardrobeItem> items =
        ref.watch(wardrobeControllerProvider).valueOrNull ??
            const <WardrobeItem>[];

    WardrobeItem? item;
    for (final WardrobeItem candidate in items) {
      if (candidate.id == itemId) {
        item = candidate;
        break;
      }
    }

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item')),
        body: const EmptyView(
          icon: Icons.help_outline,
          title: 'Item not found',
          message: 'It may have been deleted.',
        ),
      );
    }

    final WardrobeItem resolved = item;

    return Scaffold(
      appBar: AppBar(
        title: Text(resolved.name, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            tooltip: resolved.favorite ? 'Unfavorite' : 'Favorite',
            onPressed: () => ref
                .read(wardrobeControllerProvider.notifier)
                .toggleFavorite(resolved),
            icon: Icon(
              resolved.favorite ? Icons.favorite : Icons.favorite_border,
              color: resolved.favorite ? theme.colorScheme.error : null,
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => context.push(Routes.editItemFor(resolved.id)),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref, resolved),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ItemThumb(item: resolved, borderRadius: 18, iconSize: 64),
          ),
          const SizedBox(height: 20),

          Text(
            resolved.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Pill(label: resolved.category),
              if (resolved.subcategory != null)
                Pill(
                  label: resolved.subcategory!,
                  background: theme.colorScheme.surfaceContainerHighest,
                  foreground: theme.colorScheme.onSurfaceVariant,
                ),
              if (resolved.brand != null)
                Pill(
                  label: resolved.brand!,
                  background: theme.colorScheme.surfaceContainerHighest,
                  foreground: theme.colorScheme.onSurfaceVariant,
                ),
              if (resolved.attributeSource.involvedAi)
                Pill(
                  label: resolved.attributeSource.label,
                  icon: Icons.auto_awesome,
                ),
            ],
          ),

          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push(Routes.matchItemFor(resolved.id)),
                  icon: const Icon(Icons.join_inner_outlined, size: 18),
                  label: const Text('Find Matches'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push(Routes.buildAroundFor(resolved.id)),
                  icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                  label: const Text('Build Outfit'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeader(title: 'Details'),
                _Row(
                  label: 'Colors',
                  value: resolved.allColors.join(', '),
                  swatch: resolved.primaryColor,
                ),
                _Row(label: 'Material', value: resolved.material),
                _Row(label: 'Pattern', value: resolved.pattern),
                _Row(label: 'Size', value: resolved.size),
                _Row(label: 'Fit', value: resolved.fit),
                _Row(
                  label: 'Seasons',
                  value: resolved.seasons.isEmpty
                      ? null
                      : resolved.seasons.join(', '),
                ),
                _Row(
                  label: 'Occasions',
                  value: resolved.occasions.isEmpty
                      ? null
                      : resolved.occasions.join(', '),
                ),
                _Row(
                  label: 'Styles',
                  value: resolved.styles.isEmpty
                      ? null
                      : resolved.styles.join(', '),
                ),
                _Row(
                  label: 'Suitable for',
                  value: <String>[
                    if (resolved.indoor) 'Indoor',
                    if (resolved.outdoor) 'Outdoor',
                  ].join(' / '),
                ),
                _Row(
                  label: 'Price',
                  value: resolved.purchasePrice == null
                      ? null
                      : '\$${resolved.purchasePrice!.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeader(title: 'Wear history'),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Stat(
                        label: 'Times worn',
                        value: '${resolved.timesWorn}',
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'Last worn',
                        value: Dates.relative(resolved.lastWorn),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(wardrobeControllerProvider.notifier)
                        .markWorn(resolved.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged as worn today.')),
                    );
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('I wore this today'),
                ),
              ],
            ),
          ),

          if (resolved.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SectionHeader(title: 'Tags'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: resolved.tags
                        .map(
                          (String tag) => Pill(
                            label: tag,
                            background:
                                theme.colorScheme.surfaceContainerHighest,
                            foreground: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],

          if (resolved.notes != null) ...<Widget>[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SectionHeader(title: 'Notes'),
                  Text(resolved.notes!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WardrobeItem item,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete this item?'),
        content: Text(
          '"${item.name}" will be removed from your wardrobe. Saved outfits '
          'that used it will show it as missing.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(wardrobeControllerProvider.notifier).delete(item.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.value, this.swatch});

  final String label;
  final String? value;
  final String? swatch;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (swatch != null) ...<Widget>[
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 3, right: 8),
              decoration: BoxDecoration(
                color: ColorSwatches.of(swatch),
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
            ),
          ],
          Expanded(
            child: Text(
              value!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
