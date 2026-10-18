import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/game_switcher.dart';
import 'symbol_text.dart';
import '../core/theme.dart';
import '../core/widgets/confirm.dart';
import '../core/widgets/dashed_border.dart';
import '../module_format/filter.dart';
import '../module_format/path_expr.dart';
import '../modules/loaded_module.dart';
import '../modules/module_state.dart';
import 'icons.dart';
import 'item_view.dart';

/// Marker for the Remove drop target.
const _remove = 'remove';

/// `cardList` settings: `{collection, style: mini|rows|thumbs, columns?, filter?, removable?}`.
class CardListSpec {
  CardListSpec(Map<String, dynamic> s)
    : collection = s['collection'] as String? ?? '',
      style = s['style'] as String? ?? 'mini',
      columns = (s['columns'] as num?)?.toInt() ?? 2,
      filter = s['filter'] is Map ? ItemFilter.fromJson((s['filter'] as Map).cast<String, dynamic>()) : null,
      removable = s['removable'] as bool? ?? false,
      emptyText = s['emptyText'] as String?;

  final String collection;
  final String style;
  final int columns;
  final ItemFilter? filter;
  final bool removable;

  /// Shown in the lane when it has no items (and nothing can be dragged in).
  final String? emptyText;

  static CardListSpec? fromSetting(Object? v) => v is Map ? CardListSpec(v.cast<String, dynamic>()) : null;
}

/// One lane of a board: a declared zone plus how its items are listed.
class LaneSpec {
  LaneSpec({required this.zone, required this.list});
  final ZoneSpec zone;
  final CardListSpec list;
}

/// `board` settings: `{title, countLabel: template with {count}, children: [zone]}`.
class BoardSpec {
  BoardSpec(BlockSpec b, LoadedModule module)
    : title = b.settings['title'] as String? ?? 'Board',
      countLabel = b.settings['countLabel'] as String? ?? '{count} tracked',
      lanes = [
        for (final c in b.children)
          if (c.type == 'zone')
            if (zoneSpec(module, c.settings['zone'] as String?) case final z?)
              LaneSpec(
                zone: z,
                list:
                    CardListSpec.fromSetting(c.settings['list']) ??
                    CardListSpec({'collection': module.manifest.collections.keys.firstOrNull ?? ''}),
              ),
      ];

  final String title;
  final String countLabel;
  final List<LaneSpec> lanes;
}

/// What is being dragged and what it is over, shared by every drop target for visuals.
class _Drag extends ChangeNotifier {
  String? id;
  String? from;

  /// A zone id, [_remove], or null.
  Object? over;

  bool get active => id != null;

  void start(String itemId, String zone) {
    id = itemId;
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

/// Your items as a board: one colored lane per zone. Long-press (or mouse-drag) a card to
/// another lane, onto a card to place it before that card, or onto the bar at the top.
class BoardBlock extends StatefulWidget {
  const BoardBlock({super.key, required this.spec});
  final BlockSpec spec;

  @override
  State<BoardBlock> createState() => _BoardBlockState();
}

class _BoardBlockState extends State<BoardBlock> {
  final _drag = _Drag();
  final _scroll = ScrollController();
  final _listKey = GlobalKey();
  final Set<String> _collapsed = {};

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
    final module = context.read<LoadedModule>();
    final board = BoardSpec(widget.spec, module);
    final zones = context.watch<ZoneState>();
    // A single lane has nowhere to drag to, so it gets no drop bar and no drag.
    final draggable = board.lanes.length > 1;
    final total = board.lanes.fold(0, (n, l) => n + zones.count(l.zone.id));

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
                child: _drag.active && draggable
                    ? _DropDock(key: const ValueKey('dock'), drag: _drag, lanes: board.lanes)
                    : _Header(key: const ValueKey('header'), board: board, total: total),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                key: _listKey,
                controller: _scroll,
                slivers: [
                  SliverPadding(
                    // Room at the end so the last card clears the bottom bar and a snackbar.
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        for (final lane in board.lanes)
                          ..._Lane(
                            lane: lane,
                            items: _itemsIn(module, zones, lane),
                            drag: draggable ? _drag : null,
                            open: !_collapsed.contains(lane.zone.id) || _drag.active,
                            onToggle: () => setState(
                              () => _collapsed.contains(lane.zone.id)
                                  ? _collapsed.remove(lane.zone.id)
                                  : _collapsed.add(lane.zone.id),
                            ),
                            onDragUpdate: _autoScroll,
                            flat: !draggable,
                          ).slivers(context),
                      ],
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

List<Item> _itemsIn(LoadedModule module, ZoneState zones, LaneSpec lane) => [
  for (final id in zones.idsIn(lane.zone.id))
    if (module.item(lane.list.collection, id) case final it?)
      if (lane.list.filter?.matches(it.data, lane.zone.id) ?? true) it,
];

/// Empties [zone] at once and shows a snackbar whose Undo puts the cards back, in order.
void clearZoneWithUndo(BuildContext context, ZoneSpec zone) {
  final zones = context.read<ZoneState>();
  final removed = zones.idsIn(zone.id);
  if (removed.isEmpty) return;
  zones.clearZone(zone.id);
  final p = context.pal;
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      backgroundColor: p.accent,
      duration: const Duration(seconds: 5),
      content: Text(
        '${zone.label} cleared',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.onAccentFill),
      ),
      persist: false,
      action: SnackBarAction(
        label: 'Undo',
        textColor: p.onAccentFill,
        onPressed: () {
          for (final id in removed) {
            // Leave alone a card that was put somewhere else in the meantime.
            if (zones.zoneOf(id) == null) zones.put(id, zone.id);
          }
        },
      ),
    ),
  );
}

/// Small "Clear" pill in a lane header; dimmed and inert when the lane is empty.
class _ClearPill extends StatelessWidget {
  const _ClearPill({super.key, required this.color, required this.onTap});
  final Color color;

