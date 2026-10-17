import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../models/racer.dart';

/// Square racer art (the image is the art only, no card text).
class RacerArt extends StatelessWidget {
  const RacerArt(this.racer, {super.key, this.radius = 8});
  final Racer racer;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 1,
        child: racer.image == null
            ? ColoredBox(color: p.surface2)
            : Image.asset(
                racer.image!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: p.surface2),
              ),
      ),
    );
  }
}

/// A racer drawn like its printed card: art on top, English name and power name below.
class RacerCard extends StatelessWidget {
  const RacerCard(this.racer, {super.key, this.radius = 12});
  final Racer racer;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: racerAspect,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final pad = w * 0.05;
          return Container(
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(color: Palette.parchment, borderRadius: BorderRadius.circular(radius)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RacerArt(racer, radius: radius * 0.6),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              racer.name,
                              style: TextStyle(
                                fontSize: w * 0.11,
                                fontWeight: FontWeight.w800,
                                color: Palette.ink,
                                height: 1.1,
                              ),
                            ),
                            if (racer.powerName != null)
                              Text(
                                racer.powerName!,
                                style: TextStyle(
                                  fontSize: w * 0.075,
                                  fontStyle: FontStyle.italic,
                                  color: Palette.inkMuted,
                                  height: 1.2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
