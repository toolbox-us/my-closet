import 'package:flutter/material.dart';

import '../../../core/widgets/common.dart';
import '../../../models/feedback_entry.dart';
import '../../../models/outfit.dart';
import '../../../models/recommendation.dart';
import '../../../models/wardrobe_item.dart';
import '../../wardrobe/widgets/item_tile.dart';

/// A scored outfit with its explanation.
///
/// Every line under "Why this works" comes from a scoring dimension that
/// actually fired - see `LocalRecommendationService`. Nothing here is model
/// narration, which is why the breakdown sheet can show the exact points
/// behind each claim.
class ScoredOutfitCard extends StatelessWidget {
  const ScoredOutfitCard({
    super.key,
    required this.scored,
    this.title,
    this.anchorItemId,
    this.onReplaceSlot,
    this.onWear,
    this.onSave,
    this.onAnother,
    this.onLike,
    this.onDislike,
  });

  final ScoredOutfit scored;
  final String? title;

  /// Highlighted and never given a Replace button - the item the outfit is
  /// built around must stay put.
  final String? anchorItemId;

  final void Function(OutfitSlot slot)? onReplaceSlot;
  final VoidCallback? onWear;
  final VoidCallback? onSave;
  final VoidCallback? onAnother;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  title ?? 'Recommended outfit',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _ScoreBadge(score: scored.score),
            ],
          ),
          const SizedBox(height: 16),

          ..._slotRows(context),

          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Icon(
                Icons.checklist_rtl,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Why this works',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showBreakdown(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Score detail'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...scored.reasons.map(
            (String reason) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.check, size: 15, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(reason, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),

          if (onWear != null || onSave != null || onAnother != null) ...<Widget>[
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                if (onWear != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: onWear,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: const Text('Wear This'),
                    ),
                  ),
                if (onWear != null && onSave != null)
                  const SizedBox(width: 10),
                if (onSave != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSave,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
              ],
            ),
            if (onAnother != null) ...<Widget>[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onAnother,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Another'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ],
          ],

          if (onLike != null || onDislike != null) ...<Widget>[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Text(
                  'Was this a good suggestion?',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Good suggestion',
                  onPressed: onLike,
                  icon: const Icon(Icons.thumb_up_outlined),
                ),
                IconButton(
                  tooltip: 'Not for me',
                  onPressed: onDislike,
                  icon: const Icon(Icons.thumb_down_outlined),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _slotRows(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> rows = <Widget>[];

    for (final OutfitSlot slot in kSlotOrder) {
      final String? itemId = scored.outfit.items[slot];
      if (itemId == null) continue;

      WardrobeItem? item;
      for (final WardrobeItem candidate in scored.items) {
        if (candidate.id == itemId) {
          item = candidate;
          break;
        }
      }
      if (item == null) continue;

      final bool isAnchor = anchorItemId != null && itemId == anchorItemId;

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ItemRowTile(
            item: item,
            slotLabel: kSlotLabel[slot],
            trailing: isAnchor
                ? Pill(label: 'Anchor', icon: Icons.push_pin_outlined)
                : (onReplaceSlot == null
                    ? null
                    : TextButton(
                        onPressed: () => onReplaceSlot!(slot),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Replace'),
                      )),
          ),
        ),
      );
    }

    if (rows.isEmpty) {
      rows.add(
        Text(
          'No items could be matched.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return rows;
  }

  void _showBreakdown(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: <Widget>[
              SectionHeader(
                title: 'Score breakdown',
                subtitle: '${scored.score} of 100 points',
              ),
              ...ScoreKeys.all.map((String key) {
                final int? points = scored.breakdown[key];
                if (points == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          ScoreKeys.labels[key] ?? key,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        points >= 0 ? '+$points' : '$points',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: points >= 0
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 24),
              Text(
                'These points come from deterministic rules, not a language '
                'model. Every line above is reproducible for the same '
                'wardrobe, weather and occasion.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color background;
    if (score >= 80) {
      background = theme.colorScheme.primaryContainer;
    } else if (score >= 60) {
      background = theme.colorScheme.secondaryContainer;
    } else {
      background = theme.colorScheme.surfaceContainerHighest;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$score% match',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Asks why an outfit was rejected.
///
/// The reasons are a fixed list rather than free text so the engine can
/// actually act on them.
class DislikeReasonSheet extends StatelessWidget {
  const DislikeReasonSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => const DislikeReasonSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: <Widget>[
          const SectionHeader(
            title: 'What was wrong?',
            subtitle: 'This nudges future suggestions.',
          ),
          ...DislikeReasons.all.map(
            (String reason) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(reason),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(reason),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop('Unspecified'),
            child: const Text('Just not for me'),
          ),
        ],
      ),
    );
  }
}
