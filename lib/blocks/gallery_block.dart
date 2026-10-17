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
  static const _headerH = 36.0;
  static const _sectionGap = 8.0;
  static const _pad = EdgeInsets.fromLTRB(16, 0, 4, 16);

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

    return Column(
      children: [
        SearchTopBar(search: _search, hint: _g.searchHint),
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
              if (sectioned && sections.rail)
                _SectionRail(
                  keys: keys,
                  range: sections.railRange,
                  active: keys.contains(_activeSection) ? _activeSection : (keys.isEmpty ? null : keys.first),
                  onPick: _jumpTo,
                ),
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
            trailing: i == 0 && sectioned ? _LayoutToggle(onChanged: _relayout) : null,
          ),
      ],
    );
  }

  /// After switching layouts the offsets change; start again at the top of the first section.
  void _relayout() {
    setState(() => _activeSection = null);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// One continuous grid in section order. A bar with a small badge marks where each
  /// section starts; the active section's cards sit on soft panels. Offsets are the start
  /// rows, so the rail scrolls to the row where a section begins.
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
    Widget Function(List<Item>) grid,
  ) {
    final p = context.pal;
    const top = 16.0; // room for the badges above the first row
    final keyOf = {for (final it in shown) it.id: resolvePath(it.data, sections.path).firstOrNull};
    final ordered = [for (final k in keys) ...shown.where((it) => keyOf[it.id] == k)];
    final tileW = ReflowGrid.tileWidth(gridW, columns);
    final tileH = tileW / spec.cardAspect + extra;
    double leftOf(int i) => (i % columns) * (tileW + ReflowGrid.spacing);
    double topOf(int i) => (i ~/ columns) * (tileH + ReflowGrid.runSpacing);

    final overlays = <Widget>[];
    final panels = <Widget>[];
    Object? previous = const Object();
    for (var i = 0; i < ordered.length; i++) {
      final k = keyOf[ordered[i].id];
      if (k != previous) {
        previous = k;
        _sectionOffsets[k] = topOf(i);
        final x = leftOf(i) - ReflowGrid.spacing / 2;
        overlays.add(
          AnimatedPositioned(
            key: Key('sep-$k'),
            duration: context.read<Settings>().anim(ReflowGrid.normalDuration),
            curve: ReflowGrid.curve,
            left: x - 12,
            top: topOf(i) - 14,
            width: 24,
            height: tileH + 14,
            child: _FlowSeparator(label: '$k', active: k == activeKey),
          ),
        );
      }
      // Content coordinates include the top padding above the grid.
      (_sectionSpans[k] ??= []).add((top + topOf(i), top + topOf(i) + tileH));
      if (k == activeKey) {
        panels.add(
          AnimatedPositioned(
            key: Key('hl-${ordered[i].id}'),
            duration: context.read<Settings>().anim(ReflowGrid.normalDuration),
            curve: ReflowGrid.curve,
            left: leftOf(i) - 4,
            top: topOf(i) - 4,
            width: tileW + 8,
            height: tileH + 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.surface2.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        );
      }
    }
    final totalH = ReflowGrid.heightFor(ordered.length, gridW, columns, aspect: spec.cardAspect, extra: extra);
    final lastStart = _sectionOffsets[keys.last] ?? 0;
    final tail = (viewH - (totalH - lastStart) - _pad.bottom - top).clamp(0.0, double.infinity);
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: _pad.copyWith(top: top),
          sliver: SliverToBoxAdapter(
            child: Stack(clipBehavior: Clip.none, children: [...panels, grid(ordered), ...overlays]),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: tail)),
      ],
    );
  }

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
      return _scrollWatch(
        _flowing(context, spec, shown, sections, keys, activeKey, columns, gridW, viewH, extra, grid),
      );
    }
    // Grouped with sticky headers; offsets are computed so the rail can jump.
    var y = 0.0;
    final slivers = <Widget>[];
    for (final k in keys) {
      final items = shown.where((it) => resolvePath(it.data, sections.path).firstOrNull == k).toList();
      _sectionOffsets[k] = y;
      final h =
          _headerH +
          ReflowGrid.heightFor(items.length, gridW, columns, aspect: spec.cardAspect, extra: extra) +
          _sectionGap;
      _sectionSpans[k] = [(y, y + h)];
      y += h;
      slivers.add(
        SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _SectionHeader(fillTemplate(sections.label, {'value': k}), p, active: k == activeKey),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: _sectionGap),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The selected section sits on a soft panel; it is drawn outside the grid's
                    // box, so section heights (and the rail's jump offsets) don't change.
                    Positioned(
                      left: -6,
                      right: -6,
                      top: -4,
                      bottom: -4,
                      child: _SectionPanel(key: Key('section-$k'), active: k == activeKey),
                    ),
                    grid(items),
                  ],
                ),
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
            padding: _pad,
            sliver: SliverMainAxisGroup(slivers: slivers),
          ),
          SliverToBoxAdapter(child: SizedBox(height: tail)),
        ],
      ),
    );
  }

  Widget _scrollWatch(Widget child) =>
      NotificationListener<UserScrollNotification>(onNotification: _onUserScroll, child: child);
}

