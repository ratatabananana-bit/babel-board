import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/modules/module_state.dart';

import '../helpers.dart';

Map<String, Object> prefsWith(Map<String, String> zones) => {
  'app.lastGame': 'mini',
  'mod.mini.zones': jsonEncode(zones),
};

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

  testWidgets('each lane has a one-tap Clear, and Undo brings its cards back', (tester) async {
    await pumpModules(tester, tab: 'Board', prefs: prefsWith({'imp': 'a', 'nessie': 'a', 'undine': 'b'}));
    final zones = scoped<ZoneState>(tester);
    expect(find.byKey(const Key('clear-a')), findsOneWidget);
    await tester.tap(find.byKey(const Key('clear-a')));
    await tester.pump();
    expect(zones.count('a'), 0);
    expect(zones.zoneOf('undine'), 'b');
    expect(find.text('Lane A cleared'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500)); // let the snackbar slide in
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(zones.idsIn('a'), ['imp', 'nessie']);
    // Snackbars with an action must still go away by themselves.
    await tester.tap(find.byKey(const Key('clear-b')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 1)); // slide in, start the 4 s timer, slide out
    }
    expect(find.text('Lane B cleared'), findsNothing);
    expect(find.byKey(const Key('clear-b')), findsOneWidget, reason: 'Clear stays, dimmed');
    expect(
      tester.widget<InkWell>(find.descendant(of: find.byKey(const Key('clear-b')), matching: find.byType(InkWell))).onTap,
      isNull,
      reason: 'an empty lane has nothing to clear',
    );
  });

  testWidgets('a one-lane board has a Clear button in its header instead of the ⋮ menu', (tester) async {
    await pumpModules(
      tester,
      tab: 'Board',
      prefs: prefsWith({'nessie': 'b'}),
      edit: (m) => (m['tabs'] as List)[1]['block']['children'] = [
        {
          'type': 'zone',
          'zone': 'b',
          'list': {'type': 'cardList', 'collection': 'items', 'style': 'rows', 'removable': true},
        },
      ],
    );
    expect(find.byTooltip('More'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pump();
    expect(scoped<ZoneState>(tester).total, 0);
    await tester.pump(const Duration(milliseconds: 500)); // let the snackbar slide in
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(scoped<ZoneState>(tester).zoneOf('nessie'), 'b');
  });

  testWidgets('the header ⋮ menu sits at the top right', (tester) async {
    await pumpModules(tester, tab: 'Board', prefs: prefsWith({'imp': 'a'}));
    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final menuRight = tester.getTopRight(find.byTooltip('More')).dx;
    expect(menuRight, greaterThan(screenWidth - 12), reason: 'menu right edge $menuRight of $screenWidth');
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

  testWidgets('lane headers stick while a long lane scrolls, so Clear stays in reach', (tester) async {
    await pumpModules(
      tester,
      tab: 'Board',
      prefs: prefsWith({'imp': 'a', 'nessie': 'a', 'undine': 'a', 'ghost': 'a'}),
      edit: (m) {
        // One column per lane so Lane A is taller than the screen.
        final lanes = (m['tabs'] as List)[1]['block']['children'] as List;
        for (final l in lanes) {
          (l as Map)['list'] = {'type': 'cardList', 'collection': 'items', 'style': 'mini', 'columns': 1};
        }
      },
    );
    // A short screen, so Lane A is taller than the viewport and its header pins while its cards scroll.
    tester.view.physicalSize = const Size(1080, 1100);
    await tester.pumpAndSettle();
    final headerTop = tester.getTopLeft(find.byKey(const Key('clear-a'))).dy;
    final impTop = tester.getTopLeft(find.text('Imp')).dy;
    await tester.drag(find.text('Imp'), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clear-a')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('clear-a'))).dy, closeTo(headerTop, 6), reason: 'the header stays');
    expect(tester.getTopLeft(find.text('Imp')).dy, lessThan(impTop - 60), reason: 'the cards did');
    // The chevron sits by the name on the left, Clear on the right.
    final chevron = tester.getCenter(find.byIcon(Icons.expand_less_rounded).first).dx;
    final clear = tester.getCenter(find.byKey(const Key('clear-a'))).dx;
    expect(chevron, lessThan(200));
    expect(clear, greaterThan(300));
  });

  testWidgets('tapping a mini card opens its sheet', (tester) async {
    await pumpModules(tester, tab: 'Board', prefs: prefsWith({'imp': 'a'}));
    await tester.tap(find.text('Imp'));
    await tester.pumpAndSettle();
    expect(find.text('Cost 2'), findsOneWidget);
  });
}
