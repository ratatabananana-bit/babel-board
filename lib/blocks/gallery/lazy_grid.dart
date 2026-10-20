import 'package:flutter/material.dart';

import '../../core/widgets/reflow_grid.dart';
import '../../modules/loaded_module.dart';

/// A grid of items that builds only the tiles near the viewport: what the gallery uses
/// above [kReflowLimit] items, where [ReflowGrid] (every tile built, gliding to its slot)
/// would hold hundreds of pictures at once. Same geometry as [ReflowGrid] at [width], so
/// [ReflowGrid.heightFor] still gives the height the rail needs for its jumps.
Widget lazyGridSliver({
  required List<Item> items,
  required int columns,
  required double aspect,
  required double extraHeight,
  required double width,
  required Widget Function(Item) tileBuilder,
}) {
  final tileW = ReflowGrid.tileWidth(width, columns);
  final tileH = ReflowGrid.tileHeight(width, columns, aspect: aspect, extra: extraHeight);
  return SliverGrid(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: ReflowGrid.defaultRunSpacing,
      crossAxisSpacing: ReflowGrid.defaultSpacing,
      childAspectRatio: tileW / tileH,
    ),
    delegate: SliverChildBuilderDelegate(
      (context, i) => KeyedSubtree(key: ValueKey(items[i].id), child: tileBuilder(items[i])),
      childCount: items.length,
    ),
  );
}