  /// Null when there is nothing to clear.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Clear',
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Text(
              'Clear',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({super.key, required this.board, required this.total});
  final BoardSpec board;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final zones = context.read<ZoneState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
      child: Row(
        children: [
          const GameSwitcherButton(),
          const SizedBox(width: 10),
          // Title and count take their natural width (shrinking only when space runs out);
          // the rest of the row stays empty so the menu sits at the far right.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(board.title, style: T.title, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    fillTemplate(board.countLabel, {'count': total}),
                    style: T.body.copyWith(color: p.text2),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // One lane: a plain Clear button, as on the old This race screen.
          if (board.lanes.length == 1) ...[
            if (total > 0)
              TextButton(
                onPressed: () => clearZoneWithUndo(context, board.lanes.single.zone),
                child: const Text('Clear'),
              ),
            const SizedBox(width: 4),
          ] else
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: Icon(Icons.more_vert_rounded, color: p.text2),
              onSelected: (v) async {
                if (v == '*') {
                  final labels = board.lanes.map((l) => l.zone.label).join(', ');
                  final ok = await confirm(
                    context,
                    'Clear everything?',
                    'Removes every card from $labels.',
                    'Clear all',
                  );
                  if (ok) {
                    for (final l in board.lanes) {
                      zones.clearZone(l.zone.id);
                    }
                  }
                } else {
                  zones.clearZone(v);
                }
              },
              itemBuilder: (_) => [
                for (final l in board.lanes) PopupMenuItem(value: l.zone.id, child: Text('Clear ${l.zone.label}')),
                PopupMenuItem(
                  value: '*',
                  child: Text('Clear everything', style: TextStyle(color: p.danger)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Zone targets plus Remove that replace the header while dragging.
class _DropDock extends StatelessWidget {
  const _DropDock({super.key, required this.drag, required this.lanes});
  final _Drag drag;
  final List<LaneSpec> lanes;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final zones = context.read<ZoneState>();
    Widget target(Object key, String label, IconData icon, Color c) {
      final isSrc = key == drag.from;
      final hot = drag.over == key && !isSrc;
      return Expanded(
        child: DragTarget<String>(
          onWillAcceptWithDetails: (_) => !isSrc,
          onMove: (_) => drag.hover(key),
          onLeave: (_) => drag.hover(null),
          onAcceptWithDetails: (d) => key == _remove ? zones.remove(d.data) : zones.put(d.data, key as String),
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
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: hot ? p.onAccent : (isSrc ? p.line : c),
                      ),
                    ),
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
          for (final l in lanes) target(l.zone.id, l.zone.label, moduleIcon(l.zone.icon), zoneColor(context, l.zone)),
          target(_remove, 'Remove', Icons.delete_rounded, p.danger),
        ],
      ),
    );
  }
}

/// One lane: a sticky header (icon, name, count, collapse chevron on the left; Clear on
/// the right) and its cards below, both on the zone's tint. Builds slivers so the header
/// stays pinned while a long lane scrolls, keeping Clear in reach.
class _Lane {
  const _Lane({
    required this.lane,
    required this.items,
    required this.drag,
    required this.open,
    required this.onToggle,
    required this.onDragUpdate,
    this.flat = false,
  });

  final LaneSpec lane;
  final List<Item> items;

  /// A single-lane board draws its list plainly: no lane header or tint, since the
  /// board header already names it.
  final bool flat;

  /// Null when the board has a single lane (nothing to drag between).
  final _Drag? drag;
  final bool open;
  final VoidCallback onToggle;
  final void Function(DragUpdateDetails) onDragUpdate;

  static const headerH = 44.0;
  static const radius = 18.0;

  List<Widget> slivers(BuildContext context) {
    final p = context.pal;
    final zone = lane.zone;
    final zc = zoneColor(context, zone);
    final drag = this.drag;
    final isSrc = drag?.from == zone.id;
    final target = (drag?.active ?? false) && !isSrc;
    final hot = target && drag!.over == zone.id;
    final zones = context.read<ZoneState>();
    final module = context.read<LoadedModule>();
    final spec = module.manifest.collections[lane.list.collection];
    final canDrag = drag != null && lane.list.style != 'rows';
    // Opaque tint (the header is pinned, cards scroll under it).
    final tint = Color.alphaBlend(zc.withValues(alpha: hot ? 0.2 : 0.07), p.bg);

    Widget content() {
      if (spec == null) return Text('Unknown collection "${lane.list.collection}"', style: T.body);
      if (items.isEmpty) {
        return canDrag
            ? DashedBorder(
                color: p.line,
                child: SizedBox(
                  height: 64,
                  child: Center(
                    child: Text('Drag cards here', style: T.body.copyWith(color: p.muted, fontSize: 14)),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  lane.list.emptyText ?? 'Nothing in ${zone.inSentence} yet. Add items from their sheet.',
                  textAlign: TextAlign.center,
                  style: T.body.copyWith(color: p.muted, fontSize: 14),
                ),
              );
      }
      switch (lane.list.style) {
        case 'rows':
          return Column(
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: _RowCard(item: items[i], spec: spec, lane: lane),
                ),
            ],
          );
        default:
          final cols = lane.list.columns.clamp(1, 6);
          return Column(
            children: [
              for (var i = 0; i < items.length; i += cols)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var j = 0; j < cols; j++) ...[
                          if (j > 0) const SizedBox(width: 6),
                          Expanded(
                            child: i + j < items.length
                                ? _MiniCard(
                                    item: items[i + j],
                                    spec: spec,
                                    lane: lane,
                                    drag: drag,
                                    onDragUpdate: onDragUpdate,
                                  )
                                : const SizedBox(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
      }
    }

    if (flat) {
      return [
        SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: content()),
        ),
      ];
    }

    final dragging = drag?.active ?? false;
    final header = Material(
      color: tint,
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(radius),
        bottom: Radius.circular(open ? 0 : radius),
      ),
      child: SizedBox(
        height: headerH,
        child: Row(
          children: [
            // The whole icon + name + count + chevron group is the collapse button.
            Semantics(
              button: true,
              label: open ? 'Collapse ${zone.label}' : 'Expand ${zone.label}',
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(moduleIcon(zone.icon), size: 19, color: zc),
                      const SizedBox(width: 8),
                      Text(zone.label, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Container(
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: zc, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '${items.length}',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: p.onAccent),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 22, color: p.muted),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                hot
                    ? 'Release to drop here'
                    : target
                    ? 'Drop here'
                    : zone.hint ?? '',
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: T.caption.copyWith(color: target ? zc : p.muted, fontSize: 12),
              ),
            ),
            // One tap clears the lane; the snackbar offers Undo. Hidden only while dragging.
            if (!dragging) ...[
              const SizedBox(width: 8),
              _ClearPill(
                key: Key('clear-${zone.id}'),
                color: zc,
                onTap: items.isEmpty ? null : () => clearZoneWithUndo(context, zone),
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
      ),
    );

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(radius)),
      ),
      child: content(),
    );

    // Header and body are separate slivers, so each is its own drop target. The dashed
    // "drop here" outline goes on the body (or the header when the lane is collapsed).
    Widget asTarget(Widget child, {required bool dashed}) {
      if (drag == null) return child;
      // Always wrapped (transparent when idle) so the DragTarget is never rebuilt mid-hover;
      // swapping the wrapper in and out made hovering flicker and drops miss.
      return DashedBorder(
        color: dashed && target && !hot ? zc : Colors.transparent,
        radius: radius,
        child: DragTarget<String>(
          onWillAcceptWithDetails: (_) => drag.from != zone.id,
          onMove: (_) => drag.hover(zone.id),
          onLeave: (_) => drag.hover(null),
          onAcceptWithDetails: (d) => zones.put(d.data, zone.id),
          builder: (context, _, _) => child,
        ),
      );
    }

    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: _PinnedHeader(headerH, asTarget(header, dashed: !open)),
      ),
      if (open) SliverToBoxAdapter(child: asTarget(body, dashed: true)),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];
  }
}

/// A fixed-height sticky header built from any widget.
class _PinnedHeader extends SliverPersistentHeaderDelegate {
  const _PinnedHeader(this.height, this.child);
  final double height;
  final Widget child;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(_PinnedHeader old) => true;
}

/// The text lines under an item's name: its effects (symbol + text) or its sections.
List<Widget> _detailLines(BuildContext context, Item item, CollectionSpec spec, {required double size}) {
  final p = context.pal;
  final sheet = SheetSpec(spec.sheet);
  final e = sheet.effects;
  if (e != null) {
    final symbols = (e['typeSymbols'] as Map?)?.cast<String, dynamic>() ?? const {};
    return [
      for (final raw in resolvePath(item.data, e['path'] as String? ?? 'effects'))
        if (raw is Map)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (symbols[raw['type']] is String) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: SymbolImage(symbols[raw['type']] as String, size: size + 3),
                  ),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: SymbolText(
                    '${raw['text'] ?? ''}',
                    style: TextStyle(fontSize: size, height: 1.3, color: p.text.withValues(alpha: 0.9)),
                  ),
                ),
              ],
            ),
          ),
    ];
  }
  // Without effects, the first section (e.g. the ability text) is what a list row shows.
  final first = sheet.sections.firstOrNull;
  if (first == null) return const [];
  return [
    for (final v in resolvePath(item.data, first['path'] as String? ?? ''))
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          '$v',
          style: TextStyle(fontSize: size, height: 1.35, color: p.text),
        ),
      ),
  ];
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.item,
    required this.spec,
    required this.lane,
    required this.drag,
    required this.onDragUpdate,
  });

  final Item item;
  final CollectionSpec spec;
  final LaneSpec lane;
  final _Drag? drag;
  final void Function(DragUpdateDetails) onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final zones = context.read<ZoneState>();
    final zone = lane.zone;
    final zc = zoneColor(context, zone);
    final thumbs = lane.list.style == 'thumbs';
    final body = thumbs
        ? GestureDetector(
            onTap: () => showItemSheet(context, item, lane.list.collection),
            child: ItemPicture(item, spec, radius: 10),
          )
        : _MiniCardBody(item: item, spec: spec, onTap: () => showItemSheet(context, item, lane.list.collection));
    final drag = this.drag;
    if (drag == null) return body;

    void onStart() {
      HapticFeedback.mediumImpact();
      drag.start(item.id, zone.id);
    }

    Offset anchor(Draggable<Object> d, BuildContext c, Offset o) => const Offset(92, 36);
    final feedback = _Ghost(item: item, spec: spec, drag: drag, thumbs: thumbs);
    final placeholder = DashedBorder(color: p.line, child: const SizedBox(height: 84));

    // Dropping onto a card places the dragged card just before it (in this card's zone).
    final target = DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != item.id,
      onMove: (_) => drag.hover(zone.id),
      onLeave: (_) => drag.hover(null),
      onAcceptWithDetails: (d) => zones.put(d.data, zone.id, beforeId: item.id),
      builder: (context, candidates, _) => Stack(
        // Passthrough so the card takes the row's stretched height (equal-height pairs).
        fit: StackFit.passthrough,
        children: [
          body,
          if (candidates.isNotEmpty)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(color: zc, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ],
      ),
    );

    // A mouse picks the card up as soon as it moves; a finger needs a short hold first so
    // that a normal swipe still scrolls the list.
    return _MouseDraggable<String>(
      data: item.id,
      dragAnchorStrategy: anchor,
      onDragStarted: onStart,
      onDragUpdate: onDragUpdate,
      onDragEnd: (_) => drag.end(),
      feedback: feedback,
      childWhenDragging: placeholder,
      child: LongPressDraggable<String>(
        data: item.id,
        delay: const Duration(milliseconds: 220),
        dragAnchorStrategy: anchor,
        onDragStarted: onStart,
        onDragUpdate: onDragUpdate,
        onDragEnd: (_) => drag.end(),
        feedback: feedback,
        childWhenDragging: placeholder,
        child: target,
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
  const _MiniCardBody({required this.item, required this.spec, this.onTap});
  final Item item;
  final CollectionSpec spec;
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
                  SizedBox(width: 40, child: ItemPicture(item, spec, radius: 8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title(spec),
                      style: const TextStyle(fontSize: 14, height: 1.2, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ..._detailLines(context, item, spec, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width row: picture, name, subtitle, every detail line, and optionally a remove button.
class _RowCard extends StatelessWidget {
  const _RowCard({required this.item, required this.spec, required this.lane});
  final Item item;
  final CollectionSpec spec;
  final LaneSpec lane;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final subtitle = item.subtitle(spec);
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showItemSheet(context, item, lane.list.collection),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 64, child: ItemPicture(item, spec, radius: 8, artOnly: true)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title(spec), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: p.text2),
                      ),
                    const SizedBox(height: 4),
                    ..._detailLines(context, item, spec, size: 15.5),
                  ],
                ),
              ),
              if (lane.list.removable)
                IconButton(
                  tooltip: 'Remove from ${lane.zone.inSentence}',
                  icon: Icon(Icons.close_rounded, color: p.muted),
                  onPressed: () => context.read<ZoneState>().remove(item.id),
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
  const _Ghost({required this.item, required this.spec, required this.drag, required this.thumbs});
  final Item item;
  final CollectionSpec spec;
  final _Drag drag;
  final bool thumbs;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final module = context.read<LoadedModule>();
    return ListenableBuilder(
      listenable: drag,
      builder: (context, _) {
        final over = drag.over;
        final overZone = over is String ? zoneSpec(module, over) : null;
        final ring = overZone != null
            ? zoneColor(context, overZone)
            : over == _remove
            ? p.danger
            : p.text;
        return Transform.rotate(
          angle: -0.07,
          child: Transform.scale(
            scale: 1.05,
            child: Container(
              width: thumbs ? 120 : 176,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  const BoxShadow(blurRadius: 48, offset: Offset(0, 24), color: Colors.black54),
                  BoxShadow(spreadRadius: 2, color: ring),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: thumbs ? ItemPicture(item, spec, radius: 10) : _MiniCardBody(item: item, spec: spec),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A `cardList` used on its own (not inside a zone): the items matching its filter.
class CardListBlock extends StatelessWidget {
  const CardListBlock({super.key, required this.spec});
  final BlockSpec spec;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final module = context.read<LoadedModule>();
    final zones = context.watch<ZoneState>();
    final list = CardListSpec(spec.settings);
    final cs = module.manifest.collections[list.collection];
    if (cs == null) return Center(child: Text('Unknown collection "${list.collection}"', style: T.body));
    final filter = list.filter;
    final source = filter?.zone != null
        ? [for (final id in zones.idsIn(filter!.zone!)) ?module.item(list.collection, id)]
        : module.items(list.collection);
    final items = [
      for (final it in source)
        if (filter?.matches(it.data, zones.zoneOf(it.id)) ?? true) it,
    ];
    final zone =
        zoneSpec(module, filter?.zone) ??
        ZoneSpec(id: '', label: spec.settings['title'] as String? ?? '', icon: 'list', accent: 'amber');
    final lane = LaneSpec(zone: zone, list: list);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nothing here yet.',
              textAlign: TextAlign.center,
              style: T.body.copyWith(color: p.muted),
            ),
          ),
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: list.style == 'rows'
                ? _RowCard(item: it, spec: cs, lane: lane)
                : _MiniCardBody(item: it, spec: cs, onTap: () => showItemSheet(context, it, list.collection)),
          ),
      ],
    );
  }
}
