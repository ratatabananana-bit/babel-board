import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card.dart';
import '../models/zone.dart';
import '../state/tracker.dart';
import '../theme.dart';
import 'card_image.dart';

/// The whole card in its printed 5:7 shape.
class CardArt extends StatelessWidget {
  const CardArt(this.card, {super.key, this.radius = 12});

  final GameCard card;
  final double radius;

  @override
  Widget build(BuildContext context) => CardImage(card, radius: radius);
}

/// Grid tile: cropped art with the English name below. Tracked cards get a zone-colored
/// ring and a band naming the zone.
class CardTile extends StatelessWidget {
  const CardTile({super.key, required this.card, required this.onTap});

  final GameCard card;
  final VoidCallback onTap;

  /// Height of the name line under the art, including the gap.
  static const nameHeight = 23.0;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final zone = context.select<Tracker, Zone?>((t) => t.zoneOf(card.id));
    final zc = zone == null ? null : p.zone(zone);
    return Semantics(
      button: true,
      label: zone == null ? card.name : '${card.name}, in ${zone.label}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              foregroundDecoration: zc == null
                  ? null
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: zc, width: 2.5),
                    ),
              child: Stack(
                children: [
                  CardArt(card),
                  if (zone != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: zc,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(zone.icon, size: 14, color: p.onAccent),
                              const SizedBox(width: 3),
                              Text(zone.label.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                      color: p.onAccent)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, height: 1.2, fontWeight: FontWeight.w600, color: p.text),
            ),
          ],
        ),
      ),
    );
  }
}
