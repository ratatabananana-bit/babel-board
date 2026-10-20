import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/blocks/item_picture.dart';
import 'package:vale_helper/blocks/item_sheet.dart';
import 'package:vale_helper/blocks/item_tile.dart';
import 'package:vale_helper/core/settings.dart';
import 'package:vale_helper/core/theme.dart';
import 'package:vale_helper/core/widgets/search_top_bar.dart';
import 'package:vale_helper/modules/module_state.dart';

import '../helpers.dart';

int tiles() => find.byType(AnimatedPositioned).evaluate().length;

void main() {
  testWidgets('bottom filter dock is single-select with a summary; search narrows by name and nested path', (
    tester,
  ) async {
    await pumpModules(tester);
    expect(tiles(), 4);
    expect(find.textContaining('4 cards'), findsNothing, reason: 'the dock is only the options');

    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    expect(tiles(), 2);

    await tester.tap(find.bySemanticsLabel('Family Water'));
    await tester.pumpAndSettle();
    expect(tiles(), 2);

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

    testWidgets("the hint shows the module's label next to the arrow; tapping it reveals and hides", (tester) async {
      await pumpModules(tester);
      await tester.tap(find.bySemanticsLabel('Imp'));
      await tester.pumpAndSettle();
      final label = find.descendant(of: find.byKey(const Key('detailsHint')), matching: find.text('Interactions'));
      expect(label, findsOneWidget);
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(revealed(tester), 1);
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(revealed(tester), 0);
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
      expect(find.text('Interactions'), findsNothing, reason: 'no label without details');
    });

    testWidgets('a module without a hint shows the bare arrow', (tester) async {
      await pumpModules(tester, edit: (m) => (m['collections']['items']['sheet']['details'] as Map).remove('hint'));
      await tester.tap(find.bySemanticsLabel('Imp'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detailsHint')), findsOneWidget);
      expect(find.text('Interactions'), findsNothing);
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

    testWidgets('flick feedback is on the slot the panel uncovers, not on the panel', (tester) async {
      await pumpModules(tester);
      await tester.tap(find.bySemanticsLabel('Imp'));
      await tester.pumpAndSettle();
      final panel = find.byKey(const Key('sheetPanel'));
      final slot = find.byKey(const Key('flickSlot'));
      expect(slot, findsNothing, reason: 'no slot until the panel moves');
      final restLeft = tester.getTopLeft(panel).dx;
      final width = tester.getSize(panel).width;

      final g = await tester.startGesture(tester.getCenter(panel));
      await g.moveBy(const Offset(20, 0)); // past the touch slop (consumed by the drag start)
      await g.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(tester.getTopLeft(panel).dx, greaterThan(restLeft + 50), reason: 'the panel follows the finger');
      expect(slot, findsOneWidget);
      expect(find.descendant(of: slot, matching: find.text('Lane B')), findsOneWidget, reason: 'zone name on the slot');
      expect(find.descendant(of: slot, matching: find.byIcon(Icons.check_circle_rounded)), findsNothing);
      expect(find.descendant(of: panel, matching: find.byIcon(Icons.check_circle_rounded)), findsNothing);
      // Before the threshold the slot is only tinted.
      final tinted = tester.widget<ColoredBox>(slot).color;
      final mint = Theme.of(tester.element(slot)).extension<Palette>()!.mint;
      expect(tinted, isNot(mint));

      // Past a third of the width: solid fill and a check.
      await g.moveBy(Offset(width / 3, 0));
      await tester.pump();
      expect(tester.widget<ColoredBox>(slot).color, mint);
      expect(find.descendant(of: slot, matching: find.byIcon(Icons.check_circle_rounded)), findsOneWidget);
      expect(find.descendant(of: panel, matching: find.byIcon(Icons.check_circle_rounded)), findsNothing);

      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150)); // fly-out done, confirmation showing
      expect(find.text('Added to Lane B'), findsOneWidget);
      expect(scoped<ZoneState>(tester).zoneOf('imp'), 'b');
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing, reason: 'closes after the confirmation');
    });

    testWidgets('animation speed Instant: the flick still confirms, then closes at once', (tester) async {
      await pumpModules(tester, prefs: {'app.lastGame': 'mini', 'settings.animationSpeed': 'instant'});
      await tester.tap(find.bySemanticsLabel('Imp'));
      await tester.pumpAndSettle();
      await tester.fling(sheet(), const Offset(300, 0), 1500);
      await tester.pump();
      await tester.pump();
      expect(scoped<ZoneState>(tester).zoneOf('imp'), 'b');
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
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
    expect(tiles(), 0);
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
                      ).first,
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
    expect(find.byKey(const Key('cost-pill-2')), findsOneWidget, reason: 'a number pill starts each cost run');
    expect(find.byKey(const Key('cost-pill-4')), findsOneWidget);
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

  testWidgets('the density button cycles cards per row 4 → 3 → 2 → 4 and shows the count', (tester) async {
    await pumpModules(tester);
    final cycle = find.byKey(const Key('densityCycle'));
    expect(scoped<Settings>(tester).columns, 4);
    expect(find.descendant(of: cycle, matching: find.text('S')), findsOneWidget);
    await tester.tap(cycle);
    await tester.pumpAndSettle();
    expect(scoped<Settings>(tester).columns, 3);
    expect(find.descendant(of: cycle, matching: find.text('M')), findsOneWidget);
    await tester.tap(cycle);
    await tester.pumpAndSettle();
    expect(scoped<Settings>(tester).columns, 2);
    await tester.tap(cycle);
    await tester.pumpAndSettle();
    expect(scoped<Settings>(tester).columns, 4);
    // The view pill sits in the top bar; the family dock has no layout switch any more.
    expect(find.byKey(const Key('layoutToggle')), findsOneWidget);
    expect(find.descendant(of: find.byType(SearchTopBar), matching: find.byKey(const Key('layoutToggle'))), findsOneWidget);
  });

  testWidgets('the rail: fixed slots for the whole range, dots for missing costs, a bubble while scrubbing', (
    tester,
  ) async {
    await pumpModules(tester);
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    final rail = find.byKey(const Key('sectionRail'));
    // Fire has costs 2 and 4 only; the range is 0–12, so the other slots are dots, not numbers.
    expect(find.descendant(of: rail, matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('4')), findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('0')), findsNothing);
    expect(find.descendant(of: rail, matching: find.text('12')), findsNothing);
    expect(tester.getSize(rail).width, 26);
    final grid = tester.getRect(find.byType(CustomScrollView));
    expect(grid.right, lessThanOrEqualTo(tester.getRect(rail).left), reason: 'the rail has its own column');
    expect(find.byKey(const Key('railBubble')), findsNothing);

    // Press and hold: the bubble names the cost under the finger and the grid jumps live.
    final g = await tester.startGesture(tester.getCenter(find.descendant(of: rail, matching: find.text('4'))));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(const Key('railBubble')), findsOneWidget);
    expect(find.text('Cost 4'), findsOneWidget);
    expect(tester.getRect(find.byKey(const Key('railBubble'))).right, lessThan(tester.getRect(rail).left));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('railBubble')), findsNothing, reason: 'the bubble goes with the finger');
    expect(find.byKey(const Key('section-4')), findsOneWidget);
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
    expect(find.text('1 card'), findsNWidgets(2), reason: 'singular count in the group headers');

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
    expect(find.byKey(const Key('chip-nessie')), findsOneWidget, reason: 'zone chip on the corner, no band');
    expect(find.text('LANE B'), findsNothing);
  });

  testWidgets('a dock with more than 8 options becomes a picker button opening a searchable sheet', (tester) async {
    await pumpModules(
      tester,
      edit: (m) {
        final f = (m['tabs'] as List)[0]['block']['filters'][0] as Map;
        f['options'] = [
          for (var i = 0; i < 12; i++) {'value': 'fam$i', 'label': 'Family $i'},
        ];
      },
    );
    expect(find.text('Family: All families'), findsOneWidget);
    expect(find.bySemanticsLabel('Family Family 3'), findsNothing, reason: 'no pill row');

    await tester.tap(find.text('Family: All families'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Family Family 3'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Search family'), '11');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Family Family 11'), findsOneWidget);
    expect(find.bySemanticsLabel('Family Family 1'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Family Family 11'));
    await tester.pumpAndSettle();
    expect(find.text('Family: Family 11'), findsOneWidget);
    expect(tiles(), 0, reason: 'no card has family fam11');
  });
}
