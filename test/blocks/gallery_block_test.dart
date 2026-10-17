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

  testWidgets('the filter dock spaces its buttons evenly, edges included', (tester) async {
    await pumpModules(tester);
    // Mini module: All, Fire, Water.
    final all = tester.getRect(find.bySemanticsLabel('Family All'));
    final fire = tester.getRect(find.bySemanticsLabel('Family Fire'));
    final water = tester.getRect(find.bySemanticsLabel('Family Water'));
    final screenW = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final gapLeft = all.left;
    final gapMid = fire.left - all.right;
    final gapRight = screenW - water.right;
    expect((gapLeft - gapRight).abs(), lessThan(2), reason: 'both ends get the same room');
    expect(gapMid, greaterThan(20), reason: 'buttons are spread out, not bunched');
    expect(gapLeft, greaterThan(20), reason: 'not pinned to the wall');
  });

  group('item sheet: drag-up details (hidden below the zone buttons)', () {
    // How much of the hidden area shows: 0 folded, 1 fully revealed.
    double revealed(WidgetTester tester) => tester.widget<Align>(find.byKey(const Key('detailsReveal'))).heightFactor!;

    testWidgets('dragging the sheet up reveals the details; dragging down hides them, then closes', (tester) async {
      await pumpModules(tester);
      await tester.tap(find.bySemanticsLabel('Imp'));
      await tester.pumpAndSettle();
      expect(revealed(tester), 0);
      expect(find.byKey(const Key('detailsHint')), findsOneWidget, reason: 'an arrow marks the hidden details');
      expect(find.textContaining('Swipe'), findsNothing, reason: 'no hint text, just the arrow');
      final title = find.descendant(of: find.byType(ItemSheet), matching: find.text('Imp'));

      await tester.drag(title, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(revealed(tester), 1);
      expect(find.text('INTERACTIONS'), findsOneWidget);
      final details = tester.getRect(find.byKey(const Key('detailsReveal')));
      final untrack = tester.getRect(find.byKey(const Key('untrack')));
      expect(details.top, greaterThanOrEqualTo(untrack.bottom - 1), reason: 'the details sit below the zone buttons');

      await tester.drag(title, const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(revealed(tester), 0);
      expect(find.byType(ItemSheet), findsOneWidget, reason: 'the first drag down only hides the details');

      await tester.drag(title, const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(find.byType(ItemSheet), findsNothing, reason: 'a second drag down closes the sheet');
    });

    testWidgets('the drag handle at the top also pulls the details up', (tester) async {
      await pumpModules(tester);
      await tester.tap(find.bySemanticsLabel('Imp'));
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(const Key('sheetHandle')), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(revealed(tester), 1);
    });

    testWidgets('the arrow has no highlight box around it', (tester) async {
      await pumpModules(tester);
      await tester.tap(find.bySemanticsLabel('Imp'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('detailsHint')), matching: find.byType(InkWell)), findsNothing);
      expect(find.ancestor(of: find.byKey(const Key('detailsHint')), matching: find.byType(InkWell)), findsNothing);
      expect(tester.widget(find.byKey(const Key('detailsHint'))), isNot(isA<InkWell>()));
    });

    testWidgets('tapping the hint also reveals and hides', (tester) async {
      await pumpModules(tester);
      await tester.tap(find.bySemanticsLabel('Imp'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detailsHint')));
      await tester.pumpAndSettle();
      expect(revealed(tester), 1);
      await tester.tap(find.byKey(const Key('detailsHint')));
      await tester.pumpAndSettle();
      expect(revealed(tester), 0);
    });

    testWidgets('items with nothing to reveal keep the plain sheet', (tester) async {
      await pumpModules(tester);
      await tester.tap(find.bySemanticsLabel('Nessie'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detailsReveal')), findsNothing);
      expect(find.byKey(const Key('detailsHint')), findsNothing);
    });
  });

  group('item sheet: no close button; flick sideways to put the card in a zone', () {
    Finder sheet() => find.byType(ItemSheet);

    testWidgets('there is no close button; tapping outside closes the sheet', (tester) async {
      await pumpModules(tester);
      await tester.tap(find.bySemanticsLabel('Imp'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: sheet(), matching: find.byTooltip('Close')), findsNothing);
      expect(find.descendant(of: sheet(), matching: find.byIcon(Icons.close_rounded)), findsNothing);
      await tester.tapAt(const Offset(200, 60));
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
    });

    testWidgets('flick right puts the card in the right-hand zone and closes, with no snackbar', (tester) async {
      await pumpModules(tester);
      final zones = scoped<ZoneState>(tester);
      await tester.tap(find.bySemanticsLabel('Imp'));
      await tester.pumpAndSettle();
      await tester.fling(sheet(), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(zones.zoneOf('imp'), 'b');
      expect(sheet(), findsNothing);
      expect(find.byType(SnackBar), findsNothing, reason: 'no Undo prompt for flicks');
    });

    testWidgets('flick left puts the card in the left-hand zone', (tester) async {
      await pumpModules(tester);
      await tester.tap(find.bySemanticsLabel('Nessie'));
      await tester.pumpAndSettle();
      await tester.fling(sheet(), const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(scoped<ZoneState>(tester).zoneOf('nessie'), 'a');
    });

    testWidgets('a short sideways drag springs back and changes nothing', (tester) async {
      await pumpModules(tester);
      await tester.tap(find.bySemanticsLabel('Imp'));
      await tester.pumpAndSettle();
      await tester.drag(sheet(), const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(scoped<ZoneState>(tester).zoneOf('imp'), isNull);
      expect(sheet(), findsOneWidget);
    });

    testWidgets('modules without a swipe option ignore sideways flicks', (tester) async {
      await pumpModules(tester, edit: (m) => (m['collections']['items']['sheet'] as Map).remove('swipe'));
      await tester.tap(find.bySemanticsLabel('Imp'));
      await tester.pumpAndSettle();
      await tester.fling(sheet(), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(scoped<ZoneState>(tester).zoneOf('imp'), isNull);
      expect(sheet(), findsOneWidget);
    });
  });

  Future<ModalRoute<dynamic>> openSheetAt(WidgetTester tester, String speed) async {
    await pumpModules(tester, prefs: {'app.lastGame': 'mini', 'settings.animationSpeed': speed});
    await tester.tap(find.bySemanticsLabel('Imp'));
    await tester.pump();
    return ModalRoute.of(tester.element(find.byType(ItemSheet)))!;
  }

  testWidgets('animation speed Instant: the sheet and the grid reflow have no animation', (tester) async {
    final route = await openSheetAt(tester, 'instant');
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    expect(tester.widgetList<AnimatedPositioned>(find.byType(AnimatedPositioned)).first.duration, Duration.zero);
  });

  testWidgets('animation speed Normal: the standard durations', (tester) async {
    final route = await openSheetAt(tester, 'normal');
    expect(route.transitionDuration, const Duration(milliseconds: 250));
    expect(
      tester.widgetList<AnimatedPositioned>(find.byType(AnimatedPositioned)).first.duration,
      const Duration(milliseconds: 260),
    );
  });

  testWidgets('the item sheet opens and closes quickly', (tester) async {
    await pumpModules(tester);
    await tester.tap(find.bySemanticsLabel('Imp'));
    await tester.pump();
    final route = ModalRoute.of(tester.element(find.byType(ItemSheet)))!;
    expect(route.transitionDuration, lessThanOrEqualTo(const Duration(milliseconds: 150)));
    expect(route.reverseTransitionDuration, lessThanOrEqualTo(const Duration(milliseconds: 100)));
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

  testWidgets('the selected cost section is highlighted', (tester) async {
    await pumpModules(tester);
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    bool lit(String cost) =>
        (tester
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: find.byKey(Key('section-$cost'), skipOffstage: false),
                        matching: find.byType(AnimatedContainer, skipOffstage: false),
                        skipOffstage: false,
                      ),
                    )
                    .decoration
                as BoxDecoration?)
            ?.color !=
        null;
    expect(lit('2'), isFalse, reason: 'nothing is highlighted until a cost is picked on the rail');
    expect(lit('4'), isFalse);
    await tester.tap(find.descendant(of: find.byKey(const Key('sectionRail')), matching: find.text('4')));
    await tester.pumpAndSettle();
    expect(lit('4'), isTrue);
    // Section 2 may have scrolled out of the built area; when it is still there it is no longer lit.
    if (find.byKey(const Key('section-2'), skipOffstage: false).evaluate().isNotEmpty) expect(lit('2'), isFalse);
  });

  testWidgets('flowing layout: one grid with a separator where each cost starts; the choice is kept', (tester) async {
    await pumpModules(tester);
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    expect(find.text('COST 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('layoutToggle')));
    await tester.pumpAndSettle();
    expect(find.text('COST 2'), findsNothing, reason: 'no group headers');
    expect(find.byType(AnimatedPositioned), findsWidgets);
    expect(find.byKey(const Key('sep-2')), findsOneWidget);
    expect(find.byKey(const Key('sep-4')), findsOneWidget);
    expect(scoped<Settings>(tester).flowingSections, isTrue);
    // Nothing is highlighted until a cost is picked on the rail.
    expect(find.byKey(const Key('hl-imp')), findsNothing);
    expect(find.byKey(const Key('hl-ghost')), findsNothing);
    await tester.tap(find.descendant(of: find.byKey(const Key('sectionRail')), matching: find.text('4')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hl-ghost')), findsOneWidget);
    expect(find.byKey(const Key('hl-imp')), findsNothing);
    // Back to groups.
    await tester.tap(find.byKey(const Key('layoutToggle')));
    await tester.pumpAndSettle();
    expect(find.text('COST 2'), findsOneWidget);
    expect(scoped<Settings>(tester).flowingSections, isFalse);
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
