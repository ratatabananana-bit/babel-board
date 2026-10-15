import 'package:flutter/material.dart';

import '../../../core/theme.dart';

enum Zone {
  table('Table', Icons.table_restaurant_rounded, 'Revealed this round'),
  hand('Hand', Icons.back_hand_rounded, 'Taken, not summoned'),
  field('Field', Icons.grid_view_rounded, 'Summoned');

  const Zone(this.label, this.icon, this.hint);
  final String label;
  final IconData icon;

  /// Short reminder of what the zone means, shown in its lane header.
  final String hint;
}

/// Zone colors: Table amber, Hand mint, Field violet.
extension ZoneColors on Palette {
  Color zone(Zone z) => switch (z) {
        Zone.table => amber,
        Zone.hand => mint,
        Zone.field => violet,
      };
}
