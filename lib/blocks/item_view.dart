import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../modules/loaded_module.dart';

/// An item's picture in its printed shape. Minimal version; the gallery task extends it
/// with the square (framed) style and the text-only card.
class ItemPicture extends StatelessWidget {
  const ItemPicture(this.item, this.collection, {super.key, this.radius = 12});

  final Item item;
  final CollectionSpec collection;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final img = context.read<LoadedModule>().files.image(item.imageRef(collection));
    final placeholder = Container(
      color: p.surface2,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: Text(item.title(collection),
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.text2)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: collection.cardAspect,
        child: img == null ? placeholder : Image(image: img, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
      ),
    );
  }
}
