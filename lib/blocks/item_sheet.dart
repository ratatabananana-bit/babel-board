import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/settings.dart';
import '../core/theme.dart';
import '../module_format/path_expr.dart';
import '../module_format/sheet_spec.dart';
import '../modules/loaded_module.dart';
import '../modules/module_state.dart';
import 'icons.dart';
import 'item_picture.dart';
import 'symbol_text.dart';

/// Item detail as a bottom sheet over the current screen. Swipe down or tap outside to close.
Future<void> showItemSheet(BuildContext context, Item item, String collectionId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false, // the sheet draws its own handle (see ItemSheet)
    // The sheet paints its own panel (see _SheetPanel), so a flick can slide the panel
    // away and uncover the slot behind it.
    backgroundColor: Colors.transparent,
    elevation: 0,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
    // Speed follows the setting (Fast by default: tracking six cards in a row shouldn't mean
    // waiting on each sheet; Instant skips the slide).
    sheetAnimationStyle: AnimationStyle(
      duration: context.read<Settings>().anim(const Duration(milliseconds: 250)),
      reverseDuration: context.read<Settings>().anim(const Duration(milliseconds: 200)),
    ),
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
    final sheet = collection.sheet;
    final zones = context.watch<ZoneState>();
    final current = zones.zoneOf(item.id);
    final subtitle = item.subtitle(collection);
    final secondary = sheet.secondary == null ? null : fillTemplate(sheet.secondary!, item.data).trim();
    final verified = sheet.verifiedPath == null
        ? true
        : resolvePath(item.data, sheet.verifiedPath!).firstOrNull != false;
    final zoneSpecs = [for (final id in sheet.zones) ?zoneSpec(module, id)];

    // Flick sides that have a zone in this module.
    final swipe = {for (final e in sheet.swipe.sides.entries) e.key: ?zoneSpec(module, e.value)};

    // Drag-up details that this item actually has text for.
    final hidden = [
      for (final s in sheet.detailSections)
        if (resolvePath(item.data, s.path).map((v) => '$v').where((v) => v.isNotEmpty).toList() case final values
            when values.isNotEmpty)
          (label: s.label, values: values),
    ];

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The handle is part of the card, so dragging it works like dragging the card.
        Padding(
          key: const Key('sheetHandle'),
          padding: const EdgeInsets.only(top: 12, bottom: 16),
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
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
                                child: Text(
                                  item.title(collection),
                                  style: const TextStyle(fontSize: 26, height: 1.1, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: T.body.copyWith(color: p.text2, fontStyle: FontStyle.italic),
                            ),
                          ],
                          if (secondary != null && secondary.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            SymbolText(secondary, style: T.caption.copyWith(color: p.muted)),
                          ],
                          if (sheet.chips.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(spacing: 6, runSpacing: 6, children: [for (final c in sheet.chips) ?_chip(c)]),
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
                    child: Text(
                      '⚠ Text not verified. Check the physical card.',
                      style: T.caption.copyWith(color: p.warn),
                    ),
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
                  Expanded(
                    child: _ZoneButton(zone: z, active: current == z.id, itemId: item.id),
                  ),
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
    );

    if (hidden.isEmpty && swipe.isEmpty) return _SheetPanel(child: content);
    return _SheetGestures(itemId: item.id, sections: hidden, hint: sheet.details?.hint, swipe: swipe, child: content);
  }

  Widget? _chip(ChipSpec c) {
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
        children.add(
          Semantics(
            label: '${names.length} symbols',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final n in names)
                  Padding(padding: const EdgeInsets.only(right: 3), child: SymbolImage(n, size: 20)),
              ],
            ),
          ),
        );
      }
    }
    if (children.isEmpty) return null;
    return _Chip(children: children);
  }

  List<Widget> _effects(BuildContext context, EffectsSpec e) {
    final p = context.pal;
    final labels = e.typeLabels;
    final symbols = e.typeSymbols;
    final help = e.typeHelp;
    final list = resolvePath(item.data, e.path);
    return [
      for (final raw in list)
        if (raw is Map)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: help[raw['type']] ?? '',
                  triggerMode: TooltipTriggerMode.longPress,
                  child: symbols[raw['type']] == null
                      ? const SizedBox(width: 38, height: 38)
                      : SymbolImage(symbols[raw['type']]!, size: 38),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${labels[raw['type']] ?? raw['type'] ?? ''}'.toUpperCase(),
                        style: T.caption.copyWith(color: p.text2, letterSpacing: 1),
                      ),
                      const SizedBox(height: 2),
                      SymbolText('${raw['text'] ?? ''}', style: T.effect.copyWith(color: p.text)),
                    ],
                  ),
                ),
              ],
            ),
          ),
    ];
  }

  List<Widget> _section(BuildContext context, SheetSectionSpec s) {
    final p = context.pal;
    final values = resolvePath(item.data, s.path).map((v) => '$v').where((v) => v.isNotEmpty);
    if (values.isEmpty) return const [];
    return [
      Text(s.label.toUpperCase(), style: T.caption.copyWith(color: p.text2, letterSpacing: 1)),
      const SizedBox(height: 4),
      for (final v in values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SymbolText(v, style: T.effect.copyWith(color: p.text)),
        ),
      const SizedBox(height: 6),
    ];
  }
}

