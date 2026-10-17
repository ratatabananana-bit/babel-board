import 'package:flutter/material.dart';

import '../../../core/widgets/reflow_grid.dart';
import '../models/card.dart';
import 'card_art.dart';
import 'card_image.dart';

/// Vale card grid: [ReflowGrid] with card-shaped tiles and the name below.
class AnimatedCardGrid extends StatelessWidget {
  const AnimatedCardGrid({super.key, required this.cards, required this.columns, required this.onTap});

  final List<GameCard> cards;
  final int columns;
  final void Function(GameCard) onTap;

  static double heightFor(int count, double width, int columns) =>
      ReflowGrid.heightFor(count, width, columns, aspect: CardImage.aspect, extra: CardTile.nameHeight);

  @override
  Widget build(BuildContext context) => ReflowGrid<GameCard>(
    items: cards,
    idOf: (c) => c.id,
    columns: columns,
    aspect: CardImage.aspect,
    extraHeight: CardTile.nameHeight,
    tileBuilder: (c) => CardTile(card: c, onTap: () => onTap(c)),
  );
}
