import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets/reflow_grid.dart';
import '../core/widgets/search_top_bar.dart';
import '../module_format/path_expr.dart';
import '../modules/loaded_module.dart';
import 'item_view.dart';

class FilterOption {
  FilterOption(Map<String, dynamic> j)
    : value = j['value'],
      label = j['label'] as String? ?? '${j['value']}',
      symbol = j['symbol'] as String?;
  final Object? value;
  final String label;
  final String? symbol;
}

class FilterSpec {
  FilterSpec(Map<String, dynamic> j)
    : path = j['path'] as String,
      label = j['label'] as String? ?? '',
      allLabel = j['allLabel'] as String? ?? 'All',
      options = [for (final o in (j['options'] as List? ?? const [])) FilterOption((o as Map).cast<String, dynamic>())];
  final String path;
  final String label;
  final String allLabel;
  final List<FilterOption> options;
}

class SectionsSpec {
  SectionsSpec(Map<String, dynamic> j)
    : path = j['path'] as String,
      label = j['label'] as String? ?? '{value}',
      onlyWhenFiltered = j['onlyWhenFiltered'] as bool? ?? false,
      rail = j['rail'] as bool? ?? false,
      railRange = (j['railRange'] as List?)?.cast<int>();
  final String path;
  final String label;
  final bool onlyWhenFiltered;
  final bool rail;
  final List<int>? railRange;
}

/// Settings: `{collection, search: [path], tileName: bool, filters?: [...], sections?: {...}}`.
class GallerySpec {
  GallerySpec(BlockSpec b)
    : collection = b.settings['collection'] as String,
      search = (b.settings['search'] as List?)?.cast<String>() ?? const ['name'],
      tileName = b.settings['tileName'] as bool? ?? true,
      filters = [
        for (final f in (b.settings['filters'] as List? ?? const [])) FilterSpec((f as Map).cast<String, dynamic>()),
      ],
      sections = b.settings['sections'] is Map
          ? SectionsSpec((b.settings['sections'] as Map).cast<String, dynamic>())
          : null,
      noun = b.settings['noun'] as String? ?? 'cards',
      searchHint = b.settings['searchHint'] as String? ?? 'Search ${b.settings['noun'] ?? 'cards'}';

  final String collection;
  final List<String> search;
  final bool tileName;
  final List<FilterSpec> filters;
  final SectionsSpec? sections;

  /// What the summary counts, e.g. "cards".
  final String noun;
  final String searchHint;
}

/// A grid of item pictures with search, density, optional single-select filter docks and
/// optional sections with a jump rail.
class GalleryBlock extends StatefulWidget {
  const GalleryBlock({super.key, required this.spec});
  final BlockSpec spec;

  @override
  State<GalleryBlock> createState() => _GalleryBlockState();
}

class _GalleryBlockState extends State<GalleryBlock> {
  static const _headerH = 30.0;
  static const _sectionGap = 4.0;

  /// Grid padding; the right side plus the rail column make the 32 dp the rail owns.
  static const _pad = EdgeInsets.fromLTRB(16, 0, 4, 16);
  static const _railW = 26.0;
  static const _railEdge = 2.0;

