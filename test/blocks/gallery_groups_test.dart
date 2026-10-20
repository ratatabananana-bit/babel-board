import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/blocks/item_sheet.dart';
import 'package:vale_helper/blocks/item_tile.dart';
import 'package:vale_helper/core/app_state.dart';

import '../helpers.dart';

/// The mini gallery grouped by family through a `families` collection, with a cost
/// subtitle on tiles and the number keypad for search.
Future<AppState> pumpGrouped(WidgetTester tester) => pumpModules(
  tester,
  edit: (m) {
    (m['collections'] as Map)['families'] = {
      'items': [
        {'id': 'fire', 'name': 'Fire', 'image': 'images/fire.webp'},
        {'id': 'water', 'name': 'Water', 'image': 'images/water.webp'},
      ],
    };
    final g = (m['tabs'] as List)[0]['block'] as Map;
    g['groups'] = {'path': 'family', 'by': 'families', 'noun': 'families'};
    g['tileSubtitle'] = 'Cost {cost}';
    g['searchKeyboard'] = 'number';
    g.remove('filters');
  },
);

void main() {
  testWidgets('group screen first, then that group, then back to all groups', (tester) async {
    await pumpGrouped(tester);
    expect(find.bySemanticsLabel('Fire'), findsOneWidget);
    expect(find.bySemanticsLabel('Water'), findsOneWidget);
    expect(find.bySemanticsLabel('Imp'), findsNothing);
    expect(find.text('2 families'), findsNothing, reason: 'no count line, the tiles speak for themselves');

    await tester.tap(find.bySemanticsLabel('Fire'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Imp'), findsOneWidget);
    expect(find.bySemanticsLabel('Nessie'), findsNothing, reason: 'Nessie is water');
    expect(find.text('All families'), findsOneWidget, reason: 'the way back');

    await tester.tap(find.text('All families'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Water'), findsOneWidget);
    expect(find.bySemanticsLabel('Imp'), findsNothing);
  });

  testWidgets('search spans every group; the keypad is numeric; tiles show the subtitle', (tester) async {
    await pumpGrouped(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).keyboardType, TextInputType.number);

    await tester.enterText(find.byType(TextField), 'nessie');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Nessie'), findsOneWidget, reason: 'found without picking a group');
    // One tile in the grid: tap the tile itself (the row's centre is empty space).
    await tester.tap(find.byType(ItemTile));
    await tester.pumpAndSettle();
    expect(find.byType(ItemSheet), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.byType(ItemSheet), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Fire'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(ItemTile), matching: find.textContaining('Cost ')), findsWidgets);
  });
}
