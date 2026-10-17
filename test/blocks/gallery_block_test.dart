import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/blocks/item_view.dart';
import 'package:vale_helper/core/settings.dart';
import 'package:vale_helper/modules/module_state.dart';

import '../helpers.dart';

int tiles() => find.byType(AnimatedPositioned).evaluate().length;

void main() {
  testWidgets('bottom filter dock is single-select with a summary; search narrows by name and nested path', (
    tester,
  ) async {
    await pumpModules(tester);
    expect(tiles(), 4);
    expect(find.text('All families · 4 cards'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    expect(find.text('Fire · 2 cards'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Family Water'));
    await tester.pumpAndSettle();
    expect(find.text('Water · 2 cards'), findsOneWidget);

    // Tapping the selected option again goes back to all.
    await tester.tap(find.bySemanticsLabel('Family Water'));
    await tester.pumpAndSettle();
    expect(tiles(), 4);

    await tester.enterText(find.byType(TextField), 'nessie');
    await tester.pumpAndSettle();
    expect(tiles(), 1);

    await tester.enterText(find.byType(TextField), 'haunt');
    await tester.pumpAndSettle();
    expect(tiles(), 1);
    expect(find.descendant(of: find.byType(ItemTile), matching: find.text('Ghost')), findsWidgets);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No cards match "zzz".'), findsOneWidget);
  });

  testWidgets('review: a filter dock with many options scrolls instead of overflowing', (tester) async {
    await pumpModules(
      tester,
      edit: (m) {
        final filter = (m['tabs'] as List)[0]['block']['filters'][0] as Map;
        filter['options'] = [
          for (var i = 1; i <= 8; i++) {'value': 'opt$i', 'label': 'Opt$i'},
        ];
      },
    );
    expect(tester.takeException(), isNull);
    final last = find.bySemanticsLabel('Family Opt8');
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(find.text('Opt8 · 0 cards'), findsOneWidget);
  });

  testWidgets('density toggle sets cards per row', (tester) async {
    await pumpModules(tester);
    expect(scoped<Settings>(tester).columns, 4);
    await tester.tap(find.byKey(const Key('density2')));
    await tester.pumpAndSettle();
    expect(scoped<Settings>(tester).columns, 2);
    await tester.tap(find.byKey(const Key('density3')));
    await tester.pumpAndSettle();
    expect(scoped<Settings>(tester).columns, 3);
  });

  testWidgets('sections appear only when filtered; the rail jumps and keeps the last section lit', (tester) async {
    await pumpModules(tester);
    expect(find.text('COST 2'), findsNothing);
    expect(find.byKey(const Key('sectionRail')), findsNothing);

    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    expect(find.text('COST 2'), findsOneWidget);
    expect(find.text('COST 4'), findsOneWidget);
    expect(find.byKey(const Key('sectionRail')), findsOneWidget);

    Finder rail(String n) => find.descendant(of: find.byKey(const Key('sectionRail')), matching: find.text(n));
    Color railColor(String n) {
      final text = tester.widget<Text>(rail(n));
      return text.style!.color!;
    }

    final idle = railColor('4');
    // Tap the last section's number: thanks to the tail space it can reach the top and stay lit.
    await tester.tap(rail('4'));
    await tester.pumpAndSettle();
    expect(railColor('4'), isNot(idle), reason: '4 should be the highlighted rail item');
    expect(railColor('2'), idle);

    // Press 2 and slide to 4.
    await tester.tap(rail('2'));
    await tester.pumpAndSettle();
    final start = tester.getCenter(rail('2'));
    final end = tester.getCenter(rail('4'));
    final g = await tester.startGesture(start);
    for (var i = 1; i <= 8; i++) {
      await g.moveTo(Offset.lerp(start, end, i / 8)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(railColor('4'), isNot(idle));
  });

  testWidgets('item sheet: chips, effects, multi-zone toggles put and untrack', (tester) async {
    await pumpModules(tester);
    await tester.tap(find.bySemanticsLabel('Imp'));
    await tester.pumpAndSettle();
    expect(find.text('Recover.'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Cost 2'), findsOneWidget);
    expect(find.text('Sells'), findsOneWidget);

    final zones = scoped<ZoneState>(tester);
    await tester.tap(find.widgetWithText(InkWell, 'Lane B'));
    await tester.pumpAndSettle();
    expect(zones.zoneOf('imp'), 'b');
    await tester.tap(find.widgetWithText(InkWell, 'Lane A'));
    await tester.pumpAndSettle();
    expect(zones.zoneOf('imp'), 'a');
    await tester.tap(find.widgetWithText(InkWell, 'Lane A'));
    await tester.pumpAndSettle();
    expect(zones.zoneOf('imp'), isNull);
    zones.put('imp', 'b');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('untrack')));
    await tester.pumpAndSettle();
    expect(zones.zoneOf('imp'), isNull);

    // Close the sheet; the tile now has no zone band.
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    zones.put('imp', 'a');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Imp, in Lane A'), findsOneWidget);
  });

  testWidgets('single-zone sheet button adds and removes', (tester) async {
    await pumpModules(tester, edit: (m) => m['collections']['items']['sheet']['zones'] = ['b']);
    await tester.tap(find.bySemanticsLabel('Nessie'));
    await tester.pumpAndSettle();
    expect(find.text('Add to Lane B'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggleZone')));
    await tester.pumpAndSettle();
    expect(scoped<ZoneState>(tester).zoneOf('nessie'), 'b');
    expect(find.text('In Lane B'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggleZone')));
    await tester.pumpAndSettle();
    expect(scoped<ZoneState>(tester).zoneOf('nessie'), isNull);
  });

  testWidgets('an item without an image renders the text-only card; unverified items warn in the sheet', (
    tester,
  ) async {
    await pumpModules(tester);
    expect(find.descendant(of: find.byType(ItemPicture), matching: find.text('Ghost')), findsOneWidget);
    expect(find.descendant(of: find.byType(ItemPicture), matching: find.text('Imp')), findsNothing);

    await tester.tap(find.bySemanticsLabel('Ghost'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not verified'), findsOneWidget);
  });

  testWidgets('square image shape draws the framed card with the title inside', (tester) async {
    await pumpModules(
      tester,
      edit: (m) => m['collections']['items']['imageShape'] = 'square',
      prefs: {
        'app.lastGame': 'mini',
        'mod.mini.zones': jsonEncode({'nessie': 'b'}),
      },
    );
    expect(find.descendant(of: find.byType(ItemPicture), matching: find.text('Imp')), findsOneWidget);
    expect(find.bySemanticsLabel('Nessie, in Lane B'), findsOneWidget);
    expect(find.text('LANE B'), findsOneWidget);
  });
}
