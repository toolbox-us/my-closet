import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/vocab.dart';
import '../../core/widgets/common.dart';
import '../../models/feedback_entry.dart';
import '../../models/outfit.dart';
import '../../models/recommendation.dart';
import '../../models/user_profile.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/providers.dart';
import '../wardrobe/widgets/item_tile.dart';

/// Manual outfit builder.
///
/// Built before the recommendation engine on purpose: it validates the outfit
/// data model under real use, and an engine result is just a pre-filled
/// instance of this same screen. The live score is informational - a
/// hand-built outfit is never rejected for scoring badly.
class OutfitBuilderScreen extends ConsumerStatefulWidget {
  const OutfitBuilderScreen({super.key, this.editing});

  /// Pass an existing outfit to edit it rather than create a new one.
  final Outfit? editing;

  @override
  ConsumerState<OutfitBuilderScreen> createState() =>
      _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends ConsumerState<OutfitBuilderScreen> {
  final TextEditingController _name = TextEditingController();

  Map<OutfitSlot, String> _slots = <OutfitSlot, String>{};
  String? _occasion;
  bool _favorite = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Outfit? editing = widget.editing;
    if (editing != null) {
      _name.text = editing.name;
      _slots = Map<OutfitSlot, String>.from(editing.items);
      _occasion = editing.occasion;
      _favorite = editing.favorite;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickForSlot(
    OutfitSlot slot,
    List<WardrobeItem> allItems,
  ) async {
    final String category = kSlotCategory[slot]!;
    final List<WardrobeItem> options = allItems
        .where((WardrobeItem i) => i.category == category)
        .toList()
      ..sort((WardrobeItem a, WardrobeItem b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have no items in $category yet.'),
        ),
      );
      return;
    }

    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (BuildContext context, ScrollController controller) =>
            ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: <Widget>[
            SectionHeader(
              title: 'Choose a ${kSlotLabel[slot]?.toLowerCase()}',
              subtitle: '${options.length} available',
            ),
            ...options.map(
              (WardrobeItem item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ItemRowTile(
                  item: item,
                  onTap: () => Navigator.of(context).pop(item.id),
                  trailing: _slots[slot] == item.id
                      ? const Icon(Icons.check_circle)
                      : const Icon(Icons.chevron_right),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (chosen == null) return;

    setState(() {
      // withSlot enforces the dress / top+bottom exclusivity rule.
      _slots = Outfit.draft()
          .copyWith(items: _slots)
          .withSlot(slot, chosen)
          .items;
    });
  }

  void _clearSlot(OutfitSlot slot) {
    setState(() {
      final Map<OutfitSlot, String> next =
          Map<OutfitSlot, String>.from(_slots);
      next.remove(slot);
      _slots = next;
    });
  }

  Future<void> _save() async {
    if (_slots.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least two items to make an outfit.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final String name = _name.text.trim().isEmpty
        ? 'Untitled outfit'
        : _name.text.trim();

    final Outfit base = widget.editing ?? Outfit.draft();
    await ref.read(outfitsControllerProvider.notifier).save(
          base.copyWith(
            items: _slots,
            occasion: _occasion,
            favorite: _favorite,
          ),
          name: name,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Saved "$name".')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<WardrobeItem> items =
        ref.watch(wardrobeControllerProvider).valueOrNull ??
            const <WardrobeItem>[];

    final Map<String, WardrobeItem> byId = <String, WardrobeItem>{
      for (final WardrobeItem i in items) i.id: i,
    };

    // Live score, for information only.
    ScoredOutfit? preview;
    if (_slots.length >= 2) {
      final RecommendationRequest request = buildRequest(
        items: items,
        profile: ref.watch(profileControllerProvider).valueOrNull ??
            UserProfile.empty,
        weather: ref.watch(weatherControllerProvider),
        feedback: ref.watch(feedbackControllerProvider).valueOrNull ??
            const <FeedbackEntry>[],
        occasion: _occasion ?? 'Casual',
        environment: 'Mixed',
      );
      preview = ref
          .read(recommendationServiceProvider)
          .scoreOutfit(Outfit.draft().copyWith(items: _slots), request);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editing == null ? 'Create outfit' : 'Edit outfit',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: <Widget>[
          LabeledField(
            label: 'Outfit name',
            child: TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Monday Office',
              ),
            ),
          ),

          LabeledField(
            label: 'Occasion',
            optional: true,
            child: ChipSingleSelect(
              options: Vocab.occasions,
              selected: _occasion,
              allowNone: true,
              onChanged: (String? value) =>
                  setState(() => _occasion = value),
            ),
          ),

          const SizedBox(height: 8),
          const SectionHeader(
            title: 'Pieces',
            subtitle: 'Tap a slot to choose an item.',
          ),

          ...kSlotOrder.map((OutfitSlot slot) {
            final String? itemId = _slots[slot];
            final WardrobeItem? item = itemId == null ? null : byId[itemId];

            // Hide the dress slot once a top or bottom is chosen, and vice
            // versa, so the form cannot express an impossible outfit.
            final bool hasTopOrBottom = _slots.containsKey(OutfitSlot.top) ||
                _slots.containsKey(OutfitSlot.bottom);
            final bool hasDress = _slots.containsKey(OutfitSlot.dress);
            if (slot == OutfitSlot.dress && hasTopOrBottom) {
              return const SizedBox.shrink();
            }
            if ((slot == OutfitSlot.top || slot == OutfitSlot.bottom) &&
                hasDress) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: item == null
                  ? AppCard(
                      onTap: () => _pickForSlot(slot, items),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color:
                                  theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.add,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Add ${kSlotLabel[slot]?.toLowerCase()}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ItemRowTile(
                      item: item,
                      slotLabel: kSlotLabel[slot],
                      onTap: () => _pickForSlot(slot, items),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: 'Replace',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _pickForSlot(slot, items),
                            icon: const Icon(Icons.swap_horiz, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _clearSlot(slot),
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ],
                      ),
                    ),
            );
          }),

          if (preview != null) ...<Widget>[
            const SizedBox(height: 16),
            AppCard(
              color: theme.colorScheme.secondaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.insights_outlined,
                        size: 18,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Engine score: ${preview.score}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...preview.reasons.take(3).map(
                        (String reason) => Text(
                          '- $reason',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                  const SizedBox(height: 6),
                  Text(
                    'Informational only - your outfit saves either way.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mark as favorite'),
            value: _favorite,
            onChanged: (bool value) => setState(() => _favorite = value),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save Outfit'),
          ),
        ),
      ),
    );
  }
}
