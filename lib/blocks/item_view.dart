import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../module_format/path_expr.dart';
import '../modules/loaded_module.dart';
import '../modules/module_state.dart';
import 'icons.dart';

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

/// A named symbol image declared in the module's `symbols`.
class SymbolImage extends StatelessWidget {
  const SymbolImage(this.name, {super.key, this.size = 24, this.label});
  final String name;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final m = context.read<LoadedModule>();
    final img = m.files.image(m.manifest.symbols[name]);
    final w = img == null
        ? SizedBox(width: size, height: size)
        : Image(image: img, width: size, height: size, fit: BoxFit.contain,
            errorBuilder: (_, _, _) => SizedBox(width: size, height: size));
    return label == null ? w : Semantics(label: label, child: w);
  }
}

/// One chip of an item's template: text, a symbol, or a labeled row of symbols.
class _ChipSpec {
  _ChipSpec(Map<String, dynamic> j)
      : symbol = j['symbol'] as String?,
        text = j['text'] as String?,
        symbols = j['symbols'] as String?,
        label = j['label'] as String?;
  final String? symbol, text, symbols, label;
}

/// The sheet template of a collection, read from `CollectionSpec.sheet`.
class SheetSpec {
  SheetSpec(Map<String, dynamic> j)
      : chips = [for (final c in (j['chips'] as List? ?? const [])) _ChipSpec((c as Map).cast<String, dynamic>())],
        effects = (j['effects'] as Map?)?.cast<String, dynamic>(),
        sections = [for (final s in (j['sections'] as List? ?? const [])) (s as Map).cast<String, dynamic>()],
        secondary = j['secondary'] as String?,
        verifiedPath = j['verifiedPath'] as String?,
        zones = (j['zones'] as List?)?.cast<String>() ?? const [];

  final List<_ChipSpec> chips;
  final Map<String, dynamic>? effects;
  final List<Map<String, dynamic>> sections;
  final String? secondary;
  final String? verifiedPath;
  final List<String> zones;

  /// Text of the first chip that resolves to something, for the text-only card.
  String? firstChipText(Map<String, dynamic> item) {
    for (final c in chips) {
      final t = c.text == null ? null : fillTemplate(c.text!, item).trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
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
    final chip = SheetSpec(collection.sheet).firstChipText(item.data);
    final subtitle = item.subtitle(collection);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return Container(
        padding: EdgeInsets.all(w * 0.07),
        decoration: BoxDecoration(color: Palette.parchment, borderRadius: BorderRadius.circular(radius)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.title(collection),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: w * 0.12, fontWeight: FontWeight.w800, color: Palette.ink, height: 1.1)),
              if (subtitle != null)
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: w * 0.08, fontStyle: FontStyle.italic, color: Palette.inkMuted, height: 1.3)),
              if (chip != null)
                Padding(
                  padding: EdgeInsets.only(top: w * 0.05),
                  child: Text(chip,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: w * 0.075, fontWeight: FontWeight.w600, color: Palette.inkMuted)),
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// An item's picture in its printed shape: `card` fills the shape with the picture,
/// `square` frames square art above the title and subtitle. No picture → [TextOnlyCard].
class ItemPicture extends StatelessWidget {
  const ItemPicture(this.item, this.collection, {super.key, this.radius = 12});

