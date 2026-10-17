import 'package:flutter/material.dart';

import '../theme.dart';

/// A card picture in its printed shape, with a named placeholder if the image is missing.
class CardPicture extends StatelessWidget {
  const CardPicture({super.key, required this.asset, required this.aspect, required this.label, this.radius = 12});

  final String? asset;

  /// Width / height of the printed card.
  final double aspect;

  /// Shown on the placeholder.
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final placeholder = Container(
      color: p.surface2,
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.text2),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: aspect,
        child: asset == null
            ? placeholder
            : Image.asset(asset!, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
      ),
    );
  }
}
