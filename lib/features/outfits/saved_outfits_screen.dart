import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_utils.dart';
import '../../core/widgets/common.dart';
import '../../models/outfit.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/providers.dart';
import '../wardrobe/widgets/item_tile.dart';
import 'outfit_builder_screen.dart';

class SavedOutfitsScreen extends ConsumerWidget {
  const SavedOutfitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Outfit>> outfitsAsync =
        ref.watch(outfitsControllerProvider);
    final List<WardrobeItem> items =
        ref.watch(wardrobeControllerProvider).valueOrNull ??
            const <WardrobeItem>[];

    final Map<String, WardrobeItem> byId = <String, WardrobeItem>{
      for (final WardrobeItem i in items) i.id: i,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Saved outfits')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const OutfitBuilderScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New outfit'),
      ),
      body: outfitsAsync.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stack) =>
            ErrorView(message: '$error'),
        data: (List<Outfit> outfits) {
          if (outfits.isEmpty) {
            return EmptyView(
              icon: Icons.bookmark_outline,
              title: 'No saved outfits',
              message: 'Build one by hand, or save a recommendation.',
              actionLabel: 'Create an outfit',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      const OutfitBuilderScreen(),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: outfits.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final Outfit outfit = outfits[index];
              return _OutfitCard(outfit: outfit, byId: byId);
            },
          );
        },
      ),
    );
  }
}

class _OutfitCard extends ConsumerWidget {
  const _OutfitCard({required this.outfit, required this.byId});

  final Outfit outfit;
  final Map<String, WardrobeItem> byId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    final List<WardrobeItem> resolved = <WardrobeItem>[];
    int missing = 0;
    for (final OutfitSlot slot in kSlotOrder) {
      final String? id = outfit.items[slot];
      if (id == null) continue;
      final WardrobeItem? item = byId[id];
      if (item == null) {
        missing++;
      } else {
        resolved.add(item);
      }
    }

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              OutfitBuilderScreen(editing: outfit),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      outfit.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        if (outfit.occasion != null) outfit.occasion!,
                        '${resolved.length} pieces',
                        if (outfit.timesWorn > 0)
                          'worn ${outfit.timesWorn}x',
                      ].join(' - '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: outfit.favorite ? 'Unfavorite' : 'Favorite',
                onPressed: () => ref
                    .read(outfitsControllerProvider.notifier)
                    .toggleFavorite(outfit),
                icon: Icon(
                  outfit.favorite ? Icons.favorite : Icons.favorite_border,
                  color: outfit.favorite ? theme.colorScheme.error : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: resolved.isEmpty
                ? Text(
                    'All items in this outfit were deleted.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: resolved.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) => SizedBox(
                      width: 64,
                      child: ItemThumb(
                        item: resolved[index],
                        borderRadius: 10,
                        iconSize: 22,
                      ),
                    ),
                  ),
          ),

          if (missing > 0) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '$missing item${missing == 1 ? '' : 's'} no longer in your '
              'wardrobe',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                'Last worn ${Dates.relative(outfit.lastWorn).toLowerCase()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _confirmDelete(context, ref),
                child: const Text('Delete'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(outfitsControllerProvider.notifier)
                      .wearNow(outfit);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logged as worn today.')),
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(96, 40),
                ),
                child: const Text('Wear'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete this outfit?'),
        content: Text(
          '"${outfit.name}" will be removed. The individual items stay in '
          'your wardrobe.',
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
    await ref.read(outfitsControllerProvider.notifier).delete(outfit.id);
  }
}