  final Item item;
  final CollectionSpec collection;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final img = context.read<LoadedModule>().files.image(item.imageRef(collection));
    final textOnly = TextOnlyCard(item, collection, radius: radius);
    Widget body;
    if (img == null) {
      body = textOnly;
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
    return LayoutBuilder(builder: (context, box) {
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
                        Text(item.title(collection),
                            style: TextStyle(
                                fontSize: w * 0.11, fontWeight: FontWeight.w800, color: Palette.ink, height: 1.1)),
                        if (subtitle != null)
                          Text(subtitle,
                              style: TextStyle(
                                  fontSize: w * 0.075,
                                  fontStyle: FontStyle.italic,
                                  color: Palette.inkMuted,
                                  height: 1.2)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Grid tile: picture, optional name below, and a zone ring + band when tracked.
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.collection,
    required this.collectionId,
    this.showName = true,
  });

  final Item item;
  final CollectionSpec collection;
  final String collectionId;
  final bool showName;

  /// Height of the name line under the picture, including the gap.
  static const nameHeight = 23.0;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final module = context.read<LoadedModule>();
    final zoneId = context.select<ZoneState, String?>((z) => z.zoneOf(item.id));
    final zone = zoneSpec(module, zoneId);
    final zc = zone == null ? null : zoneColor(context, zone);
    final title = item.title(collection);
    final bandAtTop = collection.imageShape == 'square';
    return Semantics(
      button: true,
      label: zone == null ? title : '$title, in ${zone.label}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => showItemSheet(context, item, collectionId),
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              foregroundDecoration: zc == null
                  ? null
                  : BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: zc, width: 2.5)),
              child: Stack(
                children: [
                  ItemPicture(item, collection),
                  if (zone != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: bandAtTop ? 0 : null,
                      bottom: bandAtTop ? null : 0,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: zc,
                          borderRadius: bandAtTop
                              ? const BorderRadius.vertical(top: Radius.circular(12))
                              : const BorderRadius.vertical(bottom: Radius.circular(12)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(moduleIcon(zone.icon), size: 14, color: p.onAccent),
                              const SizedBox(width: 3),
                              Text((zone.band ?? zone.label).toUpperCase(),
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
            if (showName) ...[
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, height: 1.2, fontWeight: FontWeight.w600, color: p.text),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Item detail as a bottom sheet over the current screen. Swipe down or tap outside to close.
Future<void> showItemSheet(BuildContext context, Item item, String collectionId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
    builder: (_) => ItemSheet(item: item, collectionId: collectionId),
  );
}

class ItemSheet extends StatelessWidget {
  const ItemSheet({super.key, required this.item, required this.collectionId});
  final Item item;
  final String collectionId;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final module = context.read<LoadedModule>();
    final collection = module.manifest.collections[collectionId]!;
    final sheet = SheetSpec(collection.sheet);
    final zones = context.watch<ZoneState>();
    final current = zones.zoneOf(item.id);
    final subtitle = item.subtitle(collection);
    final secondary = sheet.secondary == null ? null : fillTemplate(sheet.secondary!, item.data).trim();
    final verified = sheet.verifiedPath == null ? true : resolvePath(item.data, sheet.verifiedPath!).firstOrNull != false;
    final zoneSpecs = [for (final id in sheet.zones) ?zoneSpec(module, id)];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Thumb(item: item, collection: collection),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(item.title(collection),
                                        style: const TextStyle(fontSize: 26, height: 1.1, fontWeight: FontWeight.w800)),
                                  ),
                                  IconButton(
                                    tooltip: 'Close',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => Navigator.pop(context),
                                    icon: Icon(Icons.close_rounded, color: p.text2),
                                  ),
                                ],
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(subtitle, style: T.body.copyWith(color: p.text2, fontStyle: FontStyle.italic)),
                              ],
                              if (secondary != null && secondary.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(secondary, style: T.caption.copyWith(color: p.muted)),
                              ],
                              if (sheet.chips.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [for (final c in sheet.chips) ?_chip(c)],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (sheet.effects != null) ..._effects(context, sheet.effects!),
                    for (final s in sheet.sections) ..._section(context, s),
                    if (!verified)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('⚠ Text not verified. Check the physical card.',
                            style: T.caption.copyWith(color: p.warn)),
                      ),
                  ],
                ),
              ),
            ),
            if (zoneSpecs.isNotEmpty) ...[
              const SizedBox(height: 14),
              if (zoneSpecs.length == 1)
                _SingleZoneButton(zone: zoneSpecs.single, active: current == zoneSpecs.single.id, itemId: item.id)
              else
                Row(
                  children: [
                    for (final z in zoneSpecs) ...[
                      Expanded(child: _ZoneButton(zone: z, active: current == z.id, itemId: item.id)),
                      const SizedBox(width: 6),
                    ],
                    Tooltip(
                      message: 'Stop tracking',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: current == null ? null : () => zones.remove(item.id),
                        child: Container(
                          key: const Key('untrack'),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.line, width: 1.5),
                          ),
                          child: Icon(Icons.remove_done_rounded, color: current == null ? p.line : p.text),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _chip(_ChipSpec c) {
    final children = <Widget>[];
    if (c.label != null) children.add(Text(c.label!));
    if (c.symbol != null) {
      final name = fillTemplate(c.symbol!, item.data).trim();
      if (name.isNotEmpty) {
        if (children.isNotEmpty) children.add(const SizedBox(width: 4));
        children.add(SymbolImage(name, size: 22));
      }
    }
    if (c.text != null) {
      final t = fillTemplate(c.text!, item.data).trim();
      if (t.isNotEmpty) {
        if (children.isNotEmpty) children.add(const SizedBox(width: 6));
        children.add(Text(t));
      }
    }
    if (c.symbols != null) {
      final names = resolvePath(item.data, c.symbols!).map((v) => '$v').toList();
      if (names.isNotEmpty) {
        if (children.isNotEmpty) children.add(const SizedBox(width: 4));
        children.add(Semantics(
          label: '${names.length} symbols',
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final n in names) Padding(padding: const EdgeInsets.only(right: 3), child: SymbolImage(n, size: 20)),
          ]),
        ));
      }
    }
    if (children.isEmpty) return null;
    return _Chip(children: children);
  }

