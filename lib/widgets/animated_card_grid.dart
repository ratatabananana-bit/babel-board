import 'package:flutter/material.dart';

import '../models/card.dart';
import 'card_art.dart';
import 'card_image.dart';

/// Grid whose tiles glide to their new slots when the column count or the card set changes.
class AnimatedCardGrid extends StatelessWidget {
  const AnimatedCardGrid({
    super.key,
    required this.cards,
    required this.columns,
    required this.onTap,
  });

  final List<GameCard> cards;
  final int columns;
  final void Function(GameCard) onTap;

  static const spacing = 8.0;
  static const runSpacing = 10.0;
  static const duration = Duration(milliseconds: 260);
  static const curve = Curves.easeOutCubic;

  static double tileWidth(double width, int columns) => (width - spacing * (columns - 1)) / columns;

  /// Total height for [count] cards at [width], so callers can compute scroll offsets.
  static double heightFor(int count, double width, int columns) {
    final rows = (count / columns).ceil();
    if (rows == 0) return 0;
    final tileH = tileWidth(width, columns) / CardImage.aspect + CardTile.nameHeight;
    return rows * tileH + (rows - 1) * runSpacing;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final tileW = tileWidth(w, columns);
      final tileH = tileW / CardImage.aspect + CardTile.nameHeight;
      return AnimatedContainer(
        duration: duration,
        curve: curve,
        height: heightFor(cards.length, w, columns),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < cards.length; i++)
              AnimatedPositioned(
                key: ValueKey(cards[i].id),
                duration: duration,
                curve: curve,
                left: (i % columns) * (tileW + spacing),
                top: (i ~/ columns) * (tileH + runSpacing),
                width: tileW,
                height: tileH,
                child: CardTile(card: cards[i], onTap: () => onTap(cards[i])),
              ),
          ],
        ),
      );
    });
  }
}