  late GallerySpec _g = GallerySpec(widget.spec);
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
  void didUpdateWidget(GalleryBlock old) {
    super.didUpdateWidget(old);
    if (old.spec != widget.spec) _g = GallerySpec(widget.spec);
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
                  child: _SectionRail(
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
          _FilterDock(
            filter: _g.filters[i],
            selected: _selected[i],
            summary:
                '${_g.filters[i].options.where((o) => o.value == _selected[i]).firstOrNull?.label ?? _g.filters[i].allLabel}'
                ' · ${shown.length} ${_g.noun}',
            onPick: (v) => _pick(i, v),
          ),
      ],
    );
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
  /// picture by [_flowInset] / 2 on both sides). A 16 dp ruler strip above every picture
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
      extra: extra + _FlowCell.rulerH,
      spacing: 0,
      cellInset: _flowInset,
    );
    double leftOf(int i) => (i % columns) * tileW;
    double topOf(int i) => (i ~/ columns) * (tileH + _flowRowGap);
    final duration = context.read<Settings>().anim(ReflowGrid.normalDuration);

    final cells = <String, _FlowCell>{};
    final band = <Widget>[];
    for (var i = 0; i < ordered.length; i++) {
      final it = ordered[i];
      final k = keyOf[it.id];
      final first = i == 0 || keyOf[ordered[i - 1].id] != k;
      final last = i == ordered.length - 1 || keyOf[ordered[i + 1].id] != k;
      if (first) _sectionOffsets[k] = (top + topOf(i) - 4).clamp(0.0, double.infinity);
      (_sectionSpans[k] ??= []).add((top + topOf(i), top + topOf(i) + tileH));
      final picked = k == activeKey;
      cells[it.id] = _FlowCell(
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
      extraHeight: extra + _FlowCell.rulerH,
      spacing: 0,
      runSpacing: _flowRowGap,
      cellInset: _flowInset,
      duration: duration,
      tileBuilder: (it) => cells[it.id]!,
    );
    final totalH = ReflowGrid.heightFor(
      ordered.length,
      gridW,
      columns,
      aspect: spec.cardAspect,
      extra: extra + _FlowCell.rulerH,
      spacing: 0,
      runSpacing: _flowRowGap,
      cellInset: _flowInset,
    );
    final lastStart = (_sectionOffsets[keys.last] ?? 0) - top;
    final tail = (viewH - (totalH - lastStart) - _pad.bottom - top).clamp(0.0, double.infinity);
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: _pad.copyWith(top: top),
          sliver: SliverToBoxAdapter(
            child: Stack(clipBehavior: Clip.none, children: [...band, grid]),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: tail)),
      ],
    );
  }

  /// Flowing layout: the picture is 8 dp narrower than its cell (4 dp a side); rows are 8 dp apart.
  static const _flowInset = 8.0;
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
    final groupW = gridW + _groupPad.left; // the container reaches 6 dp left of the grid, to the sliver edge
    final innerW = groupW - _groupPad.horizontal;
    var y = 0.0;
    final slivers = <Widget>[];
    for (final k in keys) {
      final items = shown.where((it) => resolvePath(it.data, sections.path).firstOrNull == k).toList();
      _sectionOffsets[k] = y;
      final h =
          _headerH +
          _groupPad.vertical +
          2 * _groupBorder +
          ReflowGrid.heightFor(items.length, innerW, columns, aspect: spec.cardAspect, extra: extra) +
          _sectionGap;
      _sectionSpans[k] = [(y, y + h)];
      y += h;
      slivers.add(
        SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _SectionHeader(
                fillTemplate(sections.label, {'value': k}),
                '${items.length} ${_g.noun}',
                p,
                active: k == activeKey,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: _sectionGap),
                child: _SectionPanel(key: Key('section-$k'), active: k == activeKey, child: grid(items)),
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
            padding: _pad.copyWith(left: _pad.left - _groupPad.left),
            sliver: SliverMainAxisGroup(slivers: slivers),
          ),
          SliverToBoxAdapter(child: SizedBox(height: tail)),
        ],
      ),
    );
  }

  /// Grouped layout: the padding every section container keeps, picked or not.
  static const _groupPad = EdgeInsets.symmetric(vertical: 6, horizontal: 6);
  static const _groupBorder = 1.5;

  Widget _scrollWatch(Widget child) =>
      NotificationListener<UserScrollNotification>(onNotification: _onUserScroll, child: child);
}

/// One cell of the flowing layout: the cost ruler strip, then the tile with its side
/// insets. The strip's 2 dp line runs the whole cell width so it joins the neighbours of
/// the same section; the first card of a section starts it with a number pill, the last
/// stops it 6 dp early so the next section reads as separate.
class _FlowCell extends StatelessWidget {
  const _FlowCell({
    required this.item,
    required this.spec,
    required this.collectionId,
    required this.showName,
    required this.label,
    required this.endsRun,
    required this.picked,
  });
  final Item item;
  final CollectionSpec spec;
  final String collectionId;
  final bool showName;

  /// The section's number when this is its first card.
  final String? label;
  final bool endsRun;
  final bool picked;

  /// The strip: a 16 dp pill (or line) plus 6 dp of air before the card, so nothing touches.
  static const pillH = 16.0;
  static const rulerH = pillH + 6;

