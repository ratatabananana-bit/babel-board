import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/blocks/item_tile.dart';

import '../helpers.dart';

void main() {
  testWidgets('600 items: only tiles near the viewport are built', (tester) async {
    await pumpModules(tester, load: () async => [await loadBig()]);
    expect(find.byType(AnimatedPositioned), findsNothing, reason: 'no reflow grid above kReflowLimit');
    expect(find.byType(ItemTile, skipOffstage: false).evaluate().length, lessThan(100));
    await tester.fling(find.byType(CustomScrollView), const Offset(0, -4000), 3000);
    await tester.pumpAndSettle();
    expect(find.text('Card 599', skipOffstage: false), findsNothing, reason: 'still lazy, not at the end yet');
    expect(find.byType(ItemTile, skipOffstage: false).evaluate().length, lessThan(100));
  });

  testWidgets('600 items grouped by cost: rail jump lands on the section header', (tester) async {
    await pumpModules(tester, load: () async => [await loadBig()]);
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedPositioned), findsNothing);
    await tester.tap(find.descendant(of: find.byKey(const Key('sectionRail')), matching: find.text('7')));
    await tester.pumpAndSettle();
    final header = tester.getTopLeft(find.text('COST 7'));
    expect(header.dy, lessThan(200));
    expect(find.byType(ItemTile, skipOffstage: false).evaluate().length, lessThan(100));
  });

  testWidgets('mini module (4 items) still uses the gliding grid', (tester) async {
    await pumpModules(tester);
    expect(find.byType(AnimatedPositioned), findsNWidgets(4));
  });
}
