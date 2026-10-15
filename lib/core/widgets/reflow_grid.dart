import 'package:flutter/material.dart';

/// Grid whose tiles glide to their new slots when the column count or the item set changes.
/// Each tile is a picture of [aspect] (width / height) plus [extraHeight] below it (a name line).
class ReflowGrid<T> extends StatelessWidget {
  const ReflowGrid({
    super.key,
    required this.items,
    required this.idOf,
    required this.tileBuilder,
    required this.columns,
    required this.aspect,
    this.extraHeight = 0,
  });

  final List<T> items;
  final String Function(T) idOf;
  final Widget Function(T) tileBuilder;
  final int columns;
  final double aspect;
  final double extraHeight;

  static const spacing = 8.0;
  static const runSpacing = 10.0;
  static const duration = Duration(milliseconds: 260);
  static const curve = Curves.easeOutCubic;

  static double tileWidth(double width, int columns) => (width - spacing * (columns - 1)) / columns;

  /// Total height for [count] items at [width], so callers can compute scroll offsets.
  static double heightFor(int count, double width, int columns, {required double aspect, double extra = 0}) {
    final rows = (count / columns).ceil();
    if (rows == 0) return 0;
    final tileH = tileWidth(width, columns) / aspect + extra;
    return rows * tileH + (rows - 1) * runSpacing;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final tileW = tileWidth(w, columns);
      final tileH = tileW / aspect + extraHeight;
      return AnimatedContainer(
        duration: duration,
        curve: curve,
        height: heightFor(items.length, w, columns, aspect: aspect, extra: extraHeight),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < items.length; i++)
              AnimatedPositioned(
                key: ValueKey(idOf(items[i])),
                duration: duration,
                curve: curve,
                left: (i % columns) * (tileW + spacing),
                top: (i ~/ columns) * (tileH + runSpacing),
                width: tileW,
                height: tileH,
                child: tileBuilder(items[i]),
              ),
          ],
        ),
      );
    });
  }
}
