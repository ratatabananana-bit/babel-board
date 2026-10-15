import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/card.dart';
import '../models/zone.dart';
import '../state/tracker.dart';
import '../theme.dart';
import '../widgets/card_art.dart';
import '../widgets/confirm.dart';
import '../widgets/dashed_border.dart';
import '../widgets/symbols.dart';
import 'card_sheet.dart';

/// Marker for the Remove drop target.
const _remove = 'remove';

/// What is being dragged and what it is over, shared by every drop target for visuals.
class _Drag extends ChangeNotifier {
  String? id;
  Zone? from;

  /// A [Zone], [_remove], or null.
  Object? over;

  bool get active => id != null;

  void start(String cardId, Zone zone) {
    id = cardId;
    from = zone;
    over = null;
    notifyListeners();
  }

  void hover(Object? target) {
    if (over == target) return;
    over = target;
    notifyListeners();
  }

  void end() {
    id = null;
    from = null;
    over = null;
    notifyListeners();
  }
}

/// Your cards as a board: one colored lane per zone. Long-press a card and drag it to
/// another lane (or onto a card to place it before that card), or onto the bar at the top.
class MyCardsScreen extends StatefulWidget {
  const MyCardsScreen({super.key});

  @override
  State<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends State<MyCardsScreen> {
  final _drag = _Drag();
  final _scroll = ScrollController();
  final _listKey = GlobalKey();
  final Set<Zone> _collapsed = {};

  @override
  void dispose() {
    _drag.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the list while a dragged card is held near its top or bottom edge.
  void _autoScroll(DragUpdateDetails d) {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_scroll.hasClients) return;
    final y = box.globalToLocal(d.globalPosition).dy;
    final pos = _scroll.position;
    if (y < 30) {
      _scroll.jumpTo((pos.pixels - 12).clamp(0, pos.maxScrollExtent));
    } else if (y > box.size.height - 50) {
      _scroll.jumpTo((pos.pixels + 12).clamp(0, pos.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<Tracker>();
    final byId = {for (final c in context.read<List<GameCard>>()) c.id: c};

    // Claims horizontal drags so they don't swipe to another tab.
    return GestureDetector(
      onHorizontalDragStart: (_) {},
      child: ListenableBuilder(
        listenable: _drag,
        builder: (context, _) => Column(
          children: [
            SizedBox(
              height: 60,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _drag.active
                    ? _DropDock(key: const ValueKey('dock'), drag: _drag)
                    : _Header(key: const ValueKey('header'), total: tracker.total),
              ),
            ),
            Expanded(
              child: ListView(
                key: _listKey,
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                children: [
                  for (final z in Zone.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _Lane(
                        zone: z,
                        cards: [for (final id in tracker.idsIn(z)) ?byId[id]],
                        drag: _drag,
                        open: !_collapsed.contains(z) || _drag.active,
                        onToggle: () => setState(
                            () => _collapsed.contains(z) ? _collapsed.remove(z) : _collapsed.add(z)),
                        onDragUpdate: _autoScroll,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({super.key, required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final tracker = context.read<Tracker>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 4, 0),
      child: Row(
        children: [
          const Text('My cards', style: T.title),
          const SizedBox(width: 10),
          Expanded(child: Text('$total tracked', style: T.body.copyWith(color: p.text2))),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(Icons.more_vert_rounded, color: p.text2),
            onSelected: (v) async {
              switch (v) {
                case 'all':
                  final ok = await confirm(context, 'Clear all your cards?',
                      'Removes every card from Table, Hand and Field.', 'Clear all');
                  if (ok) tracker.clearAll();
                default:
                  tracker.clearZone(Zone.values.byName(v));
              }
            },
            itemBuilder: (_) => [
              for (final z in Zone.values)
                PopupMenuItem(value: z.name, child: Text('Clear ${z.label}')),
              PopupMenuItem(
                value: 'all',
                child: Text('Clear everything', style: TextStyle(color: p.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Table / Hand / Field / Remove targets that replace the header while dragging.
class _DropDock extends StatelessWidget {
  const _DropDock({super.key, required this.drag});
  final _Drag drag;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final tracker = context.read<Tracker>();
    Widget target(Object key, String label, IconData icon, Color c) {
      final isSrc = key == drag.from;
      final hot = drag.over == key && !isSrc;
      return Expanded(
        child: DragTarget<String>(
          onWillAcceptWithDetails: (_) => !isSrc,
          onMove: (_) => drag.hover(key),
          onLeave: (_) => drag.hover(null),
          onAcceptWithDetails: (d) =>
              key == _remove ? tracker.remove(d.data) : tracker.put(d.data, key as Zone),
          builder: (context, _, _) {
            final box = AnimatedContainer(
              key: Key('drop-$key'),
              duration: const Duration(milliseconds: 100),
              height: 48,
              decoration: BoxDecoration(
                color: hot ? c : (isSrc ? Colors.transparent : p.text.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(14),
                border: isSrc ? Border.all(color: p.surface2, width: 2) : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 19, color: hot ? p.onAccent : (isSrc ? p.line : c)),
                    const SizedBox(width: 4),
                    Text(label,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: hot ? p.onAccent : (isSrc ? p.line : c))),
                  ],
                ),
              ),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: isSrc || hot ? box : DashedBorder(color: c, radius: 14, child: box),
            );
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
      child: Row(
        children: [
          for (final z in Zone.values) target(z, z.label, z.icon, p.zone(z)),
          target(_remove, 'Remove', Icons.delete_rounded, p.danger),
        ],
      ),
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    required this.zone,
    required this.cards,
    required this.drag,
    required this.open,
    required this.onToggle,
    required this.onDragUpdate,
  });

  final Zone zone;
  final List<GameCard> cards;
  final _Drag drag;
  final bool open;
  final VoidCallback onToggle;
  final void Function(DragUpdateDetails) onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final zc = p.zone(zone);
    final isSrc = drag.from == zone;
    final target = drag.active && !isSrc;
    final hot = target && drag.over == zone;
    final tracker = context.read<Tracker>();

    final lane = DragTarget<String>(
      onWillAcceptWithDetails: (_) => drag.from != zone,
      onMove: (_) => drag.hover(zone),
      onLeave: (_) => drag.hover(null),
      onAcceptWithDetails: (d) => tracker.put(d.data, zone),
      builder: (context, _, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
        decoration: BoxDecoration(
          color: zc.withValues(alpha: hot ? 0.2 : 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: hot ? zc : Colors.transparent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 42,
                child: Row(
                  children: [
                    const SizedBox(width: 6),
                    Icon(zone.icon, size: 19, color: zc),
                    const SizedBox(width: 8),
                    Text(zone.label, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Container(
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: zc, borderRadius: BorderRadius.circular(10)),
                      child: Text('${cards.length}',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w800, color: p.onAccent)),
                    ),
                    Expanded(
                      child: Text(
                        hot
                            ? 'Release to drop here'
                            : target
                                ? 'Drop here'
                                : zone.hint,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: T.caption.copyWith(color: target ? zc : p.muted),
                      ),
                    ),
                    Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: p.muted),
                  ],
                ),
              ),
            ),
            if (open && cards.isEmpty)
              DashedBorder(
                color: p.line,
                child: SizedBox(
                  height: 64,
                  child: Center(child: Text('Drag cards here', style: T.body.copyWith(color: p.muted, fontSize: 14))),
                ),
              ),
            if (open)
              for (var i = 0; i < cards.length; i += 2)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _MiniCard(card: cards[i], zone: zone, drag: drag, onDragUpdate: onDragUpdate)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: i + 1 < cards.length
                              ? _MiniCard(card: cards[i + 1], zone: zone, drag: drag, onDragUpdate: onDragUpdate)
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
    // Always wrapped (transparent when idle) so the DragTarget is never rebuilt mid-hover;
    // swapping the wrapper in and out made hovering flicker and drops miss.
    return DashedBorder(color: target && !hot ? zc : Colors.transparent, radius: 18, child: lane);
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.card, required this.zone, required this.drag, required this.onDragUpdate});

  final GameCard card;
  final Zone zone;
  final _Drag drag;
  final void Function(DragUpdateDetails) onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final tracker = context.read<Tracker>();
    void onStart() {
      HapticFeedback.mediumImpact();
      drag.start(card.id, zone);
    }

    Offset anchor(Draggable<Object> d, BuildContext c, Offset o) => const Offset(92, 36);
    final feedback = _Ghost(card: card, drag: drag);
    final placeholder = DashedBorder(color: p.line, child: const SizedBox(height: 84));

    // A mouse picks the card up as soon as it moves; a finger needs a short hold first so
    // that a normal swipe still scrolls the list.
    return _MouseDraggable<String>(
      data: card.id,
      dragAnchorStrategy: anchor,
      onDragStarted: onStart,
      onDragUpdate: onDragUpdate,
      onDragEnd: (_) => drag.end(),
      feedback: feedback,
      childWhenDragging: placeholder,
      child: LongPressDraggable<String>(
      data: card.id,
      delay: const Duration(milliseconds: 220),
      dragAnchorStrategy: anchor,
      onDragStarted: onStart,
      onDragUpdate: onDragUpdate,
      onDragEnd: (_) => drag.end(),
      feedback: feedback,
      childWhenDragging: placeholder,
      // Dropping onto a card places the dragged card just before it (in this card's zone).
      child: DragTarget<String>(
        onWillAcceptWithDetails: (d) => d.data != card.id,
        onMove: (_) => drag.hover(zone),
        onLeave: (_) => drag.hover(null),
        onAcceptWithDetails: (d) => tracker.put(d.data, zone, beforeId: card.id),
        builder: (context, candidates, _) => Stack(
          // Passthrough so the card takes the row's stretched height (equal-height pairs).
          fit: StackFit.passthrough,
          children: [
            _MiniCardBody(card: card, onTap: () => showCardSheet(context, card)),
            if (candidates.isNotEmpty)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: p.zone(zone), borderRadius: BorderRadius.circular(2)),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }
}

/// Draggable that starts immediately, for mouse pointers only.
class _MouseDraggable<D extends Object> extends Draggable<D> {
  const _MouseDraggable({
    required super.child,
    required super.feedback,
    super.data,
    super.childWhenDragging,
    super.dragAnchorStrategy,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDragEnd,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(GestureMultiDragStartCallback onStart) =>
      ImmediateMultiDragGestureRecognizer(supportedDevices: {PointerDeviceKind.mouse})..onStart = onStart;
}

class _MiniCardBody extends StatelessWidget {
  const _MiniCardBody({required this.card, this.onTap});
  final GameCard card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(width: 40, child: CardArt(card, radius: 8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(card.name,
                        style: const TextStyle(fontSize: 14, height: 1.2, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final e in card.effects)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: EffectSymbol(e.type, size: 16),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(e.text,
                            style: TextStyle(fontSize: 13, height: 1.3, color: p.text.withValues(alpha: 0.9))),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lifted card: tilted, raised, ringed in the color of the target under the finger.
class _Ghost extends StatelessWidget {
  const _Ghost({required this.card, required this.drag});
  final GameCard card;
  final _Drag drag;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListenableBuilder(
      listenable: drag,
      builder: (context, _) {
        final over = drag.over;
        final ring = over is Zone
            ? p.zone(over)
            : over == _remove
                ? p.danger
                : p.text;
        return Transform.rotate(
          angle: -0.07,
          child: Transform.scale(
            scale: 1.05,
            child: Container(
              width: 176,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  const BoxShadow(blurRadius: 48, offset: Offset(0, 24), color: Colors.black54),
                  BoxShadow(spreadRadius: 2, color: ring),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: _MiniCardBody(card: card),
              ),
            ),
          ),
        );
      },
    );
  }
}