/// The sheet's own panel: surface color, rounded top, padding that clears the bottom
/// inset. Drawn here (not by the modal route) so a flick can slide it off its slot.
class _SheetPanel extends StatelessWidget {
  const _SheetPanel({required this.child});
  final Widget child;

  static const radius = BorderRadius.vertical(top: Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      key: const Key('sheetPanel'),
      decoration: BoxDecoration(color: p.surface, borderRadius: radius),
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.paddingOf(context).bottom),
      child: child,
    );
  }
}

/// Gestures on the item sheet, all optional:
/// - drag-up details: extra text hidden below the zone buttons. Dragging the card up
///   uncovers it (following the finger, then snapping open or shut); dragging down hides it
///   again, and a further drag down closes the sheet. The arrow (and its label) toggles it.
/// - flick left / right: puts the item in the zone the module names for that side, then
///   closes the sheet. The panel follows the finger and tilts a little; the feedback is on
///   the slot it uncovers, never on the panel: the slot tints in the zone's color and shows
///   the zone's icon and name in the revealed strip. Past the threshold (a third of the
///   width) the slot fills solid and the icon becomes a check. On release the panel flies
///   out, the slot reads "Added to …" for a moment, and the sheet closes.
class _SheetGestures extends StatefulWidget {
  const _SheetGestures({
    required this.itemId,
    required this.sections,
    required this.hint,
    required this.swipe,
    required this.child,
  });
  final String itemId;
  final List<({String label, List<String> values})> sections;

  /// Label next to the drag-up arrow (from the module), or null for the bare arrow.
  final String? hint;

  /// Zone for each side: 'left' / 'right'.
  final Map<String, ZoneSpec> swipe;
  final Widget child;

  @override
  State<_SheetGestures> createState() => _SheetGesturesState();
}

class _SheetGesturesState extends State<_SheetGestures> with TickerProviderStateMixin {
  /// How far sideways the panel must go to commit, as a fraction of its width.
  static const threshold = 1 / 3;

