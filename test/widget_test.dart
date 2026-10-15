import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/main.dart';
import 'package:vale_helper/games/vale/models/zone.dart';
import 'package:vale_helper/games/vale/screens/cards_screen.dart';
import 'package:vale_helper/core/settings.dart';
import 'package:vale_helper/games/vale/state/tracker.dart';

Future<void> pumpApp(WidgetTester tester, {Map<String, String> zones = const {}}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'app.lastGame': 'vale', 'vale.tracker.zones': jsonEncode(zones)});
  final data = await tester.runAsync(loadAppData);
  await tester.pumpWidget(HelperApp(loader: () async => data!));
  await tester.pumpAndSettle();
}

int tiles() => find.byType(AnimatedPositioned).evaluate().length;

Tracker tracker(WidgetTester tester) => tester.element(find.byType(NavigationBar)).read<Tracker>();

Finder navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('family dock is single-select; search narrows by name', (tester) async {
    await pumpApp(tester);
    expect(tiles(), 70);

    // A picked family is grouped into lazily built cost sections, so check the summary.
    await tester.tap(find.bySemanticsLabel('Family Dragon'));
    await tester.pumpAndSettle();
    expect(find.text('Dragon · 10 cards'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Family Water'));
    await tester.pumpAndSettle();
    expect(find.text('Water · 15 cards'), findsOneWidget);

    // Tapping the selected family again goes back to all.
    await tester.tap(find.bySemanticsLabel('Family Water'));
    await tester.pumpAndSettle();
    expect(tiles(), 70);

    await tester.enterText(find.byType(TextField), 'nessie');
    await tester.pumpAndSettle();
    expect(tiles(), 1);
  });

  testWidgets('cost rail jumps down to a cost section', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Family Wind'));
    await tester.pumpAndSettle();
    expect(find.text('COST 3'), findsOneWidget);

    await tester.tap(find.text('10').last);
    await tester.pumpAndSettle();
    expect(find.text('COST 10'), findsOneWidget);
    expect(find.text('COST 3'), findsNothing);
  });

  testWidgets('cost rail keeps the last cost highlighted (Fire 0 → 4)', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    Color railColor(String n) {
      final text = tester.widget<Text>(find.descendant(
          of: find.byType(AnimatedContainer), matching: find.text(n)).last);
      return text.style!.color!;
    }

    final idle = railColor('4');
    await tester.tap(find.text('0').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('4').last);
    await tester.pumpAndSettle();
    expect(railColor('4'), isNot(idle), reason: '4 should be the highlighted rail item');
    expect(find.text('COST 4'), findsOneWidget);
  });

  testWidgets('press 0 on the cost rail and slide to 4', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    Finder rail(String n) =>
        find.descendant(of: find.byKey(const Key('costRail')), matching: find.text(n));

    final g = await tester.startGesture(tester.getCenter(rail('0')));
    final end = tester.getCenter(rail('4'));
    final start = tester.getCenter(rail('0'));
    for (var i = 1; i <= 8; i++) {
      await g.moveTo(Offset.lerp(start, end, i / 8)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('COST 4'), findsOneWidget);
    expect(find.text('COST 0'), findsNothing);
  });

  testWidgets('mouse drags a card between lanes without holding', (tester) async {
    await pumpApp(tester, zones: {'imp': 'table'});
    await tester.tap(navLabel('My cards'));
    await tester.pumpAndSettle();

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
    expect(tracker(tester).zoneOf('imp'), Zone.hand);
  });

  testWidgets('density toggle sets cards per row', (tester) async {
    await pumpApp(tester);
    Settings settings() => tester.element(find.byType(CardsScreen)).read<Settings>();
    expect(settings().columns, 4);
    await tester.tap(find.byKey(const Key('density2')));
    await tester.pumpAndSettle();
    expect(settings().columns, 2);
  });

  testWidgets('card sheet zone buttons toggle tracking', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Imp'));
    await tester.pumpAndSettle();
    expect(find.text('Recover.'), findsOneWidget);

    await tester.tap(find.text('Hand'));
    await tester.pumpAndSettle();
    expect(tracker(tester).zoneOf('imp'), Zone.hand);

    await tester.tap(find.text('Hand'));
    await tester.pumpAndSettle();
    expect(tracker(tester).zoneOf('imp'), isNull);
  });

  testWidgets('long-press drag moves a card to another lane and to Remove', (tester) async {
    await pumpApp(tester, zones: {'imp': 'table', 'nessie': 'table'});
    await tester.tap(navLabel('My cards'));
    await tester.pumpAndSettle();

    Future<void> dragTo(String cardName, Finder target) async {
      final start = tester.getCenter(find.text(cardName));
      final g = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 400)); // long-press picks the card up
      await tester.pump();
      // Move in several steps like a real finger, one frame each, then let go.
      final end = tester.getCenter(target);
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset.lerp(start, end, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
    }

    // While dragging, the Hand lane's hint reads "Drop here".
    await dragTo('Imp', find.text('Drop here').first);
    expect(tracker(tester).zoneOf('imp'), Zone.hand);

    await dragTo('Nessie', find.byKey(const Key('drop-remove')));
    expect(tracker(tester).zoneOf('nessie'), isNull);
  });

  testWidgets('Next with open steps needs a second tap', (tester) async {
    await pumpApp(tester);
    await tester.tap(navLabel('Round'));
    await tester.pumpAndSettle();
    expect(find.text('3 steps left'), findsOneWidget);

    await tester.tap(find.text('Next: Action'));
    await tester.pumpAndSettle();
    expect(find.text('Tap again to skip them'), findsOneWidget);

    await tester.tap(find.text('Next: Action'));
    await tester.pumpAndSettle();
    expect(find.text('Next: Resolution'), findsOneWidget);
  });

  testWidgets('ticking every step makes Next go in one tap', (tester) async {
    await pumpApp(tester);
    await tester.tap(navLabel('Round'));
    await tester.pumpAndSettle();
    for (final t in ['Reveal 2 cards per player', 'First picks: clockwise', 'Second picks: counterclockwise']) {
      await tester.tap(find.text(t));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.tap(find.text('Next: Action'));
    await tester.pumpAndSettle();
    expect(find.text('Next: Resolution'), findsOneWidget);
  });
}
