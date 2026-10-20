import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/blocks/item_sheet.dart';
import 'package:vale_helper/blocks/item_tile.dart';
import 'package:vale_helper/modules/module_state.dart';

import '../gloomlike.dart';
import '../helpers.dart';

void main() {
  testWidgets('a Gloomhaven-shaped module: find a card in three taps, track a room, end a scenario', (
    tester,
  ) async {
    await pumpModules(tester, load: () async => [await loadGloomlike()], tab: 'Cards');

    // Three taps and a number: hub entry, class tile, search, card.
    await tester.tap(find.text('Abilities'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Class 3'), findsOneWidget, reason: '17 class tiles first');
    expect(find.text('Ability 3'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Class 3'));
    await tester.pumpAndSettle();
    expect(find.text('All classes'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '42');
    await tester.pumpAndSettle();
    expect(find.byType(ItemTile), findsWidgets);
    await tester.tap(find.byType(ItemTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(ItemSheet), findsOneWidget);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.byType(ItemSheet), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // A room: two monster types in play list their cards, nothing else.
    final zones = scoped<ZoneState>(tester);
    zones
      ..put('m5', 'inplay')
      ..put('m7', 'inplay')
      ..put('a1', 'hand')
      ..put('a2', 'discard')
      ..put('a3', 'lost')
      ..put('a4', 'active');
    await tester.tap(find.text('In play'));
    await tester.pumpAndSettle();
    // Rows show the name next to a text-only card that prints it too.
    expect(find.text('Monster card 5'), findsAtLeastNWidgets(1));
    expect(find.text('Monster card 7'), findsAtLeastNWidgets(1));
    expect(find.text('Monster card 6'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Scenario end: everything back to the pool, the room cleared, the round tracker untouched.
    await tester.tap(navLabel('Scenario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cleanup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    expect(zones.count('pool'), 4);
    expect(zones.count('hand') + zones.count('discard') + zones.count('lost') + zones.count('active'), 0);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(zones.count('inplay'), 0);
    expect(zones.count('pool'), 4, reason: 'the pool is campaign state and survives');
  });
}
