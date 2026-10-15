import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/card.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/animated_card_grid.dart';
import '../widgets/symbols.dart';
import 'card_sheet.dart';

/// Card lookup. All families: one continuous grid. One family: grouped by cost with a
/// right-edge cost rail that jumps to a cost. Family picker sits at the bottom, in thumb reach.
class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  static const _headerH = 36.0;
  static const _sectionGap = 8.0;
  static const _pad = EdgeInsets.fromLTRB(16, 0, 4, 16);

  final _scroll = ScrollController();
  final _search = TextEditingController();
  Family? _family;
  int? _activeCost;

  /// Scroll offset where each cost section starts (filled in during layout).
  final Map<int, double> _sectionOffsets = {};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_trackActiveCost);
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _pickFamily(Family? f) {
    setState(() {
      _family = _family == f ? null : f;
      _activeCost = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _jumpToCost(int cost, {required bool animate}) {
    final o = _sectionOffsets[cost];
    if (o == null || !_scroll.hasClients) return;
    setState(() => _activeCost = cost);
    if (!animate) {
      _scroll.jumpTo(o.clamp(0, _scroll.position.maxScrollExtent));
      return;
    }
    // Keep the tapped cost lit while the list animates past the sections in between.
    _jumping = true;
    _scroll
        .animateTo(o.clamp(0, _scroll.position.maxScrollExtent),
            duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic)
        .whenComplete(() => _jumping = false);
  }

  bool _jumping = false;

  void _trackActiveCost() {
    if (_family == null || _sectionOffsets.isEmpty || _jumping) return;
    int? active;
    for (final e in _sectionOffsets.entries) {
      if (e.value <= _scroll.offset + 4) active = e.key;
    }
    active ??= _sectionOffsets.keys.first;
    if (active != _activeCost) setState(() => _activeCost = active);
  }

  List<GameCard> _filtered(List<GameCard> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((c) {
      if (_family != null && c.family != _family) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.effects.any((e) => e.text.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = context.read<List<GameCard>>();
    final columns = context.watch<Settings>().columns;
    final shown = _filtered(all);
    final costs = {for (final c in shown) c.cost}.toList()..sort();

    return Column(
      children: [
        _TopBar(search: _search),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final gridW = box.maxWidth - _pad.horizontal;
                  return _grid(context, shown, costs, columns, gridW, box.maxHeight);
                }),
              ),
              if (_family != null)
                _CostRail(
                  available: costs.toSet(),
                  active: costs.contains(_activeCost) ? _activeCost : (costs.isEmpty ? null : costs.first),
                  onPick: _jumpToCost,
                ),
            ],
          ),
        ),
        _FamilyDock(selected: _family, count: shown.length, onPick: _pickFamily),
      ],
    );
  }

  Widget _grid(BuildContext context, List<GameCard> shown, List<int> costs, int columns, double gridW,
      double viewH) {
    final p = context.pal;
    if (shown.isEmpty) {
      return Center(
        child: Text('No cards match "${_search.text}".', style: T.body.copyWith(color: p.text2)),
      );
    }
    if (_family == null) {
      _sectionOffsets.clear();
      return ListView(
        controller: _scroll,
        padding: _pad.copyWith(top: 8, right: 16),
        children: [
          AnimatedCardGrid(cards: shown, columns: columns, onTap: (c) => showCardSheet(context, c)),
        ],
      );
    }
    // Grouped by cost with sticky headers; offsets are computed so the rail can jump.
    _sectionOffsets.clear();
    var y = 0.0;
    final slivers = <Widget>[];
    for (final cost in costs) {
      final cards = shown.where((c) => c.cost == cost).toList();
      _sectionOffsets[cost] = y;
      y += _headerH + AnimatedCardGrid.heightFor(cards.length, gridW, columns) + _sectionGap;
      slivers.add(SliverMainAxisGroup(slivers: [
        SliverPersistentHeader(pinned: true, delegate: _CostHeader(cost, p)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: _sectionGap),
            child: AnimatedCardGrid(
                cards: cards, columns: columns, onTap: (c) => showCardSheet(context, c)),
          ),
        ),
      ]));
    }
    // Room after the last section so every cost can scroll to the top (keeps the rail honest).
    final lastH = y - _sectionOffsets[costs.last]!;
    final tail = (viewH - lastH - _pad.bottom).clamp(0.0, double.infinity);
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(padding: _pad, sliver: SliverMainAxisGroup(slivers: slivers)),
        SliverToBoxAdapter(child: SizedBox(height: tail)),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.search});
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final settings = context.watch<Settings>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: search,
                style: T.body.copyWith(color: p.text),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search name or effect',
                  hintStyle: T.body.copyWith(color: p.muted),
                  prefixIcon: Icon(Icons.search_rounded, color: p.muted),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: Icon(Icons.close_rounded, color: p.muted),
                          onPressed: search.clear,
                        ),
                  filled: true,
                  fillColor: p.surface,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                for (final (n, icon) in const [
                  (4, Icons.apps_rounded),
                  (3, Icons.grid_on_rounded),
                  (2, Icons.grid_view_rounded),
                ])
                  Tooltip(
                    message: '$n per row',
                    child: GestureDetector(
                      onTap: () => settings.columns = n,
                      child: AnimatedContainer(
                        key: Key('density$n'),
                        duration: const Duration(milliseconds: 150),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: settings.columns == n ? p.text : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(icon, size: 22, color: settings.columns == n ? p.bg : p.text2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CostHeader extends SliverPersistentHeaderDelegate {
  _CostHeader(this.cost, this.p);
  final int cost;
  final Palette p;

  @override
  double get minExtent => 36;
  @override
  double get maxExtent => 36;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: p.bg,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text('COST $cost', style: T.label.copyWith(color: p.text2)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: p.surface2)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_CostHeader old) => old.cost != cost || old.p != p;
}

/// Always shows 0–12; costs this family doesn't have are dimmed. Tap a cost to jump to it,
/// or press and slide along the rail to scrub through costs (snaps to the nearest one present).
class _CostRail extends StatelessWidget {
  const _CostRail({required this.available, required this.active, required this.onPick});
  final Set<int> available;
  final int? active;

  /// [animate] is false while scrubbing so the grid follows the finger instantly.
  final void Function(int cost, {required bool animate}) onPick;

  static const _pad = EdgeInsets.fromLTRB(3, 4, 5, 12);

  int? _costAt(double dy, double height) {
    if (available.isEmpty) return null;
    final slot = height / 13;
    final n = ((dy - _pad.top) / slot).floor().clamp(0, 12);
    return available.reduce((a, b) => (a - n).abs() <= (b - n).abs() ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight - _pad.vertical;
      void scrub(Offset local, {required bool animate}) {
        final c = _costAt(local.dy, h);
        if (c != null && (c != active || animate)) {
          if (!animate) HapticFeedback.selectionClick();
          onPick(c, animate: animate);
        }
      }

      return GestureDetector(
        key: const Key('costRail'),
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => scrub(d.localPosition, animate: true),
        onVerticalDragStart: (d) => scrub(d.localPosition, animate: false),
        onVerticalDragUpdate: (d) => scrub(d.localPosition, animate: false),
        child: Container(
          width: 36,
          padding: _pad,
          child: Column(
            children: [
              for (var n = 0; n <= 12; n++)
                Expanded(
                  child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 28,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: n == active ? p.text : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      '$n',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: n == active
                            ? p.bg
                            : available.contains(n)
                                ? p.text
                                : p.line,
                      ),
                    ),
                  ),
                ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _FamilyDock extends StatelessWidget {
  const _FamilyDock({required this.selected, required this.count, required this.onPick});
  final Family? selected;
  final int count;
  final void Function(Family?) onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(p.bg, p.surface, 0.45),
        border: Border(top: BorderSide(color: p.surface2)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text('FAMILY', style: T.caption.copyWith(letterSpacing: 1, fontWeight: FontWeight.w700, color: p.muted)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${selected?.label ?? 'All families'} · $count cards',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: T.caption.copyWith(color: p.text2, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FamilyButton(
                label: 'All',
                selected: selected == null,
                onTap: () => onPick(null),
                child: Icon(Icons.apps_rounded, color: p.text, size: 22),
              ),
              for (final f in Family.values)
                _FamilyButton(
                  label: f.label,
                  selected: selected == f,
                  onTap: () => onPick(f),
                  child: FamilySymbol(f, size: 40),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FamilyButton extends StatelessWidget {
  const _FamilyButton({required this.label, required this.selected, required this.onTap, required this.child});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Family $label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 56,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? p.text : Colors.transparent, width: 2.5),
                ),
                child: Container(
                  decoration: BoxDecoration(color: p.surface2, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: child,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? p.text : p.muted,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
