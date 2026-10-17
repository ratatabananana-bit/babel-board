import 'package:flutter/material.dart';
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
        filters = [for (final f in (b.settings['filters'] as List? ?? const [])) FilterSpec((f as Map).cast<String, dynamic>())],
        sections = b.settings['sections'] is Map ? SectionsSpec((b.settings['sections'] as Map).cast<String, dynamic>()) : null,
        noun = b.settings['noun'] as String? ?? 'cards';

  final String collection;
  final List<String> search;
  final bool tileName;
  final List<FilterSpec> filters;
  final SectionsSpec? sections;

  /// What the summary counts, e.g. "cards".
  final String noun;
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
  Object? _activeSection;
  bool _jumping = false;

  /// Scroll offset where each section starts (filled in during layout).
  final Map<Object?, double> _sectionOffsets = {};

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
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _jumpTo(Object? section, {required bool animate}) {
    final o = _sectionOffsets[section];
    if (o == null || !_scroll.hasClients) return;
    setState(() => _activeSection = section);
    final target = o.clamp(0.0, _scroll.position.maxScrollExtent);
    if (!animate) {
      _scroll.jumpTo(target);
      return;
    }
    // Keep the tapped section lit while the list animates past the ones in between.
    _jumping = true;
    _scroll
        .animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic)
        .whenComplete(() => _jumping = false);
  }

  void _trackActiveSection() {
    if (_sectionOffsets.isEmpty || _jumping) return;
    Object? active;
    for (final e in _sectionOffsets.entries) {
      if (e.value <= _scroll.offset + 4) active = e.key;
    }
    active ??= _sectionOffsets.keys.first;
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
    final columns = context.watch<Settings>().columns;
    final shown = _shown(module.items(_g.collection));
    final sections = _g.sections;
    final sectioned = sections != null && (!sections.onlyWhenFiltered || _filtered);
    final keys = sectioned ? _sectionKeys(shown, sections.path) : const <Object?>[];

    return Column(
      children: [
        SearchTopBar(search: _search, hint: 'Search ${_g.noun}'),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final gridW = box.maxWidth - _pad.horizontal;
                  return _grid(context, spec, shown, sectioned ? sections : null, keys, columns, gridW, box.maxHeight);
                }),
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
            summary: '${_g.filters[i].options.where((o) => o.value == _selected[i]).firstOrNull?.label ?? _g.filters[i].allLabel}'
                ' · ${shown.length} ${_g.noun}',
            onPick: (v) => _pick(i, v),
          ),
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

  Widget _grid(BuildContext context, CollectionSpec spec, List<Item> shown, SectionsSpec? sections,
      List<Object?> keys, int columns, double gridW, double viewH) {
    final p = context.pal;
    final extra = _g.tileName ? ItemTile.nameHeight : 0.0;
    Widget grid(List<Item> items) => ReflowGrid<Item>(
          items: items,
          idOf: (it) => it.id,
          columns: columns,
          aspect: spec.cardAspect,
          extraHeight: extra,
          tileBuilder: (it) => ItemTile(item: it, collection: spec, collectionId: _g.collection, showName: _g.tileName),
        );
    if (shown.isEmpty) {
      return Center(child: Text('No ${_g.noun} match "${_search.text}".', style: T.body.copyWith(color: p.text2)));
    }
    _sectionOffsets.clear();
    if (sections == null) {
      return ListView(
        controller: _scroll,
        padding: _pad.copyWith(top: 8, right: 16),
        children: [grid(shown)],
      );
    }
    // Grouped with sticky headers; offsets are computed so the rail can jump.
    var y = 0.0;
    final slivers = <Widget>[];
    for (final k in keys) {
      final items = shown.where((it) => resolvePath(it.data, sections.path).firstOrNull == k).toList();
      _sectionOffsets[k] = y;
      y += _headerH + ReflowGrid.heightFor(items.length, gridW, columns, aspect: spec.cardAspect, extra: extra) + _sectionGap;
      slivers.add(SliverMainAxisGroup(slivers: [
        SliverPersistentHeader(pinned: true, delegate: _SectionHeader(fillTemplate(sections.label, {'value': k}), p)),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(bottom: _sectionGap), child: grid(items))),
      ]));
    }
    // Room after the last section so every section can scroll to the top (keeps the rail honest).
    final lastH = y - _sectionOffsets[keys.last]!;
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

class _SectionHeader extends SliverPersistentHeaderDelegate {
  _SectionHeader(this.label, this.p);
  final String label;
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
          Text(label, style: T.label.copyWith(color: p.text2)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: p.surface2)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SectionHeader old) => old.label != label || old.p != p;
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
    return LayoutBuilder(builder: (context, box) {
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
    });
  }
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
                Text(filter.label.toUpperCase(),
                    style: T.caption.copyWith(letterSpacing: 1, fontWeight: FontWeight.w700, color: p.muted)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(summary,
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
                      ? Text(o.label.isEmpty ? '?' : o.label[0],
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.text))
                      : SymbolImage(o.symbol!, size: 40),
                ),
            ],
          ),
        ],
      ),
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
