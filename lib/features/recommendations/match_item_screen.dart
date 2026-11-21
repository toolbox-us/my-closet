import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../../models/feedback_entry.dart';
import '../../models/outfit.dart';
import '../../models/recommendation.dart';
import '../../models/user_profile.dart';
import '../../models/wardrobe_item.dart';
import '../../models/weather.dart';
import '../../providers/providers.dart';
import '../../services/recommendation_service.dart';
import '../wardrobe/widgets/item_tile.dart';
import 'widgets/outfit_result_view.dart';

enum MatchMode {
  /// Several complete outfits, all containing the anchor.
  matches,

  /// One outfit, with per-slot Replace.
  buildAround,
}

/// "Match This Item" and "Build Around This".
///
/// Both hold the selected item fixed; they differ only in how many results
/// they show and whether individual slots can be re-solved. The engine
/// guarantees the anchor survives - see `matchItem`, which filters results
/// that somehow lost it.
class MatchItemScreen extends ConsumerStatefulWidget {
  const MatchItemScreen({
    super.key,
    required this.itemId,
    required this.mode,
  });

  final String itemId;
  final MatchMode mode;

  @override
  ConsumerState<MatchItemScreen> createState() => _MatchItemScreenState();
}

class _MatchItemScreenState extends ConsumerState<MatchItemScreen> {
  String _occasion = 'Casual';
  String _environment = 'Mixed';

  List<ScoredOutfit> _matches = <ScoredOutfit>[];
  ScoredOutfit? _built;
  bool _solved = false;

  /// Items already shown per slot, so tapping Replace repeatedly cycles
  /// through alternatives rather than offering the same second-best twice.
  final Map<OutfitSlot, Set<String>> _seen = <OutfitSlot, Set<String>>{};

  RecommendationRequest _request({Set<String> exclude = const <String>{}}) {
    return buildRequest(
      items: ref.read(wardrobeControllerProvider).valueOrNull ??
          const <WardrobeItem>[],
      profile:
          ref.read(profileControllerProvider).valueOrNull ?? UserProfile.empty,
      weather: ref.read(weatherControllerProvider),
      feedback: ref.read(feedbackControllerProvider).valueOrNull ??
          const <FeedbackEntry>[],
      occasion: _occasion,
      environment: _environment,
      excludeItemIds: exclude,
    );
  }

  void _solve(WardrobeItem anchor) {
    final RecommendationRequest request = _request();
    final RecommendationService service =
        ref.read(recommendationServiceProvider);

    setState(() {
      _seen.clear();
      _solved = true;
      if (widget.mode == MatchMode.matches) {
        _matches = service.matchItem(anchor, request, limit: 3);
        _built = null;
      } else {
        _built = service.buildAround(anchor, request);
        _matches = <ScoredOutfit>[];
      }
    });
  }