  /// A run ends this far before the cell edge: well inside the card's rounded corner.
  static const tailGap = 14.0;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final line = picked ? p.accent : p.muted.withValues(alpha: 0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: rulerH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: label == null ? 0 : _GalleryBlockState._flowInset / 2,
                right: endsRun ? tailGap : 0,
                top: pillH / 2 - 1,
                height: 2,
                child: ColoredBox(color: line),
              ),
              if (label != null)
                Positioned(
                  left: _GalleryBlockState._flowInset / 2,
                  top: 0,
                  child: Container(
                    key: Key('cost-pill-$label'),
                    height: pillH,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: picked ? p.accent : p.surface2,
                      borderRadius: BorderRadius.circular(pillH / 2),
                    ),
                    child: Text(
                      label!,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: picked ? p.onAccentFill : p.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _GalleryBlockState._flowInset / 2),
            child: ItemTile(item: item, collection: spec, collectionId: collectionId, showName: showName),
          ),
        ),
      ],
    );
  }
}

/// A section's cards in the grouped layout: the same padding whether picked or not; picked
/// gets a soft accent fill and an inset outline.
class _SectionPanel extends StatelessWidget {
  const _SectionPanel({super.key, required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AnimatedContainer(
      duration: context.read<Settings>().anim(const Duration(milliseconds: 200)),
      padding: _GalleryBlockState._groupPad,
      decoration: BoxDecoration(
        color: active ? p.highlight.withValues(alpha: 0.14) : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? p.highlight.withValues(alpha: 0.7) : Colors.transparent,
          width: _GalleryBlockState._groupBorder,
        ),
      ),
      child: child,
    );
  }
}

/// Sticky separator above a section: label pill, a rule, and the count.
class _SectionHeader extends SliverPersistentHeaderDelegate {
  _SectionHeader(this.label, this.count, this.p, {this.active = false});
  final String label;
  final String count;
  final Palette p;
  final bool active;

  @override
  double get minExtent => _GalleryBlockState._headerH;
  @override
  double get maxExtent => _GalleryBlockState._headerH;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: p.bg,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: active ? p.accent : p.surface2, borderRadius: BorderRadius.circular(10)),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: active ? p.onAccentFill : p.text2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1.5, color: active ? p.accent.withValues(alpha: 0.5) : p.surface2)),
          const SizedBox(width: 8),
          Text(
            count,
            style: T.caption.copyWith(color: p.muted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SectionHeader old) =>
      old.label != label || old.count != count || old.p != p || old.active != active;
}

/// Jump rail: slim, full height, one fixed position per value of the module's range (or
/// per section present), so a cost is always in the same spot. Values the current filter
/// lacks are dots. Press anywhere and slide to scrub (the grid jumps live and a bubble
/// names the cost; releasing picks it), or tap a number.
///
/// Pills: [picked] is filled in the accent; [active] (what fills the screen while you
/// scroll) has a ring; the rest are muted.
class _SectionRail extends StatefulWidget {
  const _SectionRail({
    required this.keys,
    required this.range,
    required this.active,
    required this.picked,
    required this.labelOf,
    required this.onPick,
  });
  final List<Object?> keys;
  final List<int>? range;
  final Object? active;
  final Object? picked;

  /// Text of the scrub bubble for a section.
  final String Function(Object? section) labelOf;

  /// [animate] is false while scrubbing so the grid follows the finger instantly.
  final void Function(Object? section, {required bool animate}) onPick;

  @override
  State<_SectionRail> createState() => _SectionRailState();
}

class _SectionRailState extends State<_SectionRail> {
  static const inset = 6.0;
  static const pill = 22.0;

  /// Finger height while scrubbing (local y), else null.
  double? _scrubY;
  Object? _scrubSection;

  List<Object?> get _slots {
    final r = widget.range;
    if (r != null && r.length == 2 && widget.keys.every((k) => k is int)) {
      return [for (var n = r[0]; n <= r[1]; n++) n];
    }
    return widget.keys;
  }

