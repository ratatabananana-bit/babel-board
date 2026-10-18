import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../modules/loaded_module.dart';
import '../modules/module_state.dart';
import 'icons.dart';
import 'item_picture.dart';
import 'item_sheet.dart';

/// Grid tile: picture and an optional two-line name below. A tracked item keeps its text
/// clear: a 2 dp outline in the zone's color just outside the picture, and a small chip
/// with the zone's icon on the picture's top-right corner.
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.collection,
    required this.collectionId,
    this.showName = true,
  });

  final Item item;
  final CollectionSpec collection;
  final String collectionId;
  final bool showName;

  /// Height of the name block under the picture (two lines), including the gap.
  static const nameHeight = 6.0 + nameLines * nameSize * nameLineHeight;
  static const nameLines = 2;
  static const nameSize = 12.0;
  static const nameLineHeight = 1.2;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final module = context.read<LoadedModule>();
    final zoneId = context.select<ZoneState, String?>((z) => z.zoneOf(item.id));
    final zone = zoneSpec(module, zoneId);
    final zc = zone == null ? null : zoneColor(context, zone);
    final title = item.title(collection);
    return Semantics(
      button: true,
      label: zone == null ? title : '$title, in ${zone.label}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => showItemSheet(context, item, collectionId),
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ItemPicture(item, collection),
                if (zone != null && zc != null) ...[
                  // Outline: 2 dp line, 2 dp outside the picture.
                  Positioned(
                    left: -4,
                    top: -4,
                    right: -4,
                    bottom: -4,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: zc, width: 2),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: ZoneChip(key: Key('chip-${item.id}'), zone: zone, color: zc),
                  ),
                ],
              ],
            ),
            if (showName) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: nameLines * nameSize * nameLineHeight,
                child: Text(
                  title,
                  maxLines: nameLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: nameSize,
                    height: nameLineHeight,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Zone marker on a tracked picture: a 20 dp disc in the zone's color with its icon, ringed
/// in the background color so it reads on any art.
class ZoneChip extends StatelessWidget {
  const ZoneChip({super.key, required this.zone, required this.color, this.size = 20});
  final ZoneSpec zone;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      width: size + 4,
      height: size + 4,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(moduleIcon(zone.icon), size: size * 0.62, color: p.onAccent),
      ),
    );
  }
}

