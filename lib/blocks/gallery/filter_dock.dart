import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../module_format/block_specs.dart';
import '../item_picture.dart';

/// Single-select option dock at the bottom, in thumb reach: just the option buttons with
/// their labels (the picked one is ringed), nothing else.
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
    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(p.bg, p.surface, 0.45),
        border: Border(top: BorderSide(color: p.surface2)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: _OptionRow(
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
