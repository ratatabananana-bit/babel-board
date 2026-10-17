import 'package:flutter/material.dart';

import '../models/card.dart';

/// Card art; falls back to a family-colored placeholder with name and cost.
class CardImage extends StatelessWidget {
  const CardImage(this.card, {super.key, this.radius = 6});

  final GameCard card;
  final double radius;

  static const aspect = 300 / 419; // width / height of the printed card

  @override
  Widget build(BuildContext context) {
    final img = card.image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: aspect,
        child: img == null
            ? _Placeholder(card)
            : Image.asset(img, fit: BoxFit.cover, errorBuilder: (_, _, _) => _Placeholder(card)),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.card);
  final GameCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: card.family.color.withValues(alpha: 0.85),
      padding: const EdgeInsets.all(4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${card.cost}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              card.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
            if (card.nameZh != null) Text(card.nameZh!, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
