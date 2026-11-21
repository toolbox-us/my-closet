import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_utils.dart';
import '../../core/widgets/common.dart';
import '../../models/outfit.dart';
import '../../models/planner_entry.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/providers.dart';
import '../wardrobe/widgets/item_tile.dart';

/// Weekly outfit planner.
///
/// One saved outfit per day, keyed by `yyyy-MM-dd`. Stored in Hive like
/// everything else, so a plan survives a restart.
class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = Dates.startOfWeek(DateTime.now());
  }

  void _shiftWeek(int weeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * weeks));
    });
  }

  Future<void> _assign(DateTime day, List<Outfit> outfits) async {
    if (outfits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save an outfit first, then plan it in.'),
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
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (BuildContext context, ScrollController controller) =>
            ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: <Widget>[
            SectionHeader(
              title: 'Plan for ${Dates.medium(day)}',
              subtitle: 'Pick a saved outfit.',
            ),
            ...outfits.map(
              (Outfit outfit) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  outfit.favorite ? Icons.favorite : Icons.bookmark_outline,
                ),
                title: Text(outfit.name),
                subtitle: Text(
                  <String>[
                    if (outfit.occasion != null) outfit.occasion!,
                    '${outfit.items.length} pieces',
                  ].join(' - '),
                ),
                onTap: () => Navigator.of(context).pop(outfit.id),
              ),
            ),
          ],
        ),
      ),
    );

    if (chosen == null) return;

    await ref.read(plannerRepositoryProvider).save(
          PlannerEntry(dateKey: Dates.key(day), outfitId: chosen),
        );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _clear(DateTime day) async {
    await ref.read(plannerRepositoryProvider).delete(Dates.key(day));
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Outfit> outfits =
        ref.watch(outfitsControllerProvider).valueOrNull ?? const <Outfit>[];
    final List<WardrobeItem> items =
        ref.watch(wardrobeControllerProvider).valueOrNull ??
            const <WardrobeItem>[];

    final Map<String, Outfit> outfitsById = <String, Outfit>{
      for (final Outfit o in outfits) o.id: o,
    };
    final Map<String, WardrobeItem> itemsById = <String, WardrobeItem>{
      for (final WardrobeItem i in items) i.id: i,
    };

    final DateTime weekEnd = _weekStart.add(const Duration(days: 6));
    final String todayKey = Dates.key(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planner'),
        actions: <Widget>[
          IconButton(
            tooltip: 'This week',
            onPressed: () => setState(
              () => _weekStart = Dates.startOfWeek(DateTime.now()),
            ),
            icon: const Icon(Icons.today_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<List<PlannerEntry>>(
        // Read straight from the repository: the planner is the only screen
        // that needs this data, so it does not justify a controller of its
        // own yet.
        future: ref.read(plannerRepositoryProvider).getAll(),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<PlannerEntry>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }

          final Map<String, String> planned = <String, String>{
            for (final PlannerEntry e in snapshot.data ?? <PlannerEntry>[])
              e.dateKey: e.outfitId,
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Previous week',
                    onPressed: () => _shiftWeek(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${Dates.short(_weekStart)} - '
                      '${Dates.short(weekEnd)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next week',
                    onPressed: () => _shiftWeek(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              for (int offset = 0; offset < 7; offset++)
                _DayRow(
                  day: _weekStart.add(Duration(days: offset)),
                  isToday:
                      Dates.key(_weekStart.add(Duration(days: offset))) ==
                          todayKey,
                  outfit: outfitsById[
                      planned[Dates.key(_weekStart.add(Duration(days: offset)))]],
                  itemsById: itemsById,
                  onAssign: () =>
                      _assign(_weekStart.add(Duration(days: offset)), outfits),
                  onClear: () =>
                      _clear(_weekStart.add(Duration(days: offset))),
                ),

              if (outfits.isEmpty) ...<Widget>[
                const SizedBox(height: 24),
                Text(
                  'You have no saved outfits yet. Create one from the Style '
                  'tab and it will show up here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.isToday,
    required this.outfit,
    required this.itemsById,
    required this.onAssign,
    required this.onClear,
  });

  final DateTime day;
  final bool isToday;
  final Outfit? outfit;
  final Map<String, WardrobeItem> itemsById;
  final VoidCallback onAssign;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Outfit? planned = outfit;

    final List<WardrobeItem> resolved = <WardrobeItem>[];
    if (planned != null) {
      for (final OutfitSlot slot in kSlotOrder) {
        final String? id = planned.items[slot];
        if (id == null) continue;
        final WardrobeItem? item = itemsById[id];
        if (item != null) resolved.add(item);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        color: isToday
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerLow,
        onTap: onAssign,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 46,
              child: Column(
                children: <Widget>[
                  Text(
                    Dates.weekdayShort[day.weekday - 1].toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${day.day}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: planned == null
                  ? Text(
                      'Nothing planned',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          planned.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (resolved.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 34,
                            child: Row(
                              children: resolved
                                  .take(5)
                                  .map(
                                    (WardrobeItem item) => Padding(
                                      padding:
                                          const EdgeInsets.only(right: 6),
                                      child: SizedBox(
                                        width: 34,
                                        child: ItemThumb(
                                          item: item,
                                          borderRadius: 8,
                                          iconSize: 14,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            if (planned == null)
              IconButton(
                tooltip: 'Plan an outfit',
                onPressed: onAssign,
                icon: const Icon(Icons.add),
              )
            else
              IconButton(
                tooltip: 'Clear this day',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}
