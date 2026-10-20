import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game_switcher.dart';
import '../settings.dart';
import '../theme.dart';

/// Top row of a picture-grid tab: game switcher, the search field (all the remaining
/// width), and an optional [trailing] control such as the [ViewPill].
class SearchTopBar extends StatelessWidget {
  const SearchTopBar({
    super.key,
    required this.search,
    this.hint = 'Search cards',
    this.trailing,
    this.keyboardType = TextInputType.text,
  });
  final TextEditingController search;
  final String hint;
  final Widget? trailing;

  /// The keypad the field opens: numbers for games found by printed number.
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 8),
      child: Row(
        children: [
          const GameSwitcherButton(),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: search,
                style: T.body.copyWith(color: p.text),
                keyboardType: keyboardType,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: hint,
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// One pill with the view controls: card size (a grid icon plus S / M / L; tapping cycles
/// small → medium → large; the per-row count depends on the screen) and, when the grid
/// has sections, the grouped / flowing layout switch, whose icon shows the current layout.
class ViewPill extends StatelessWidget {
  const ViewPill({super.key, this.onLayoutChanged});

  /// Null hides the layout switch (galleries without sections).
  final VoidCallback? onLayoutChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final settings = context.watch<Settings>();
    final n = settings.columns;
    final choices = Settings.columnChoices;
    final next = choices[(choices.indexOf(n) + 1) % choices.length];
    final flowing = settings.flowingSections;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillButton(
            key: const Key('densityCycle'),
            tooltip: '${Settings.sizeLabel(n)} cards · tap for ${Settings.sizeLabel(next).toLowerCase()}',
            semantics: '${Settings.sizeLabel(n)} cards',
            onTap: () => settings.columns = next,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.grid_view_rounded, size: 20, color: p.text),
                const SizedBox(width: 4),
                Text(
                  Settings.sizeLetter(n),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: p.text,
                  ),
                ),
              ],
            ),
          ),
          if (onLayoutChanged != null)
            _PillButton(
              key: const Key('layoutToggle'),
              tooltip: flowing ? 'Flowing grid · tap for cost groups' : 'Cost groups · tap for a flowing grid',
              semantics: flowing ? 'Flowing grid' : 'Cost groups',
              onTap: () {
                settings.flowingSections = !flowing;
                onLayoutChanged!();
              },
              child: Icon(flowing ? Icons.view_quilt_rounded : Icons.view_agenda_rounded, size: 20, color: p.text),
            ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({super.key, required this.tooltip, required this.semantics, required this.onTap, required this.child});
  final String tooltip;
  final String semantics;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: semantics,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            height: 40,
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
