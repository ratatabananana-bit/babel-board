import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../module_format/block_specs.dart';
import '../item_picture.dart';

/// A dock with more options than this becomes a picker button (a searchable sheet).
const kDockPickerLimit = 8;

/// Single-select option dock at the bottom, in thumb reach: just the option buttons with
/// their labels (the picked one is ringed), nothing else. Past [kDockPickerLimit] options
/// a pill row would scroll off the screen, so the dock is one button that opens a
/// searchable sheet of the same options.
class FilterDock extends StatelessWidget {
  const FilterDock({
    super.key,
    required this.filter,
    required this.selected,
    required this.onPick,
  });
  final FilterSpec filter;
  final Object? selected;
  final void Function(Object?) onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final picker = filter.options.length > kDockPickerLimit;
    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(p.bg, p.surface, 0.45),
        border: Border(top: BorderSide(color: p.surface2)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: picker
          ? _DockPickerButton(filter: filter, selected: selected, onPick: onPick)
          : _OptionRow(children: _options(context, filter, selected, onPick)),
    );
  }
}

/// All, then one button per option (optionally only those matching [query]).
List<Widget> _options(
  BuildContext context,
  FilterSpec filter,
  Object? selected,
  void Function(Object?) onPick, {
  String query = '',
}) {
  final p = context.pal;
  final q = query.trim().toLowerCase();
  return [
    if (q.isEmpty)
      _OptionButton(
        label: 'All',
        semantics: '${filter.label} All',
        selected: selected == null,
        onTap: () => onPick(null),
        child: Icon(Icons.apps_rounded, color: p.text, size: 22),
      ),
    for (final o in filter.options)
      if (q.isEmpty || o.label.toLowerCase().contains(q))
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
  ];
}

/// The dock for a long option list: "Class: Brute ▾"; tap opens [_DockPickerSheet].
class _DockPickerButton extends StatelessWidget {
  const _DockPickerButton({required this.filter, required this.selected, required this.onPick});
  final FilterSpec filter;
  final Object? selected;
  final void Function(Object?) onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final current = filter.options.where((o) => o.value == selected).firstOrNull;
    final text = '${filter.label}: ${current?.label ?? filter.allLabel}';
    return Material(
      color: p.surface2,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: p.bg,
          builder: (_) => _DockPickerSheet(
            filter: filter,
            selected: selected,
            onPick: (v) {
              onPick(v);
              Navigator.of(context).pop();
            },
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              if (current?.symbol != null) ...[SymbolImage(current!.symbol!, size: 24), const SizedBox(width: 10)],
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.expand_more_rounded, color: p.text2),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockPickerSheet extends StatefulWidget {
  const _DockPickerSheet({required this.filter, required this.selected, required this.onPick});
  final FilterSpec filter;
  final Object? selected;
  final void Function(Object?) onPick;

  @override
  State<_DockPickerSheet> createState() => _DockPickerSheetState();
}

class _DockPickerSheetState extends State<_DockPickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final options = _options(context, widget.filter, widget.selected, widget.onPick, query: _query.text);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: T.body.copyWith(color: p.text),
              decoration: InputDecoration(
                hintText: 'Search ${widget.filter.label.toLowerCase()}',
                hintStyle: T.body.copyWith(color: p.muted),
                prefixIcon: Icon(Icons.search_rounded, color: p.muted),
                filled: true,
                fillColor: p.surface,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                childAspectRatio: 56 / 72,
                children: options,
              ),
            ),
          ],
        ),
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
