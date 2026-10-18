import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/blocks/item_view.dart';
import 'package:vale_helper/module_format/block_specs.dart';
import 'package:vale_helper/core/app_state.dart';
import 'package:vale_helper/modules/module_state.dart';

import '../helpers.dart';
import 'games.dart';

void main() {
  group('Magical Athlete module data', () {
    test('has all 36 racers with abilities and images; square card shape', () async {
      final m = await loadMa();
      final racers = m.items('racers');
      expect(racers, hasLength(36));
      final spec = m.manifest.collections['racers']!;
      expect(spec.imageShape, 'square');
      expect(spec.subtitleField, 'powerName');
      for (final r in racers) {
        expect((r.data['abilities'] as List).every((a) => (a as String).trim().isNotEmpty), isTrue, reason: r.id);
        expect(File('modules/$maId/${r.imageRef(spec)}').existsSync(), isTrue, reason: r.id);
      }
      expect(File('modules/$maId/${m.manifest.icon}').existsSync(), isTrue);
    });

    test('flow: draft, 4 races (Mild/Wild), final; unique checklist ids; runs once', () async {
      final m = await loadMa();
      final flow = m.manifest.tabs.map((t) => t.block).whereType<FlowSpec>().single;
      expect(flow.cyclic, isFalse);
      expect(flow.steps.map((s) => s.id), ['draft', 'race1', 'race2', 'race3', 'race4', 'final']);
      expect(flow.steps.map((s) => s.tag), [null, 'Mild', 'Wild', 'Mild', 'Wild', null]);
      final ids = [
        for (final i in flow.setup!.checklist) i.id,
        for (final s in flow.steps)
          for (final i in s.checklist) i.id,
      ];
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  testWidgets('first launch shows the Library; picking a game opens it and is remembered', (tester) async {
    await pumpGames(tester);
    expect(find.text('Library'), findsOneWidget);
    await tester.tap(find.text('Magical Athlete'));
    await tester.pumpAndSettle();
    expect(navLabel('Racers'), findsOneWidget);
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getString(AppState.lastGameKey), maId);
  });

  testWidgets('game switcher moves between games', (tester) async {
    await pumpGames(tester, prefs: {'app.lastGame': valeId});
    expect(navLabel('Round'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gameSwitcher')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Magical Athlete'));
    await tester.pumpAndSettle();
    expect(navLabel('Racers'), findsOneWidget);
    expect(navLabel('Round'), findsNothing);
  });

  testWidgets('search, add a racer to this race, see it in This race', (tester) async {
    await pumpGames(tester, prefs: {'app.lastGame': maId});
    await tester.enterText(find.byType(TextField), 'banana');
    await tester.pumpAndSettle();
    expect(find.byType(ItemTile), findsOneWidget);

    await tester.tap(find.byType(ItemTile));
    await tester.pumpAndSettle();
    expect(find.text('I trip any racer that passes me.'), findsOneWidget);
    expect(find.text('The Slip'), findsWidgets);
    expect(find.text('Add to this race'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggleZone')));
    await tester.pumpAndSettle();
    expect(find.text('In this race'), findsOneWidget);
    expect(scoped<ZoneState>(tester).idsIn('race'), ['banana']);
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();

    await tester.tap(navLabel('This race'));
    await tester.pumpAndSettle();
    expect(find.text('1 racers'), findsOneWidget);
    expect(find.text('I trip any racer that passes me.'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove from this race'));
    await tester.pumpAndSettle();
    expect(scoped<ZoneState>(tester).total, 0);
  });

  testWidgets('Game flow runs once: the last step offers a new game', (tester) async {
    await pumpGames(tester, prefs: {'app.lastGame': maId}, tab: 'Game');
    expect(find.text('Next: Race 1'), findsOneWidget);
    await tester.tap(find.text('Final'));
    await tester.pumpAndSettle();
    expect(find.text('New game'), findsWidgets);
  });
}
