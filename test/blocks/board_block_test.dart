import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/modules/module_state.dart';

import '../helpers.dart';

Map<String, Object> prefsWith(Map<String, String> zones) =>
    {'app.lastGame': 'mini', 'mod.mini.zones': jsonEncode(zones)};

void main() {
  testWidgets('board header, lanes and counts', (tester) async {
    await pumpModules(tester, tab: 'Board', prefs: prefsWith({'imp': 'a', 'nessie': 'a', 'undine': 'b'}));
    expect(find.text('Board'), findsWidgets);
    expect(find.text('3 tracked'), findsOneWidget);
    expect(find.text('Lane A'), findsOneWidget);
    expect(find.text('Lane B'), findsOneWidget);
    expect(find.text('First lane'), findsOneWidget);
    expect(find.text('Imp'), findsOneWidget);
    expect(find.text('Recover.'), findsOneWidget, reason: 'mini cards list the effects');
    // Collapse Lane A: its cards fold away.
    await tester.tap(find.text('Lane A'));
    await tester.pumpAndSettle();
    expect(find.text('Imp'), findsNothing);
    await tester.tap(find.text('Lane A'));
    await tester.pumpAndSettle();
    expect(find.text('Imp'), findsOneWidget);
  });

  testWidgets('long-press drag moves a card to another lane and to Remove', (tester) async {
    await pumpModules(tester, tab: 'Board', prefs: prefsWith({'imp': 'a', 'nessie': 'a'}));
    final zones = scoped<ZoneState>(tester);

    // While dragging, the other lane's hint reads "Drop here".
    final start = tester.getCenter(find.text('Imp'));
    final g = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byKey(const Key('drop-remove')), findsOneWidget, reason: 'drop bar replaces the header');
    final end = tester.getCenter(find.text('Drop here').first);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset.lerp(start, end, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(zones.zoneOf('imp'), 'b');

    await longPressDrag(tester, tester.getCenter(find.text('Nessie')), find.byKey(const Key('drop-remove')));
    expect(zones.zoneOf('nessie'), isNull);
  });

  testWidgets('mouse drags a card between lanes without holding', (tester) async {
    await pumpModules(tester, tab: 'Board', prefs: prefsWith({'imp': 'a'}));
    final start = tester.getCenter(find.text('Imp'));
    final g = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(0, 30));
    await tester.pump();
    final end = tester.getCenter(find.text('Drop here').first);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset.lerp(start, end, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(scoped<ZoneState>(tester).zoneOf('imp'), 'b');
  });

  testWidgets('dropping onto a card places the dragged card before it', (tester) async {
    await pumpModules(tester, tab: 'Board', prefs: prefsWith({'imp': 'a', 'nessie': 'a', 'undine': 'b'}));
    await longPressDrag(tester, tester.getCenter(find.text('Undine')), find.text('Imp'));
    expect(scoped<ZoneState>(tester).idsIn('a'), ['undine', 'imp', 'nessie']);
  });

  testWidgets('a one-zone board shows rows with a remove button and no drop bar', (tester) async {
    await pumpModules(
      tester,
      tab: 'Board',
      prefs: prefsWith({'nessie': 'b', 'imp': 'a'}),
      edit: (m) => (m['tabs'] as List)[1]['block']['children'] = [
        {
          'type': 'zone',
          'zone': 'b',
          'list': {'type': 'cardList', 'collection': 'items', 'style': 'rows', 'removable': true},
        },
      ],
    );
    expect(find.text('Nessie'), findsOneWidget);
    expect(find.text('Imp'), findsNothing);
    expect(find.text('Gain 2 points.'), findsOneWidget);
    expect(find.text('1 tracked'), findsOneWidget);
    final g = await tester.startGesture(tester.getCenter(find.text('Nessie')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byKey(const Key('drop-remove')), findsNothing);
    await g.cancel();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove from Lane B'));
    await tester.pumpAndSettle();
    expect(scoped<ZoneState>(tester).zoneOf('nessie'), isNull);
    expect(scoped<ZoneState>(tester).zoneOf('imp'), 'a');
    expect(find.text('Drag cards here'), findsNothing);
    expect(find.textContaining('Nothing in Lane B yet'), findsOneWidget);
  });

  testWidgets('menu clears one lane directly and everything behind a confirm', (tester) async {
    await pumpModules(tester, tab: 'Board', prefs: prefsWith({'imp': 'a', 'nessie': 'b'}));
    final zones = scoped<ZoneState>(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Lane A'));
    await tester.pumpAndSettle();
    expect(zones.count('a'), 0);
    expect(zones.count('b'), 1);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear everything'));
    await tester.pumpAndSettle();
    expect(find.text('Clear everything?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(zones.total, 1);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear everything'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear all'));
    await tester.pumpAndSettle();
    expect(zones.total, 0);
  });

  testWidgets('tapping a mini card opens its sheet', (tester) async {
    await pumpModules(tester, tab: 'Board', prefs: prefsWith({'imp': 'a'}));
    await tester.tap(find.text('Imp'));
    await tester.pumpAndSettle();
    expect(find.text('Cost 2'), findsOneWidget);
  });
}
