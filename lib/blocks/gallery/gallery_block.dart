import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';

import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../core/widgets/reflow_grid.dart';
import '../../core/widgets/search_top_bar.dart';
import '../../module_format/block_specs.dart';
import '../../module_format/path_expr.dart';
import '../../modules/loaded_module.dart';
import '../item_tile.dart';
import 'filter_dock.dart';
import 'layouts.dart';
import 'rail.dart';

/// A grid of item pictures with search, density, optional single-select filter docks and
/// optional sections with a jump rail.
class GalleryBlock extends StatefulWidget {
  const GalleryBlock({super.key, required this.spec});
  final GallerySpec spec;

  @override
  State<GalleryBlock> createState() => _GalleryBlockState();
}

class _GalleryBlockState extends State<GalleryBlock> {
  static const _headerH = kSectionHeaderH;
  static const _sectionGap = 4.0;

  /// Grid padding; the right side plus the rail column make the 32 dp the rail owns.
  static const _pad = EdgeInsets.fromLTRB(16, 0, 4, 16);
  static const _railW = 26.0;
  static const _railEdge = 2.0;

  GallerySpec get _g => widget.spec;
  final _scroll = ScrollController();
  final _search = TextEditingController();

  /// Selected option value per filter index.
  final Map<int, Object?> _selected = {};

  /// Where you are: the section the rail lights up. Follows your scrolling.
  Object? _activeSection;

  /// What you picked: the section picked on the rail. Its cards stay highlighted while you
  /// scroll, until you pick another section or another filter.
  Object? _picked;

  /// True while a finger (or mouse wheel) is scrolling, so jumps made by the rail don't
  /// move the rail's own light.
  bool _userScrolling = false;

  /// Scroll offset where each section starts (filled in during layout).
  final Map<Object?, double> _sectionOffsets = {};

