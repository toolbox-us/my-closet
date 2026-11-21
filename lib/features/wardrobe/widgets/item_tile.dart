import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/app_utils.dart';
import '../../../core/widgets/common.dart';
import '../../../models/wardrobe_item.dart';

/// An item's picture, or a colour swatch when it has none.
///
/// No bundled stock photos: a swatch in the item's own colour plus a category
/// icon reads as deliberate, stays honest about what the app knows, and keeps
/// the repository free of 30 placeholder images. Real photos appear as soon
/// as the user adds them.
class ItemThumb extends StatelessWidget {
  const ItemThumb({
    super.key,
    required this.item,
    this.borderRadius = 12,
    this.iconSize = 30,
  });

  final WardrobeItem item;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final String? path = item.imagePath;

    if (path != null && path.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          // The file can disappear - the user deletes the photo, or restores
          // the app onto a new device. Fall back rather than show a crash box.
          errorBuilder: (BuildContext context, Object error, StackTrace? s) =>
              _swatch(radius),
        ),
      );
    }

    return _swatch(radius);
  }

  Widget _swatch(BorderRadius radius) {
    final Color background = ColorSwatches.of(item.primaryColor);
    final Color foreground = ColorSwatches.onOf(item.primaryColor);

    return Container(
      decoration: BoxDecoration(color: background, borderRadius: radius),
      child: Center(
        // Opacity rather than an alpha-adjusted colour: colour channel
        // accessors were renamed in recent Flutter versions, and this works
        // on every version.
        child: Opacity(
          opacity: 0.55,
          child: Icon(
            ColorSwatches.iconFor(item.category),
            size: iconSize,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

/// Grid card for the wardrobe screen.
class WardrobeItemCard extends StatelessWidget {
  const WardrobeItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onFavoriteToggle,
  });

  final WardrobeItem item;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ItemThumb(item: item),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 20,
                      onPressed: onFavoriteToggle,
                      tooltip: item.favorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                      icon: Icon(
                        item.favorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: item.favorite
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (item.attributeSource.involvedAi)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Tooltip(
                        message: item.attributeSource.label,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: ColorSwatches.of(item.primaryColor),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${item.primaryColor} - ${item.category}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact row used in outfit builders and recommendation results.
class ItemRowTile extends StatelessWidget {
  const ItemRowTile({
    super.key,
    required this.item,
    this.slotLabel,
    this.trailing,
    this.onTap,
  });

  final WardrobeItem item;
  final String? slotLabel;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 48,
            height: 48,
            child: ItemThumb(item: item, borderRadius: 10, iconSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (slotLabel != null)
                  Text(
                    slotLabel!.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
                  ),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  <String?>[
                    item.primaryColor,
                    item.material,
                    item.brand,
                  ].whereType<String>().join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