  late final _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));

  /// Sideways offset as a fraction of the sheet's width (-1 left … 1 right).
  late final _slide = AnimationController(vsync: this, lowerBound: -1.5, upperBound: 1.5, value: 0);

  /// Times the "Added to …" confirmation (a ticker, so it runs on frames like the rest).
  late final _confirm = AnimationController(vsync: this);
  final _detailsKey = GlobalKey();
  Duration _spring = const Duration(milliseconds: 270);
  Duration _hold = const Duration(milliseconds: 400);

  /// Set when a drag starts with the details hidden; a drag down then means "close".
  bool _startedHidden = false;
  double _pulledDown = 0;

  /// True once the finger is past the threshold (for the haptic tick on crossing).
  bool _past = false;

  /// The zone the item went to on release; the slot then stays solid until the sheet closes.
  ZoneSpec? _committed;

  /// True while the slot reads "Added to …" after the fly-out.
  bool _confirmed = false;

  bool get _hasDetails => widget.sections.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.watch<Settings>();
    _reveal.duration = s.anim(const Duration(milliseconds: 360));
    _spring = s.anim(const Duration(milliseconds: 270));
    _hold = s.anim(const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _reveal.dispose();
    _slide.dispose();
    _confirm.dispose();
    super.dispose();
  }

  double get _detailsHeight {
    final box = _detailsKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null || box.size.height <= 0 ? 200 : box.size.height;
  }

  void _settleReveal(bool open) {
    if (open) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
  }

  // Vertical: drag-up details.
  void _onVStart(DragStartDetails d) {
    _reveal.stop();
    _startedHidden = _reveal.value == 0;
    _pulledDown = 0;
  }

  void _onVUpdate(DragUpdateDetails d) {
    final dy = d.primaryDelta ?? 0;
    if (_startedHidden && _reveal.value == 0 && dy > 0) {
      _pulledDown += dy;
      return;
    }
    _reveal.value = (_reveal.value - dy / _detailsHeight).clamp(0.0, 1.0);
  }

  void _onVEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_startedHidden && _reveal.value == 0) {
      if (_pulledDown > 60 || v > 600) Navigator.maybePop(context);
      return;
    }
    _settleReveal(v < -300 || (v.abs() <= 300 && _reveal.value > 0.4));
  }

  // Horizontal: flick into a zone.
  double get _width => (context.findRenderObject() as RenderBox?)?.size.width ?? 360;

  ZoneSpec? _zoneFor(double dir) => widget.swipe[dir > 0 ? 'right' : 'left'];

  void _onHStart(DragStartDetails d) {
    if (_committed != null) return;
    _slide.stop();
  }

  void _onHUpdate(DragUpdateDetails d) {
    if (_committed != null) return;
    final next = _slide.value + (d.primaryDelta ?? 0) / _width;
    // Only follow the finger towards a side that has a zone.
    _slide.value = (_zoneFor(next) == null ? 0.0 : next).clamp(-1.0, 1.0);
    final past = _slide.value.abs() >= threshold;
    if (past != _past) {
      _past = past;
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _onHEnd(DragEndDetails d) async {
    if (_committed != null) return;
    final v = (d.primaryVelocity ?? 0) / _width;
    final x = _slide.value;
    final dir = x != 0 ? x.sign : v.sign;
    final zone = dir == 0 ? null : _zoneFor(dir);
    final commit = zone != null && (x.abs() >= threshold || (v.abs() > 2 && v.sign == dir));
    if (!commit) {
      _past = false;
      _slide.animateTo(0, duration: _spring, curve: Curves.easeOutCubic);
      return;
    }
    // Put it there, fly the panel out, show the confirmation on the slot, close.
    final zones = context.read<ZoneState>();
    if (zones.zoneOf(widget.itemId) != zone.id) zones.put(widget.itemId, zone.id);
    setState(() => _committed = zone);
    final instant = _spring == Duration.zero;
    if (instant) {
      _slide.value = dir * 1.2;
    } else {
      await _slide.animateTo(dir * 1.2, duration: _spring ~/ 2, curve: Curves.easeIn);
    }
    if (!mounted) return;
    setState(() => _confirmed = true);
    // Instant still shows the confirmation for one frame (a zero-length run ends next tick).
    _confirm.duration = instant ? Duration.zero : _hold;
    await _confirm.forward(from: 0);
    if (mounted) Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _hasDetails ? _onVStart : null,
      onVerticalDragUpdate: _hasDetails ? _onVUpdate : null,
      onVerticalDragEnd: _hasDetails ? _onVEnd : null,
      onHorizontalDragStart: widget.swipe.isEmpty ? null : _onHStart,
      onHorizontalDragUpdate: widget.swipe.isEmpty ? null : _onHUpdate,
      onHorizontalDragEnd: widget.swipe.isEmpty ? null : _onHEnd,
      child: AnimatedBuilder(
        animation: Listenable.merge([_reveal, _slide]),
        builder: (context, child) {
          final x = _slide.value;
          final panel = _SheetPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(child: child!),
                if (_hasDetails) ...[
                  // Arrow plus the module's label: there is more below. Tap it, or drag up.
                  GestureDetector(
                    key: const Key('detailsHint'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _settleReveal(_reveal.value < 0.5),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.rotate(
                            angle: _reveal.value * 3.14159,
                            child: Icon(Icons.keyboard_arrow_up_rounded, size: 24, color: p.muted),
                          ),
                          if (widget.hint case final h? when h.isNotEmpty) ...[
                            const SizedBox(width: 2),
                            Text(h, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.muted)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  ClipRect(
                    child: Align(
                      key: const Key('detailsReveal'),
                      alignment: Alignment.topCenter,
                      heightFactor: _reveal.value,
                      child: KeyedSubtree(key: _detailsKey, child: _details(p)),
                    ),
                  ),
                ],
              ],
            ),
          );
          final zone = _committed ?? (x == 0 ? null : _zoneFor(x));
          if (zone == null) return panel;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: _slot(p, zone, x)),
              Transform.translate(
                offset: Offset(x * _width, 0),
                // Up to 4° at the far edge.
                child: Transform.rotate(angle: x * 0.07, child: panel),
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }

  /// The slot the panel slides off: the zone's tint grows with the drag, then fills solid
  /// past the threshold. Its icon and name sit in the strip the panel has uncovered.
  Widget _slot(Palette p, ZoneSpec zone, double x) {
    final zc = zoneColor(context, zone);
    final progress = (x.abs() / threshold).clamp(0.0, 1.0);
    final past = _committed != null || x.abs() >= threshold;
    final base = Color.lerp(p.bg, Colors.black, 0.45)!;
    final fill = past ? zc : Color.alphaBlend(zc.withValues(alpha: 0.10 + 0.30 * progress), base);
    final fg = past ? p.onAccent : zc;
    final stripW = (x.abs() * _width).clamp(0.0, _width);
    return ClipRRect(
      borderRadius: _SheetPanel.radius,
      child: ColoredBox(
        key: const Key('flickSlot'),
        color: fill,
        child: Align(
          alignment: x >= 0 ? Alignment.centerLeft : Alignment.centerRight,
          child: SizedBox(
            width: stripW,
            child: ClipRect(
              child: Center(
                child: OverflowBox(
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: Opacity(
                    opacity: progress,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(past ? Icons.check_circle_rounded : moduleIcon(zone.icon), size: 30, color: fg),
                        const SizedBox(height: 6),
                        Text(
                          _confirmed ? 'Added to ${zone.label}' : zone.label,
                          softWrap: false,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _details(Palette p) => Padding(
    padding: const EdgeInsets.only(top: 2, bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in widget.sections) ...[
          if (s.label.isNotEmpty) ...[
            Text(s.label.toUpperCase(), style: T.caption.copyWith(color: p.text2, letterSpacing: 1)),
            const SizedBox(height: 4),
          ],
          for (final v in s.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SymbolText(v, style: T.body.copyWith(color: p.text)),
            ),
        ],
      ],
    ),
  );
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
                  child: Text(
                    zone.label,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: active ? p.onAccent : p.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One wide "Add to (zone)" / "In (zone)" toggle for modules with a single zone.
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
              Icon(
                active ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                color: active ? p.onAccent : zc,
              ),
              const SizedBox(width: 8),
              Text(
                active ? 'In ${zone.inSentence}' : 'Add to ${zone.inSentence}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: active ? p.onAccent : p.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