  /// The vertical ranges each section covers, in scroll content coordinates: one range per
  /// group when grouped, one per card when flowing. Used to find the most visible section.
  final Map<Object?, List<(double, double)>> _sectionSpans = {};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_trackActiveSection);
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _filtered => _selected.values.any((v) => v != null);

  void _pick(int filter, Object? value) {
    setState(() {
      _selected[filter] = _selected[filter] == value ? null : value;
      _activeSection = null;
      _picked = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _jumpTo(Object? section, {required bool animate}) {
    final o = _sectionOffsets[section];
    if (o == null || !_scroll.hasClients) return;
    setState(() {
      _activeSection = section;
      _picked = section;
    });
    final target = o.clamp(0.0, _scroll.position.maxScrollExtent);
    if (!animate) {
      _scroll.jumpTo(target);
      return;
    }
    final d = context.read<Settings>().anim(const Duration(milliseconds: 250));
    if (d == Duration.zero) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: d, curve: Curves.easeOutCubic);
    }
  }

  /// Rail jumps aren't user scrolls, so only a finger or wheel moves the rail's light.
  bool _onUserScroll(UserScrollNotification n) {
    _userScrolling = n.direction != ScrollDirection.idle;
    if (!_userScrolling) _trackActiveSection(force: true);
    return false;
  }

  /// Lights the section that fills the most of the screen, so a sliver of a group at the
  /// top never wins. On a tie the current one stays, else the topmost.
  void _trackActiveSection({bool force = false}) {
    if (_sectionSpans.isEmpty || !_scroll.hasClients || !(_userScrolling || force)) return;
    final top = _scroll.offset;
    final bottom = top + _scroll.position.viewportDimension;
    final scores = <Object?, double>{};
    for (final e in _sectionSpans.entries) {
      var s = 0.0;
      for (final (a, b) in e.value) {
        final overlap = (b < bottom ? b : bottom) - (a > top ? a : top);
        if (overlap > 0) s += overlap;
      }
      scores[e.key] = s;
    }
    final best = scores.values.fold(0.0, (m, s) => s > m ? s : m);
    if (best <= 0) return;
    final tied = [
      for (final e in scores.entries)
        if (best - e.value < 0.5) e.key,
    ];
    final active = tied.contains(_activeSection) ? _activeSection : tied.first;
    if (active != _activeSection) setState(() => _activeSection = active);
  }

  List<Item> _shown(List<Item> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((it) {
      for (var i = 0; i < _g.filters.length; i++) {
        final v = _selected[i];
        if (v != null && !resolvePath(it.data, _g.filters[i].path).any((x) => x == v)) return false;
      }
      if (q.isEmpty) return true;
      return _g.search.any((p) => resolvePath(it.data, p).any((v) => '$v'.toLowerCase().contains(q)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final module = context.read<LoadedModule>();
    final spec = module.manifest.collections[_g.collection];
    if (spec == null) return Center(child: Text('Unknown collection "${_g.collection}"', style: T.body));
    final columns = Settings.columnsFor(context.watch<Settings>().columns, MediaQuery.sizeOf(context).width);
    final shown = _shown(module.items(_g.collection));
    final sections = _g.sections;
    final sectioned = sections != null && (!sections.onlyWhenFiltered || _filtered);
    final keys = sectioned ? _sectionKeys(shown, sections.path) : const <Object?>[];

    final rail = sectioned && sections.rail;
    return Column(
      children: [
        SearchTopBar(
          search: _search,
          hint: _g.searchHint,
          trailing: ViewPill(onLayoutChanged: sections == null ? null : _relayout),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final gridW = box.maxWidth - _pad.horizontal;
                    return _grid(
                      context,
                      spec,
                      shown,
                      sectioned ? sections : null,
                      keys,
                      columns,
                      gridW,
                      box.maxHeight,
                    );
                  },
                ),
              ),
              if (rail) ...[
                SizedBox(
                  width: _railW,
                  child: SectionRail(
                    keys: keys,
                    range: sections.railRange,
                    active: keys.contains(_activeSection) ? _activeSection : (keys.isEmpty ? null : keys.first),
                    picked: keys.contains(_picked) ? _picked : null,
                    labelOf: (k) => _bubbleLabel(sections, k),
                    onPick: _jumpTo,
                  ),
                ),
                const SizedBox(width: _railEdge),
              ],
            ],
          ),
        ),
        for (var i = 0; i < _g.filters.length; i++)
          FilterDock(filter: _g.filters[i], selected: _selected[i], onPick: (v) => _pick(i, v)),
      ],
    );
  }

  /// "1 card", "3 cards": the module's noun, singular for one (plain English plurals only).
  String _countOf(int n) {
    final noun = _g.noun;
    final one = noun.endsWith('s') && noun.length > 1 ? noun.substring(0, noun.length - 1) : noun;
    return '$n ${n == 1 ? one : noun}';
  }

  /// The scrub bubble's text: the section label in sentence case ("COST 3" → "Cost 3").
  static String _bubbleLabel(SectionsSpec sections, Object? k) {
    final s = fillTemplate(sections.label, {'value': k}).trim();
    if (s.isEmpty || s != s.toUpperCase()) return s;
    return s[0] + s.substring(1).toLowerCase();
  }

  /// After switching layouts the offsets change: back to the top, keeping the picked cost.
  void _relayout() {
    setState(() => _activeSection = null);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// One continuous grid in section order with even gutters (cells touch; each pads its
  /// picture by [kFlowInset] / 2 on both sides). A 16 dp ruler strip above every picture
  /// carries a 2 dp line that runs across the cells of one section, with the section's
  /// number at its start and a gap before the next section. The picked section's cards sit
  /// on one continuous band, like a text selection. Offsets put a section's ruler at the top
  /// of the viewport.
  Widget _flowing(
    BuildContext context,
    CollectionSpec spec,
    List<Item> shown,
    SectionsSpec sections,
    List<Object?> keys,
    Object? activeKey,
    int columns,
    double gridW,
    double viewH,
    double extra,
  ) {
    final p = context.pal;
    const top = 8.0;
    final keyOf = {for (final it in shown) it.id: resolvePath(it.data, sections.path).firstOrNull};
    final ordered = [for (final k in keys) ...shown.where((it) => keyOf[it.id] == k)];
    final tileW = ReflowGrid.tileWidth(gridW, columns, spacing: 0);
    final tileH = ReflowGrid.tileHeight(
      gridW,
      columns,
      aspect: spec.cardAspect,
      extra: extra + FlowCell.rulerH,
      spacing: 0,
      cellInset: kFlowInset,
    );
    double leftOf(int i) => (i % columns) * tileW;
    double topOf(int i) => (i ~/ columns) * (tileH + _flowRowGap);
    final duration = context.read<Settings>().anim(ReflowGrid.normalDuration);

    final cells = <String, FlowCell>{};
    final band = <Widget>[];
    for (var i = 0; i < ordered.length; i++) {
      final it = ordered[i];
      final k = keyOf[it.id];
      final first = i == 0 || keyOf[ordered[i - 1].id] != k;
      final last = i == ordered.length - 1 || keyOf[ordered[i + 1].id] != k;
      if (first) _sectionOffsets[k] = (top + topOf(i) - 4).clamp(0.0, double.infinity);
      (_sectionSpans[k] ??= []).add((top + topOf(i), top + topOf(i) + tileH));
      final picked = k == activeKey;
      cells[it.id] = FlowCell(
        item: it,
        spec: spec,
        collectionId: _g.collection,
        showName: _g.tileName,
        label: first ? '$k' : null,
        endsRun: last,
        picked: picked,
      );
      if (picked) {
        final col = i % columns;
        final roundLeft = first || col == 0;
        final roundRight = last || col == columns - 1;
        band.add(
          AnimatedPositioned(
            key: Key('hl-${it.id}'),
            duration: duration,
            curve: ReflowGrid.curve,
            left: leftOf(i),
            top: topOf(i),
            width: tileW,
            height: tileH,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.highlight.withValues(alpha: 0.22),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(roundLeft ? 10 : 0),
                  right: Radius.circular(roundRight ? 10 : 0),
                ),
              ),
            ),
          ),
        );
      }
    }
    final grid = ReflowGrid<Item>(
      items: ordered,
      idOf: (it) => it.id,
      columns: columns,
      aspect: spec.cardAspect,
      extraHeight: extra + FlowCell.rulerH,
      spacing: 0,
      runSpacing: _flowRowGap,
      cellInset: kFlowInset,
      duration: duration,
      tileBuilder: (it) => cells[it.id]!,
    );
    final totalH = ReflowGrid.heightFor(
      ordered.length,
      gridW,
      columns,
      aspect: spec.cardAspect,
      extra: extra + FlowCell.rulerH,
      spacing: 0,
      runSpacing: _flowRowGap,
      cellInset: kFlowInset,
    );
    final lastStart = (_sectionOffsets[keys.last] ?? 0) - top;
    final tail = (viewH - (totalH - lastStart) - _pad.bottom - top).clamp(0.0, double.infinity);
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: _pad.copyWith(top: top),
          sliver: SliverToBoxAdapter(child: Stack(clipBehavior: Clip.none, children: [...band, grid])),
        ),
        SliverToBoxAdapter(child: SizedBox(height: tail)),
      ],
    );
  }

  static const _flowRowGap = 8.0;

  /// Distinct section values in display order: numbers ascending, else by first appearance.
  List<Object?> _sectionKeys(List<Item> shown, String path) {
    final keys = <Object?>[];
    for (final it in shown) {
      final v = resolvePath(it.data, path).firstOrNull;
      if (!keys.contains(v)) keys.add(v);
    }
    if (keys.every((k) => k is num)) keys.sort((a, b) => (a as num).compareTo(b as num));
    return keys;
  }

  Widget _grid(
    BuildContext context,
    CollectionSpec spec,
    List<Item> shown,
    SectionsSpec? sections,
    List<Object?> keys,
    int columns,
    double gridW,
    double viewH,
  ) {
    final p = context.pal;
    final extra = _g.tileName ? ItemTile.nameHeight : 0.0;
    Widget grid(List<Item> items) => ReflowGrid<Item>(
      items: items,
      idOf: (it) => it.id,
      columns: columns,
      aspect: spec.cardAspect,
      extraHeight: extra,
      duration: context.read<Settings>().anim(ReflowGrid.normalDuration),
      tileBuilder: (it) => ItemTile(item: it, collection: spec, collectionId: _g.collection, showName: _g.tileName),
    );
    if (shown.isEmpty) {
      return Center(
        child: Text('No ${_g.noun} match "${_search.text}".', style: T.body.copyWith(color: p.text2)),
      );
    }
    _sectionOffsets.clear();
    _sectionSpans.clear();
    if (sections == null) {
      return ListView(controller: _scroll, padding: _pad.copyWith(top: 8, right: 16), children: [grid(shown)]);
    }
    // Highlighted cards: only what was picked on the rail (and is still shown).
    final activeKey = keys.contains(_picked) ? _picked : null;
    if (context.read<Settings>().flowingSections) {
      return _scrollWatch(_flowing(context, spec, shown, sections, keys, activeKey, columns, gridW, viewH, extra));
    }
    // Grouped: a sticky header per section, then its cards in a container whose padding
    // never changes, so the pick only recolors it. Offsets let the rail jump.
    // The container reaches 6 dp left of the grid, to the sliver edge; its border and
    // padding sit inside that width.
    final groupW = gridW + kGroupPad.left;
    final innerW = groupW - kGroupPad.horizontal - 2 * kGroupBorder;
    var y = 0.0;
    final slivers = <Widget>[];
    for (final k in keys) {
      final items = shown.where((it) => resolvePath(it.data, sections.path).firstOrNull == k).toList();
      _sectionOffsets[k] = y;
      // Header (with the top border) + body (padding, cards, padding, bottom border) + gap.
      final h =
          _headerH +
          ReflowGrid.heightFor(items.length, innerW, columns, aspect: spec.cardAspect, extra: extra) +
          kGroupPad.vertical +
          kGroupBorder +
          _sectionGap;
      _sectionSpans[k] = [(y, y + h)];
      y += h;
      slivers.add(
        SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: SectionHeader(
                fillTemplate(sections.label, {'value': k}),
                _countOf(items.length),
                p,
                active: k == activeKey,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: _sectionGap),
                child: SectionPanel(key: Key('section-$k'), active: k == activeKey, child: grid(items)),
              ),
            ),
          ],
        ),
      );
    }
    // Room after the last section so every section can scroll to the top (keeps the rail honest).
    final lastH = y - _sectionOffsets[keys.last]!;
    final tail = (viewH - lastH - _pad.bottom).clamp(0.0, double.infinity);
    return _scrollWatch(
      CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverPadding(
            padding: _pad.copyWith(left: _pad.left - kGroupPad.left),
            sliver: SliverMainAxisGroup(slivers: slivers),
          ),
          SliverToBoxAdapter(child: SizedBox(height: tail)),
        ],
      ),
    );
  }


  /// Watches for real user scrolls, and hides the platform scrollbar: the rail is the
  /// scrollbar here.
  Widget _scrollWatch(Widget child) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: NotificationListener<UserScrollNotification>(onNotification: _onUserScroll, child: child),
  );
}

