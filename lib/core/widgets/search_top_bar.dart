import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game_switcher.dart';
import '../settings.dart';
import '../theme.dart';

/// Top row of a picture-grid tab: game switcher, search field, and the 4 / 3 / 2 per-row toggle.
class SearchTopBar extends StatelessWidget {
  const SearchTopBar({super.key, required this.search, this.hint = 'Search name or effect'});
  final TextEditingController search;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final settings = context.watch<Settings>();
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
