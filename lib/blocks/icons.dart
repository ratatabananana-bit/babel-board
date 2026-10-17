import 'package:flutter/material.dart';

/// Icons a module can name (tabs, zones). Names, not code, so the set is fixed here.
IconData moduleIcon(String name) => switch (name) {
  'cards' => Icons.style_rounded,
  'hand' => Icons.back_hand_rounded,
  'flag' => Icons.flag_rounded,
  'run' => Icons.directions_run_rounded,
  'race' => Icons.sports_score_rounded,
  'table' => Icons.table_restaurant_rounded,
  'grid' => Icons.grid_view_rounded,
  'book' => Icons.menu_book_rounded,
  'list' => Icons.list_alt_rounded,
  'star' => Icons.star_rounded,
  _ => Icons.circle_outlined,
};