  Object? _sectionAt(double dy, double height, List<Object?> slots) {
    final keys = widget.keys;
    if (keys.isEmpty || slots.isEmpty) return null;
    final slot = height / slots.length;
    final n = ((dy - inset) / slot).floor().clamp(0, slots.length - 1);
    if (keys.contains(slots[n])) return slots[n];
    // Nearest present section by slot distance.
    Object? best;
    var bestD = 1 << 30;
    for (final k in keys) {
      final d = (slots.indexOf(k) - n).abs();
      if (d < bestD) {
        bestD = d;
        best = k;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final slots = _slots;
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight - inset * 2;
        void scrub(Offset local) {
          final s = _sectionAt(local.dy, h, slots);
          if (s == null) return;
          final changed = s != _scrubSection || _scrubY == null;
          setState(() {
            _scrubY = local.dy.clamp(inset, box.maxHeight - inset);
            _scrubSection = s;
          });
          if (!changed) return;
          if (s != widget.picked) HapticFeedback.selectionClick();
          // Live, no smooth scroll: the grid follows the finger.
          widget.onPick(s, animate: false);
        }

        void release() {
          if (_scrubY != null) setState(() => _scrubY = null);
        }

        final scrubbing = _scrubY != null;
        return GestureDetector(
          key: const Key('sectionRail'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => scrub(d.localPosition),
          onTapUp: (_) => release(),
          onTapCancel: release,
          onVerticalDragStart: (d) => scrub(d.localPosition),
          onVerticalDragUpdate: (d) => scrub(d.localPosition),
          onVerticalDragEnd: (_) => release(),
          onVerticalDragCancel: release,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(vertical: inset),
                decoration: BoxDecoration(
                  color: scrubbing ? p.surface2.withValues(alpha: 0.92) : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  children: [
                    for (final s in slots)
                      Expanded(
                        child: Center(
                          child: widget.keys.contains(s)
                              ? _pill(p, s, picked: s == widget.picked, active: s == widget.active)
                              : Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: p.muted.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              if (scrubbing)
                Positioned(
                  key: const Key('railBubble'),
                  right: box.maxWidth + 8,
                  top: _scrubY! - 22,
                  child: IgnorePointer(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [BoxShadow(blurRadius: 16, offset: Offset(0, 6), color: Colors.black45)],
                      ),
                      child: Text(
                        widget.labelOf(_scrubSection),
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: p.onAccentFill,
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

  Widget _pill(Palette p, Object? s, {required bool picked, required bool active}) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: pill,
    height: pill,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: picked ? p.accent : Colors.transparent,
      shape: BoxShape.circle,
      border: !picked && active ? Border.all(color: p.muted, width: 1.5) : null,
    ),
    child: Text(
      '$s',
      style: TextStyle(
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: picked
            ? p.onAccentFill
            : active
            ? p.text
            : p.muted,
      ),
    ),
  );
}

/// Single-select option dock at the bottom, in thumb reach.
class _FilterDock extends StatelessWidget {
  const _FilterDock({required this.filter, required this.selected, required this.summary, required this.onPick});
  final FilterSpec filter;
  final Object? selected;
  final String summary;
  final void Function(Object?) onPick;

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
                Text(
                  filter.label.toUpperCase(),
                  style: T.caption.copyWith(letterSpacing: 1, fontWeight: FontWeight.w700, color: p.muted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: T.caption.copyWith(color: p.text2, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _OptionRow(
            children: [
              _OptionButton(
                label: 'All',
                semantics: '${filter.label} All',
                selected: selected == null,
                onTap: () => onPick(null),
                child: Icon(Icons.apps_rounded, color: p.text, size: 22),
              ),
              for (final o in filter.options)
                _OptionButton(
                  label: o.label,
                  semantics: '${filter.label} ${o.label}',
                  selected: selected == o.value,
                  onTap: () => onPick(o.value),
                  child: o.symbol == null
                      ? Text(
                          o.label.isEmpty ? '?' : o.label[0],
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.text),
                        )
                      : SymbolImage(o.symbol!, size: 40),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Spreads the option buttons across the dock when they fit (as today with five
/// families); otherwise they scroll sideways so every option stays reachable.
class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (children.length * _OptionButton.width <= box.maxWidth) {
          // Even gaps everywhere, the ends included; on wide screens the row keeps a
          // comfortable width in the middle instead of drifting to the walls.
          final maxW = children.length * _OptionButton.width * 1.6;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW < box.maxWidth ? maxW : box.maxWidth),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: children),
            ),
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: children),
        );
      },
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.semantics,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  static const width = 56.0;
  final String label;
  final String semantics;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      selected: selected,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: width,
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
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? p.text : p.muted,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
