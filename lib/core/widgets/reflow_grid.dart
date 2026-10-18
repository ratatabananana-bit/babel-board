import 'package:flutter/material.dart';

/// Grid whose tiles glide to their new slots when the column count or the item set changes.
/// Each tile is a picture of [aspect] (width / height) plus [extraHeight] below it (a name
/// line, a ruler strip). [cellInset] is horizontal padding inside each cell that the picture
/// does not use (so the picture is `cell width - cellInset` wide).
class ReflowGrid<T> extends StatelessWidget {
  const ReflowGrid({
    super.key,
    required this.items,
    required this.idOf,
    required this.tileBuilder,
    required this.columns,
    required this.aspect,
    this.extraHeight = 0,
    this.spacing = defaultSpacing,
    this.runSpacing = defaultRunSpacing,
    this.cellInset = 0,
    this.duration = normalDuration,
  });

  final List<T> items;
  final String Function(T) idOf;
  final Widget Function(T) tileBuilder;
  final int columns;
  final double aspect;
  final double extraHeight;
  final double spacing;
  final double runSpacing;
  final double cellInset;

  /// How long tiles take to glide to new slots (zero: they jump).
  final Duration duration;

  static const defaultSpacing = 8.0;
  static const defaultRunSpacing = 10.0;
  static const normalDuration = Duration(milliseconds: 260);
  static const curve = Curves.easeOutCubic;

  static double tileWidth(double width, int columns, {double spacing = defaultSpacing}) =>
      (width - spacing * (columns - 1)) / columns;

  static double tileHeight(
    double width,
    int columns, {
    required double aspect,
    double extra = 0,
    double spacing = defaultSpacing,
    double cellInset = 0,
  }) => (tileWidth(width, columns, spacing: spacing) - cellInset) / aspect + extra;

  /// Total height for [count] items at [width], so callers can compute scroll offsets.
  static double heightFor(
    int count,
    double width,
    int columns, {
    required double aspect,
    double extra = 0,
    double spacing = defaultSpacing,
    double runSpacing = defaultRunSpacing,
    double cellInset = 0,
  }) {
    final rows = (count / columns).ceil();
    if (rows == 0) return 0;
    final tileH = tileHeight(width, columns, aspect: aspect, extra: extra, spacing: spacing, cellInset: cellInset);
    return rows * tileH + (rows - 1) * runSpacing;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final tileW = tileWidth(w, columns, spacing: spacing);
        final tileH = tileHeight(w, columns, aspect: aspect, extra: extraHeight, spacing: spacing, cellInset: cellInset);
        return AnimatedContainer(
          duration: duration,
          curve: curve,
          height: heightFor(
            items.length,
            w,
            columns,
            aspect: aspect,
            extra: extraHeight,
            spacing: spacing,
            runSpacing: runSpacing,
            cellInset: cellInset,
          ),
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
      },
    );
  }
}
