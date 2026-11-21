import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/vocab.dart';
import '../../core/widgets/common.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/providers.dart';
import 'widgets/item_tile.dart';

enum WardrobeSort { nameAsc, mostWorn, leastWorn, recentlyWorn }

extension WardrobeSortX on WardrobeSort {
  String get label {
    switch (this) {
      case WardrobeSort.nameAsc:
        return 'Name (A-Z)';
      case WardrobeSort.mostWorn:
        return 'Most worn';
      case WardrobeSort.leastWorn:
        return 'Least worn';
      case WardrobeSort.recentlyWorn:
        return 'Recently worn';
    }
  }
}

/// The wardrobe.
///
/// Filtering and sorting happen in Dart over the full item list. Hive has no
/// query API, so this is the trade-off that came with picking it - entirely
/// fine for a few dozen items, and a real limitation worth naming at scale.
class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({super.key});

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen> {
  final TextEditingController _search = TextEditingController();

  String _category = 'All';
  bool _favoritesOnly = false;
  WardrobeSort _sort = WardrobeSort.nameAsc;
  List<String> _colorFilter = <String>[];
  List<String> _occasionFilter = <String>[];
  List<String> _seasonFilter = <String>[];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _activeFilterCount =>
      _colorFilter.length +
      _occasionFilter.length +
      _seasonFilter.length +
      (_favoritesOnly ? 1 : 0);

  List<WardrobeItem> _apply(List<WardrobeItem> items) {
    final String query = _search.text.trim().toLowerCase();

    final List<WardrobeItem> filtered = items.where((WardrobeItem item) {
      if (_category != 'All' && item.category != _category) return false;
      if (_favoritesOnly && !item.favorite) return false;

      if (query.isNotEmpty && !item.searchHaystack.contains(query)) {
        return false;
      }

      if (_colorFilter.isNotEmpty &&
          !_colorFilter.contains(item.primaryColor) &&
          !(item.secondaryColor != null &&
              _colorFilter.contains(item.secondaryColor))) {
        return false;
      }

      if (_occasionFilter.isNotEmpty &&
          !item.occasions.any(_occasionFilter.contains)) {
        return false;
      }

      if (_seasonFilter.isNotEmpty &&
          !item.seasons.any(_seasonFilter.contains)) {
        return false;
      }

      return true;
    }).toList();

    switch (_sort) {
      case WardrobeSort.nameAsc:
        filtered.sort((WardrobeItem a, WardrobeItem b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case WardrobeSort.mostWorn:
        filtered.sort((WardrobeItem a, WardrobeItem b) =>
            b.timesWorn.compareTo(a.timesWorn));
        break;
      case WardrobeSort.leastWorn:
        filtered.sort((WardrobeItem a, WardrobeItem b) =>
            a.timesWorn.compareTo(b.timesWorn));
        break;
      case WardrobeSort.recentlyWorn:
        filtered.sort((WardrobeItem a, WardrobeItem b) {
          final DateTime aDate =
              a.lastWorn ?? DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime bDate =
              b.lastWorn ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        break;
    }

    return filtered;
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        // Local copies so Cancel is a real cancel.
        List<String> colors = List<String>.from(_colorFilter);
        List<String> occasions = List<String>.from(_occasionFilter);
        List<String> seasons = List<String>.from(_seasonFilter);
        bool favoritesOnly = _favoritesOnly;
        WardrobeSort sort = _sort;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              builder: (BuildContext context, ScrollController controller) {
                return ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: <Widget>[
                    const SectionHeader(
                      title: 'Filter & sort',
                      subtitle: 'Narrow down what you are looking at.',
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Favorites only'),
                      value: favoritesOnly,
                      onChanged: (bool value) =>
                          setSheetState(() => favoritesOnly = value),
                    ),
                    const SizedBox(height: 12),
                    const SectionHeader(title: 'Sort by'),
                    ChipSingleSelect(
                      options: WardrobeSort.values
                          .map((WardrobeSort s) => s.label)
                          .toList(),
                      selected: sort.label,
                      onChanged: (String? value) {
                        if (value == null) return;
                        setSheetState(() {
                          sort = WardrobeSort.values.firstWhere(
                            (WardrobeSort s) => s.label == value,
                            orElse: () => WardrobeSort.nameAsc,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Color'),
                    ChipMultiSelect(
                      options: Vocab.colors,
                      selected: colors,
                      onChanged: (List<String> next) =>
                          setSheetState(() => colors = next),
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Occasion'),
                    ChipMultiSelect(
                      options: Vocab.occasions,
                      selected: occasions,
                      onChanged: (List<String> next) =>
                          setSheetState(() => occasions = next),
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Season'),
                    ChipMultiSelect(
                      options: Vocab.seasons,
                      selected: seasons,
                      onChanged: (List<String> next) =>
                          setSheetState(() => seasons = next),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                colors = <String>[];
                                occasions = <String>[];
                                seasons = <String>[];
                                favoritesOnly = false;
                                sort = WardrobeSort.nameAsc;
                              });
                            },
                            child: const Text('Clear all'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _colorFilter = colors;
                                _occasionFilter = occasions;
                                _seasonFilter = seasons;
                                _favoritesOnly = favoritesOnly;
                                _sort = sort;
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<WardrobeItem>> itemsAsync =
        ref.watch(wardrobeControllerProvider);

    final List<String> categories = <String>['All', ...Vocab.categories];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wardrobe'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Filter and sort',
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: _activeFilterCount > 0,
              label: Text('$_activeFilterCount'),
              child: const Icon(Icons.tune),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.addItem),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search name, brand, color, tag...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final String category = categories[index];
                return ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: itemsAsync.when(
              loading: () => const LoadingView(label: 'Loading wardrobe...'),
              error: (Object error, StackTrace stack) => ErrorView(
                message: '$error',
                onRetry: () =>
                    ref.read(wardrobeControllerProvider.notifier).reload(),
              ),
              data: (List<WardrobeItem> items) {
                if (items.isEmpty) {
                  return EmptyView(
                    icon: Icons.grid_view_outlined,
                    title: 'Your wardrobe is empty',
                    message:
                        'Add your first item and My Closet can start building '
                        'outfits.',
                    actionLabel: 'Add item',
                    onAction: () => context.push(Routes.addItem),
                  );
                }

                final List<WardrobeItem> visible = _apply(items);
                if (visible.isEmpty) {
                  return EmptyView(
                    icon: Icons.search_off,
                    title: 'Nothing matches',
                    message:
                        'Try a different search, or clear your filters.',
                    actionLabel: 'Clear filters',
                    onAction: () => setState(() {
                      _search.clear();
                      _colorFilter = <String>[];
                      _occasionFilter = <String>[];
                      _seasonFilter = <String>[];
                      _favoritesOnly = false;
                      _category = 'All';
                    }),
                  );
                }

                return Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: <Widget>[
                          Text(
                            '${visible.length} of ${items.length} items',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _sort.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: visible.length,
                        itemBuilder: (BuildContext context, int index) {
                          final WardrobeItem item = visible[index];
                          return WardrobeItemCard(
                            item: item,
                            onTap: () =>
                                context.push(Routes.itemDetailFor(item.id)),
                            onFavoriteToggle: () => ref
                                .read(wardrobeControllerProvider.notifier)
                                .toggleFavorite(item),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
