import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../modules/loaded_module.dart';

/// The accent color of a zone: amber, mint or violet (tracking state only).
Color zoneColor(BuildContext context, ZoneSpec z) {
  final p = context.pal;
  return switch (z.accent) {
    'mint' => p.mint,
    'violet' => p.violet,
    _ => p.amber,
  };
}

ZoneSpec? zoneSpec(LoadedModule m, String? id) => m.manifest.zones.where((z) => z.id == id).firstOrNull;

/// A named symbol image declared in the module's `symbols`. `name#3` draws "3" centred on
/// the picture (a printed coin with its amount, a points badge with its value). Since 3.3.3.
class SymbolImage extends StatelessWidget {
  const SymbolImage(this.name, {super.key, this.size = 24, this.label});
  final String name;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final m = context.read<LoadedModule>();
    final hash = name.indexOf('#');
    final base = hash < 0 ? name : name.substring(0, hash);
    final number = hash < 0 ? '' : name.substring(hash + 1);
    final img = m.files.image(m.manifest.symbols[base]);
    Widget w = img == null
        ? SizedBox(width: size, height: size)
        : Image(
            image: img,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
          );
    if (number.isNotEmpty) {
      // Bold white with a dark rim, so it reads on a gold coin and on a green badge alike.
      final stroke = (size / 24).clamp(0.6, 2.5);
      w = SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            w,
            Text(
              number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: size * (number.length > 1 ? 0.46 : 0.58),
                height: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: [
                  for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)])
                    Shadow(offset: Offset(dx * stroke, dy * stroke), color: const Color(0xFF14110C)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final semantics = label ?? '${base.replaceAll('_', ' ')}${number.isEmpty ? '' : ' $number'}';
    return Semantics(label: semantics, child: w);
  }
}

/// A clean card with the name and key fields, for items with no (or a broken) picture.
class TextOnlyCard extends StatelessWidget {
  const TextOnlyCard(this.item, this.collection, {super.key, this.radius = 12});
  final Item item;
  final CollectionSpec collection;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final chip = collection.sheet.firstChipText(item.data);
    final subtitle = item.subtitle(collection);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return Container(
          padding: EdgeInsets.all(w * 0.07),
          decoration: BoxDecoration(color: Palette.parchment, borderRadius: BorderRadius.circular(radius)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title(collection),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: w * 0.12, fontWeight: FontWeight.w800, color: Palette.ink, height: 1.1),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: w * 0.08,
                      fontStyle: FontStyle.italic,
                      color: Palette.inkMuted,
                      height: 1.3,
                    ),
                  ),
                if (chip != null)
                  Padding(
                    padding: EdgeInsets.only(top: w * 0.05),
                    child: Text(
                      chip,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: w * 0.075, fontWeight: FontWeight.w600, color: Palette.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Decodes [img] no wider than [logicalWidth] at [dpr], so a grid of tiles never holds
/// full-size frames. The sheet's zoom keeps the raw provider.
ImageProvider sizedImage(ImageProvider img, double logicalWidth, double dpr) {
  final w = (logicalWidth * dpr).ceil();
  if (w <= 0) return img;
  return ResizeImage(img, width: w, policy: ResizeImagePolicy.fit, allowUpscaling: false);
}

/// An item's picture in its printed shape: `card` fills the shape with the picture,
/// `square` frames square art above the title and subtitle. No picture → [TextOnlyCard].
class ItemPicture extends StatelessWidget {
  const ItemPicture(
    this.item,
    this.collection, {
    super.key,
    this.radius = 12,
    this.artOnly = false,
    this.decodeWidth,
    this.back = false,
  });

  /// For the `square` shape: draw just the square art, without the card frame (list rows).
  final bool artOnly;

  /// Draw the item's second picture (`backImageField`) instead of its front.
  final bool back;

  final Item item;
  final CollectionSpec collection;
  final double radius;

  /// Logical width the picture will be drawn at, when the caller knows it (grid tiles). The
  /// picture is then decoded no wider than that; without it the full file is decoded.
  final double? decodeWidth;

  @override
  Widget build(BuildContext context) {
    final ref = back ? item.backImageRef(collection) : item.imageRef(collection);
    final raw = context.read<LoadedModule>().files.image(ref);
    final textOnly = TextOnlyCard(item, collection, radius: radius);
    if (raw == null) return AspectRatio(aspectRatio: collection.cardAspect, child: textOnly);
    final w = decodeWidth;
    final img = w == null ? raw : sizedImage(raw, w, MediaQuery.devicePixelRatioOf(context));
    Widget body;
    if (collection.imageShape == 'square' && artOnly) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image(image: img, fit: BoxFit.cover, errorBuilder: (_, _, _) => textOnly),
        ),
      );
    } else if (collection.imageShape == 'square') {
      body = _FramedCard(item: item, collection: collection, image: img, radius: radius, fallback: textOnly);
    } else {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image(image: img, fit: BoxFit.cover, errorBuilder: (_, _, _) => textOnly),
      );
    }
    return AspectRatio(aspectRatio: collection.cardAspect, child: body);
  }
}

/// Square art on parchment with the title and subtitle below (Magical Athlete style).
class _FramedCard extends StatelessWidget {
  const _FramedCard({
    required this.item,
    required this.collection,
    required this.image,
    required this.radius,
    required this.fallback,
  });
  final Item item;
  final CollectionSpec collection;
  final ImageProvider image;
  final double radius;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final subtitle = item.subtitle(collection);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final pad = w * 0.05;
        return Container(
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(color: Palette.parchment, borderRadius: BorderRadius.circular(radius)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(radius * 0.6),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image(
                    image: image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(color: context.pal.surface2),
                  ),
                ),
              ),
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
                            item.title(collection),
                            style: TextStyle(
                              fontSize: w * 0.11,
                              fontWeight: FontWeight.w800,
                              color: Palette.ink,
                              height: 1.1,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
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
    );
  }
}