  List<Widget> _effects(BuildContext context, Map<String, dynamic> e) {
    final p = context.pal;
    final labels = (e['typeLabels'] as Map?)?.cast<String, dynamic>() ?? const {};
    final symbols = (e['typeSymbols'] as Map?)?.cast<String, dynamic>() ?? const {};
    final help = (e['typeHelp'] as Map?)?.cast<String, dynamic>() ?? const {};
    final list = resolvePath(item.data, e['path'] as String? ?? 'effects');
    return [
      for (final raw in list)
        if (raw is Map)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: '${help[raw['type']] ?? ''}',
                  triggerMode: TooltipTriggerMode.longPress,
                  child: symbols[raw['type']] is String
                      ? SymbolImage(symbols[raw['type']] as String, size: 38)
                      : const SizedBox(width: 38, height: 38),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${labels[raw['type']] ?? raw['type'] ?? ''}'.toUpperCase(),
                          style: T.caption.copyWith(color: p.text2, letterSpacing: 1)),
                      const SizedBox(height: 2),
                      Text('${raw['text'] ?? ''}', style: T.effect.copyWith(color: p.text)),
                    ],
                  ),
                ),
              ],
            ),
          ),
    ];
  }

  List<Widget> _section(BuildContext context, Map<String, dynamic> s) {
    final p = context.pal;
    final values = resolvePath(item.data, s['path'] as String? ?? '').map((v) => '$v').where((v) => v.isNotEmpty);
    if (values.isEmpty) return const [];
    return [
      Text('${s['label'] ?? ''}'.toUpperCase(), style: T.caption.copyWith(color: p.text2, letterSpacing: 1)),
      const SizedBox(height: 4),
      for (final v in values)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(v, style: T.effect.copyWith(color: p.text))),
      const SizedBox(height: 6),
    ];
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, required this.collection});
  final Item item;
  final CollectionSpec collection;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (d) => GestureDetector(
          onTap: () => Navigator.pop(d),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: InteractiveViewer(
                maxScale: 4,
                child: SizedBox(width: 300, child: ItemPicture(item, collection, radius: 14)),
              ),
            ),
          ),
        ),
      ),
      child: SizedBox(
        width: 88,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(blurRadius: 12, offset: Offset(0, 4), color: Colors.black38)],
              ),
              child: ItemPicture(item, collection, radius: 8),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(color: Color(0xCC121315), shape: BoxShape.circle),
                child: const Icon(Icons.open_in_full_rounded, size: 16, color: Color(0xFFF2EDE4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(15)),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// Toggle: tap to move the item to this zone; tap the active zone again to untrack.
class _ZoneButton extends StatelessWidget {
  const _ZoneButton({required this.zone, required this.active, required this.itemId});
  final ZoneSpec zone;
  final bool active;
  final String itemId;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final zc = zoneColor(context, zone);
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? zc : p.surface2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final z = context.read<ZoneState>();
            active ? z.remove(itemId) : z.put(itemId, zone.id);
          },
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(moduleIcon(zone.icon), size: 21, color: active ? p.onAccent : zc),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(zone.label,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: active ? p.onAccent : p.text)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One wide "Add to <zone>" / "In <zone>" toggle for modules with a single zone.
class _SingleZoneButton extends StatelessWidget {
  const _SingleZoneButton({required this.zone, required this.active, required this.itemId});
  final ZoneSpec zone;
  final bool active;
  final String itemId;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final zc = zoneColor(context, zone);
    return Material(
      color: active ? zc : p.surface2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('toggleZone'),
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final z = context.read<ZoneState>();
          active ? z.remove(itemId) : z.put(itemId, zone.id);
        },
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(active ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  color: active ? p.onAccent : zc),
              const SizedBox(width: 8),
              Text(active ? 'In ${zone.label}' : 'Add to ${zone.label}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: active ? p.onAccent : p.text)),
            ],
          ),
        ),
      ),
    );
  }
}
