import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/blocks/flow/flow_state.dart';
import 'package:vale_helper/blocks/item_view.dart';
import 'package:vale_helper/modules/loaded_module.dart';
import 'package:vale_helper/modules/module_state.dart';

import '../helpers.dart';
import 'games.dart';

int tiles() => find.byType(AnimatedPositioned).evaluate().length;

Map<String, Object> valePrefs([Map<String, String> zones = const {}]) => {
  'app.lastGame': valeId,
  'mod.$valeId.zones': jsonEncode(zones),
};

void main() {
  group('Vale of Eternity module data', () {
    test('has all 70 base-game cards, 15 per family and 10 dragons, with images', () async {
      final m = await loadVale();
      final cards = m.items('cards');
      expect(cards, hasLength(70));
      int n(String f) => cards.where((c) => c.data['family'] == f).length;
      expect(n('fire'), 15);
      expect(n('water'), 15);
      expect(n('earth'), 15);
      expect(n('wind'), 15);
      expect(n('dragon'), 10);
      final spec = m.manifest.collections['cards']!;
      for (final c in cards) {
        final ref = c.imageRef(spec);
        expect(ref, isNotNull, reason: c.id);
        expect(File('modules/$valeId/$ref').existsSync(), isTrue, reason: ref);
        expect((c.data['effects'] as List), isNotEmpty, reason: c.id);
        expect(c.data['cost'], inInclusiveRange(0, 12), reason: c.id);
        expect(c.data['sellsFor'], isA<List>(), reason: c.id);
        expect(c.data['familyLabel'], isA<String>(), reason: c.id);
      }
      for (final s in m.manifest.symbols.values) {
        expect(File('modules/$valeId/$s').existsSync(), isTrue, reason: s);
      }
      expect(File('modules/$valeId/${m.manifest.icon}').existsSync(), isTrue);
      expect(m.manifest.id, valeId);
      expect(m.manifest.version, '1.1.0');
    });

    test('small stone counts are repeated icons, like the printed cards', () async {
      final m = await loadVale();
      String effect(String id) => (m.item('cards', id)!.data['effects'] as List).first['text'] as String;
      expect(effect('imp'), 'Earn :stone_red::stone_red:.');
      expect(effect('water_giant'), 'Earn :stone_blue::stone_blue:.');
      final leftover = RegExp(r'\b[1-4] :stone_');
      for (final c in m.items('cards')) {
        for (final e in c.data['effects'] as List) {
          expect(leftover.hasMatch(e['text'] as String), isFalse, reason: '${c.id}: ${e['text']}');
        }
      }
    });

    test('points use the wiki\'s points symbol inline', () async {
      final m = await loadVale();
      expect(m.manifest.symbols['points'], 'images/symbols/points.png');
      expect(File('modules/$valeId/images/symbols/points.png').existsSync(), isTrue);
      String effect(String id) => (m.item('cards', id)!.data['effects'] as List).first['text'] as String;
      expect(effect('mud_slime'), 'Earn 6 :points:.');
      expect(effect('rock_golem'), 'Earn :points: equal to the total value of your :stone_purple:.');
      for (final c in m.items('cards')) {
        for (final e in c.data['effects'] as List) {
          final text = (e['text'] as String).replaceAll(':points:', '');
          expect(RegExp(r'\bpoints?\b').hasMatch(text), isFalse, reason: '${c.id}: ${e['text']}');
        }
      }
    });

    test('cards are sorted by family then cost; the flow has the 4-phase cycle', () async {
      final m = await loadVale();
      final cards = m.items('cards');
      const order = ['fire', 'water', 'earth', 'wind', 'dragon'];
      for (var i = 1; i < cards.length; i++) {
        final a = cards[i - 1].data, b = cards[i].data;
        final fa = order.indexOf(a['family'] as String), fb = order.indexOf(b['family'] as String);
        expect(
          fa < fb || (fa == fb && (a['cost'] as int) <= (b['cost'] as int)),
          isTrue,
          reason: '${a['name']} before ${b['name']}',
        );
      }
      final flow = m.manifest.tabs.firstWhere((t) => t.block.type == 'flow').block;
      expect(flow.children.map((s) => s.settings['id']), ['hunting', 'action', 'resolution', 'end']);
      expect(flow.settings['cyclic'], isTrue);
    });
  });

  testWidgets('family dock is single-select; search narrows by name', (tester) async {
    await pumpGames(tester, prefs: valePrefs());
    expect(tiles(), 70);

    await tester.tap(find.bySemanticsLabel('Family Dragon'));
    await tester.pumpAndSettle();
    expect(find.text('Dragon · 10 cards'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Family Water'));
    await tester.pumpAndSettle();
    expect(find.text('Water · 15 cards'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Family Water'));
    await tester.pumpAndSettle();
    expect(tiles(), 70);

    await tester.enterText(find.byType(TextField), 'nessie');
    await tester.pumpAndSettle();
    expect(tiles(), 1);
  });

  testWidgets('cost rail jumps down to a cost section', (tester) async {
    await pumpGames(tester, prefs: valePrefs());
    await tester.tap(find.bySemanticsLabel('Family Wind'));
    await tester.pumpAndSettle();
    expect(find.text('COST 3'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byKey(const Key('sectionRail')), matching: find.text('10')));
    await tester.pumpAndSettle();
    expect(find.text('COST 10'), findsOneWidget);
    expect(find.text('COST 3'), findsNothing);
  });

  testWidgets('cost rail keeps the last cost highlighted (Fire 0 → 4) and scrubs', (tester) async {
    await pumpGames(tester, prefs: valePrefs());
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    Finder rail(String n) => find.descendant(of: find.byKey(const Key('sectionRail')), matching: find.text(n));
    Color railColor(String n) => tester.widget<Text>(rail(n)).style!.color!;

    final idle = railColor('4');
    await tester.tap(rail('0'));
    await tester.pumpAndSettle();
    await tester.tap(rail('4'));
    await tester.pumpAndSettle();
    expect(railColor('4'), isNot(idle), reason: '4 should be the highlighted rail item');
    expect(find.text('COST 4'), findsOneWidget);

    await tester.tap(rail('0'));
    await tester.pumpAndSettle();
    final start = tester.getCenter(rail('0'));
    final end = tester.getCenter(rail('4'));
    final g = await tester.startGesture(start);
    for (var i = 1; i <= 8; i++) {
      await g.moveTo(Offset.lerp(start, end, i / 8)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('COST 4'), findsOneWidget);
    expect(find.text('COST 0'), findsNothing);
  });

  testWidgets('on a tablet the gallery shows more than 4 cards per row', (tester) async {
    await pumpGames(tester, prefs: valePrefs());
    // A 10-inch tablet in portrait: 800 x 1280 logical pixels.
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    await tester.pumpAndSettle();
    int firstRow() =>
        tester.widgetList<AnimatedPositioned>(find.byType(AnimatedPositioned)).where((p) => p.top == 0).length;
    expect(firstRow(), 8);
    await tester.tap(find.byKey(const Key('densityCycle'))); // 3
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('densityCycle'))); // 2
    await tester.pumpAndSettle();
    expect(firstRow(), 4);
  });

  group('grouped by cost: the highlight is what you picked, the rail is where you are', () {
    Finder rail(String n) => find.descendant(of: find.byKey(const Key('sectionRail')), matching: find.text(n));
    BoxDecoration pill(WidgetTester tester, String n) =>
        tester
                .widget<AnimatedContainer>(find.ancestor(of: rail(n), matching: find.byType(AnimatedContainer)).first)
                .decoration
            as BoxDecoration;
    // Picked on the rail: the pill is filled.
    bool railPicked(WidgetTester tester, String n) => pill(tester, n).color != Colors.transparent;
    // Where you are while scrolling: a ring (or the filled pill when it is also the pick).
    bool railLit(WidgetTester tester, String n) => railPicked(tester, n) || pill(tester, n).border != null;
    bool panelLit(WidgetTester tester, String cost) {
      final f = find.descendant(
        of: find.byKey(Key('section-$cost'), skipOffstage: false),
        matching: find.byType(AnimatedContainer, skipOffstage: false),
      );
      if (f.evaluate().isEmpty) return false;
      return (tester.widget<AnimatedContainer>(f).decoration as BoxDecoration?)?.color != null;
    }

    Future<void> fire(WidgetTester tester) async {
      await pumpGames(tester, prefs: valePrefs());
      await tester.tap(find.bySemanticsLabel('Family Fire'));
      await tester.pumpAndSettle();
    }

    testWidgets('plain scrolling moves the rail to the cost that fills the screen, not a sliver at the top', (
      tester,
    ) async {
      await fire(tester);
      expect(railLit(tester, '0'), isTrue);
      // Scroll just enough that only the bottom of the cost-0 group stays on screen.
      final start = tester.getCenter(find.text('COST 1'));
      await tester.dragFrom(start, const Offset(0, -130));
      await tester.pumpAndSettle();
      expect(railLit(tester, '0'), isFalse, reason: 'a barely visible group does not win');
      expect(railLit(tester, '1'), isTrue);
      expect(panelLit(tester, '0'), isFalse, reason: 'scrolling alone never highlights cards');
      expect(panelLit(tester, '1'), isFalse);
    });

    testWidgets('a cost picked on the rail stays highlighted while you scroll', (tester) async {
      await fire(tester);
      await tester.tap(rail('2'));
      await tester.pumpAndSettle();
      expect(panelLit(tester, '2'), isTrue);
      expect(railPicked(tester, '2'), isTrue);
      await tester.dragFrom(tester.getCenter(find.text('COST 3')), const Offset(0, -260));
      await tester.pumpAndSettle();
      expect(panelLit(tester, '2'), isTrue, reason: 'the pick stays');
      expect(railPicked(tester, '2'), isTrue, reason: 'the filled pill is the pick, it stays too');
      expect(railLit(tester, '3') || railLit(tester, '4'), isTrue, reason: 'the ring follows the scroll');
      expect(railPicked(tester, '3') || railPicked(tester, '4'), isFalse);
      // Picking another family clears the pick.
      await tester.tap(find.bySemanticsLabel('Family Water'));
      await tester.pumpAndSettle();
      expect(panelLit(tester, '2'), isFalse);
    });
  });

  testWidgets('flowing layout: the cost rail scrolls to that cost and highlights its cards', (tester) async {
    await pumpGames(tester, prefs: {...valePrefs(), 'settings.flowingSections': true});
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    expect(find.text('COST 4'), findsNothing, reason: 'flowing: no group headers');
    final m = scoped<LoadedModule>(tester);
    final fire = m.items('cards').where((c) => c.data['family'] == 'fire').toList();
    final cost4 = fire.where((c) => c.data['cost'] == 4).map((c) => c.id).toList();
    expect(cost4, isNotEmpty);
    final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
    expect(scroll.offset, 0);
    await tester.tap(find.descendant(of: find.byKey(const Key('sectionRail')), matching: find.text('4')));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0), reason: 'scrolled down to the cost-4 row');
    for (final id in cost4) {
      expect(find.byKey(Key('hl-$id'), skipOffstage: false), findsOneWidget, reason: id);
    }
    expect(find.byKey(Key('hl-${fire.first.id}'), skipOffstage: false), findsNothing);
  });

  testWidgets('density toggle sets cards per row', (tester) async {
    await pumpGames(tester, prefs: valePrefs());
    await tester.tap(find.byKey(const Key('densityCycle'))); // 3
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('densityCycle'))); // 2
    await tester.pumpAndSettle();
    expect(tiles(), 70);
    expect(find.descendant(of: find.byKey(const Key('densityCycle')), matching: find.text('2')), findsOneWidget);
  });

  testWidgets("Hae-tae's interaction ruling is in its drag-up details", (tester) async {
    await pumpGames(tester, prefs: valePrefs());
    await tester.enterText(find.byType(TextField), 'hae');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ItemTile)); // the only card left after the search
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detailsHint')), findsOneWidget);
    expect(tester.widget<Align>(find.byKey(const Key('detailsReveal'))).heightFactor, 0);
    await tester.tap(find.byKey(const Key('detailsHint')));
    await tester.pumpAndSettle();
    expect(find.textContaining('still needs an actual', findRichText: true), findsOneWidget);
    // Stones show as their symbols, like the printed card: no colour words left in the text.
    expect(find.textContaining('blue stones', findRichText: true), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ItemSheet),
        matching: find.byWidgetPredicate((w) => w is SymbolImage && w.name.startsWith('stone_')),
      ),
      findsWidgets,
    );
  });

  testWidgets('flick a card sheet right for Hand, left for Table', (tester) async {
    await pumpGames(tester, prefs: valePrefs());
    final zones = scoped<ZoneState>(tester);
    await tester.tap(find.bySemanticsLabel('Imp'));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ItemSheet), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(zones.zoneOf('imp'), 'hand');
    await tester.tap(find.bySemanticsLabel('Hestia'));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ItemSheet), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(zones.zoneOf('hestia'), 'table');
  });

  testWidgets('card sheet zone buttons toggle tracking', (tester) async {
    await pumpGames(tester, prefs: valePrefs());
    await tester.tap(find.bySemanticsLabel('Imp'));
    await tester.pumpAndSettle();
    expect(find.text('Recover.'), findsOneWidget);
    expect(find.descendant(of: find.byType(ItemSheet), matching: find.text('Fire')), findsOneWidget);
    expect(find.text('Cost 0'), findsOneWidget);
    expect(find.text('Sells'), findsOneWidget);

    final zones = scoped<ZoneState>(tester);
    await tester.tap(find.text('Hand'));
    await tester.pumpAndSettle();
    expect(zones.zoneOf('imp'), 'hand');
    await tester.tap(find.text('Hand'));
    await tester.pumpAndSettle();
    expect(zones.zoneOf('imp'), isNull);
  });

  testWidgets('long-press drag moves a card to another lane and to Remove', (tester) async {
    await pumpGames(tester, prefs: valePrefs({'imp': 'table', 'nessie': 'table'}), tab: 'My cards');
    final zones = scoped<ZoneState>(tester);
    expect(find.text('2 tracked'), findsOneWidget);
    await longPressDrag(tester, tester.getCenter(find.text('Imp')), find.text('Drop here').first);
    expect(zones.zoneOf('imp'), 'hand');
    await longPressDrag(tester, tester.getCenter(find.text('Nessie')), find.byKey(const Key('drop-remove')));
    expect(zones.zoneOf('nessie'), isNull);
  });

  testWidgets('mouse drags a card between lanes without holding', (tester) async {
    await pumpGames(tester, prefs: valePrefs({'imp': 'table'}), tab: 'My cards');
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
    expect(scoped<ZoneState>(tester).zoneOf('imp'), 'hand');
  });

  testWidgets('Next with open steps needs a second tap', (tester) async {
    await pumpGames(tester, prefs: valePrefs(), tab: 'Round');
    expect(find.text('3 steps left'), findsOneWidget);
    await tester.tap(find.text('Next: Action'));
    await tester.pumpAndSettle();
    expect(find.text('Tap again to skip them'), findsOneWidget);
    await tester.tap(find.text('Next: Action'));
    await tester.pumpAndSettle();
    expect(find.text('Next: Resolution'), findsOneWidget);
  });

  testWidgets('ticking every step makes Next go in one tap', (tester) async {
    await pumpGames(tester, prefs: valePrefs(), tab: 'Round');
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

  testWidgets('Resolution lists Field cards with Active effects; End of round clears Table', (tester) async {
    await pumpGames(tester, prefs: valePrefs({'imp': 'field', 'hestia': 'field', 'nessie': 'table'}), tab: 'Round');
    await tester.tap(find.text('Resolution'));
    await tester.pumpAndSettle();
    expect(find.text('Imp'), findsOneWidget);
    expect(find.text('Recover.'), findsOneWidget);
    expect(find.text('Hestia'), findsNothing);
    expect(find.text('0 / 1'), findsOneWidget);

    await tester.tap(find.text('End of round'));
    await tester.pumpAndSettle();
    expect(find.text('Start next round'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    final zones = scoped<ZoneState>(tester);
    expect(zones.zoneOf('nessie'), isNull);
    expect(zones.zoneOf('imp'), 'field');
    expect(scoped<FlowState>(tester).isChecked('end.table'), isTrue);
  });
}