/// Two-way switch between cost groups (a header per cost) and one flowing grid.
class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final settings = context.watch<Settings>();
    final flowing = settings.flowingSections;
    Widget seg(bool forFlowing, IconData icon, String tip) {
      final on = flowing == forFlowing;
      return Tooltip(
        message: tip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: on
              ? null
              : () {
                  settings.flowingSections = forFlowing;
                  onChanged();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 26,
            decoration: BoxDecoration(color: on ? p.text : Colors.transparent, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, size: 17, color: on ? p.bg : p.text2),
          ),
        ),
      );
    }

    return GestureDetector(
      key: const Key('layoutToggle'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        settings.flowingSections = !flowing;
        onChanged();
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(15)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            seg(false, Icons.view_agenda_rounded, 'Group by cost'),
            seg(true, Icons.view_comfy_rounded, 'One flowing grid'),
          ],
        ),
      ),
    );
  }
}

/// Where a section starts in the flowing layout: a thin bar in the gap before its first
/// card, with the section's value in a small badge on top.
class _FlowSeparator extends StatelessWidget {
  const _FlowSeparator({required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return IgnorePointer(
      child: Column(
        children: [
          Container(
            height: 22,
            constraints: const BoxConstraints(minWidth: 22),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: active ? p.text : p.surface2, shape: BoxShape.circle),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: active ? p.bg : p.text,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: active ? p.text : p.text2.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Background panel behind the selected section's cards (neutral: accents are for zones).
class _SectionPanel extends StatelessWidget {
  const _SectionPanel({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: context.read<Settings>().anim(const Duration(milliseconds: 200)),
    decoration: BoxDecoration(
      color: active ? context.pal.surface2.withValues(alpha: 0.7) : null,
      borderRadius: BorderRadius.circular(14),
    ),
  );
}

class _SectionHeader extends SliverPersistentHeaderDelegate {
  _SectionHeader(this.label, this.p, {this.active = false});
  final String label;
  final Palette p;
  final bool active;

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
          Text(
            label,
            style: T.label.copyWith(color: active ? p.text : p.text2, fontWeight: active ? FontWeight.w800 : null),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(height: active ? 2 : 1, color: active ? p.text2 : p.surface2),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SectionHeader old) => old.label != label || old.p != p || old.active != active;
}

/// Jump rail: every value of the range (or every present section); absent ones are dimmed.
/// Tap to jump, or press and slide to scrub (snaps to the nearest section present).
class _SectionRail extends StatelessWidget {
  const _SectionRail({required this.keys, required this.range, required this.active, required this.onPick});
  final List<Object?> keys;
  final List<int>? range;
  final Object? active;

  /// [animate] is false while scrubbing so the grid follows the finger instantly.
  final void Function(Object? section, {required bool animate}) onPick;

  static const _pad = EdgeInsets.fromLTRB(3, 4, 5, 12);

  List<Object?> get _slots {
    final r = range;
    if (r != null && r.length == 2 && keys.every((k) => k is int)) {
      return [for (var n = r[0]; n <= r[1]; n++) n];
    }
    return keys;
  }

  Object? _sectionAt(double dy, double height, List<Object?> slots) {
    if (keys.isEmpty || slots.isEmpty) return null;
    final slot = height / slots.length;
    final n = ((dy - _pad.top) / slot).floor().clamp(0, slots.length - 1);
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
        final h = box.maxHeight - _pad.vertical;
        void scrub(Offset local, {required bool animate}) {
          final s = _sectionAt(local.dy, h, slots);
          if (s != null && (s != active || animate)) {
            if (!animate) HapticFeedback.selectionClick();
            onPick(s, animate: animate);
          }
        }

        return GestureDetector(
          key: const Key('sectionRail'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => scrub(d.localPosition, animate: true),
          onVerticalDragStart: (d) => scrub(d.localPosition, animate: false),
          onVerticalDragUpdate: (d) => scrub(d.localPosition, animate: false),
          child: Container(
            width: 36,
            padding: _pad,
            child: Column(
              children: [
                for (final s in slots)
                  Expanded(
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 28,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s == active ? p.text : Colors.transparent,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          '$s',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: s == active
                                ? p.bg
                                : keys.contains(s)
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
      },
    );
  }
}

/// Single-select option dock at the bottom, in thumb reach.
class _FilterDock extends StatelessWidget {
  const _FilterDock({
    required this.filter,
    required this.selected,
    required this.summary,
    required this.onPick,
    this.trailing,
  });
  final FilterSpec filter;
  final Object? selected;
  final String summary;
  final void Function(Object?) onPick;

  /// Shown at the end of the summary row (the grouped/flowing layout switch).
  final Widget? trailing;

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
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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