  void _replace(OutfitSlot slot) {
    final ScoredOutfit? current = _built;
    if (current == null) return;

    final String? currentId = current.outfit.items[slot];
    final Set<String> seen = _seen.putIfAbsent(slot, () => <String>{});
    if (currentId != null) seen.add(currentId);

    ScoredOutfit? next = ref.read(recommendationServiceProvider).replaceSlot(
          current.outfit,
          slot,
          _request(exclude: seen),
        );

    // Exhausted the alternatives - wrap around rather than dead-end.
    if (next == null) {
      seen.clear();
      if (currentId != null) seen.add(currentId);
      next = ref.read(recommendationServiceProvider).replaceSlot(
            current.outfit,
            slot,
            _request(exclude: seen),
          );
    }

    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No other ${kSlotLabel[slot]?.toLowerCase() ?? 'item'} in your '
            'wardrobe fits here yet.',
          ),
        ),
      );
      return;
    }

    setState(() => _built = next);
  }

  Future<void> _save(ScoredOutfit scored, String anchorName) async {
    await ref.read(outfitsControllerProvider.notifier).save(
          scored.outfit.copyWith(occasion: _occasion),
          name: 'Around $anchorName',
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to your outfits.')),
    );
  }

  Future<void> _wear(ScoredOutfit scored, String anchorName) async {
    await ref.read(outfitsControllerProvider.notifier).wearNow(
          scored.outfit.copyWith(
            name: 'Around $anchorName',
            occasion: _occasion,
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged. Wear counts updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Weather weather = ref.watch(weatherControllerProvider);
    final List<WardrobeItem> items =
        ref.watch(wardrobeControllerProvider).valueOrNull ??
            const <WardrobeItem>[];

    WardrobeItem? anchor;
    for (final WardrobeItem candidate in items) {
      if (candidate.id == widget.itemId) {
        anchor = candidate;
        break;
      }
    }

    final bool isBuild = widget.mode == MatchMode.buildAround;

    if (anchor == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isBuild ? 'Build around' : 'Find matches'),
        ),
        body: const EmptyView(
          icon: Icons.help_outline,
          title: 'Item not found',
          message: 'It may have been deleted.',
        ),
      );
    }

    final WardrobeItem resolvedAnchor = anchor;

    return Scaffold(
      appBar: AppBar(
        title: Text(isBuild ? 'Build around this' : 'Find matches'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: <Widget>[
          Text(
            'Keeping this item',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ItemRowTile(
            item: resolvedAnchor,
            trailing: Pill(
              label: 'Anchor',
              icon: Icons.push_pin_outlined,
            ),
          ),

          const SizedBox(height: 24),
          const SectionHeader(title: 'Occasion'),
          ChipSingleSelect(
            options: const <String>[
              'Casual',
              'Work',
              'Dinner',
              'Date',
              'Travel',
              'Party',
            ],
            selected: _occasion,
            onChanged: (String? value) {
              if (value != null) setState(() => _occasion = value);
            },
          ),

          const SizedBox(height: 20),
          const SectionHeader(title: 'Environment'),
          ChipSingleSelect(
            options: const <String>['Indoor', 'Outdoor', 'Mixed'],
            selected: _environment,
            onChanged: (String? value) {
              if (value != null) setState(() => _environment = value);
            },
          ),

          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Icon(
                Icons.cloud_outlined,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Using ${weather.summary}. Change it in '
                  'What should I wear?',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _solve(resolvedAnchor),
            icon: const Icon(Icons.auto_awesome),
            label: Text(
              _solved
                  ? 'Recalculate'
                  : (isBuild ? 'Build Outfit' : 'Find Matches'),
            ),
          ),

          if (_solved) ...<Widget>[
            const SizedBox(height: 32),
            if (isBuild)
              ..._buildAroundResults(resolvedAnchor)
            else
              ..._matchResults(resolvedAnchor),
          ],
        ],
      ),
    );
  }

  List<Widget> _matchResults(WardrobeItem anchor) {
    if (_matches.isEmpty) {
      return <Widget>[
        const EmptyView(
          icon: Icons.search_off,
          title: 'No matches yet',
          message:
              'Nothing in your wardrobe pairs with this for that occasion and '
              'weather. Try another occasion, or add more items.',
        ),
      ];
    }

    final List<Widget> widgets = <Widget>[];
    for (int i = 0; i < _matches.length; i++) {
      final ScoredOutfit match = _matches[i];
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ScoredOutfitCard(
            scored: match,
            title: 'Match ${i + 1}',
            anchorItemId: anchor.id,
            onSave: () => _save(match, anchor.name),
            onWear: () => _wear(match, anchor.name),
          ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildAroundResults(WardrobeItem anchor) {
    final ScoredOutfit? built = _built;
    if (built == null) {
      return <Widget>[
        const EmptyView(
          icon: Icons.search_off,
          title: 'Could not complete an outfit',
          message:
              'Add a few more items in other categories and try again.',
        ),
      ];
    }

    return <Widget>[
      ScoredOutfitCard(
        scored: built,
        title: 'Built around ${anchor.name}',
        anchorItemId: anchor.id,
        onReplaceSlot: _replace,
        onSave: () => _save(built, anchor.name),
        onWear: () => _wear(built, anchor.name),
      ),
      const SizedBox(height: 12),
      Text(
        'Replace swaps one slot and keeps the rest of the outfit as it is.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    ];
  }
}
