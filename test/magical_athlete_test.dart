@Skip('App-level tests of the old code games; re-expressed against modules in test/games (Task 9), deleted in Task 13')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/core/app_state.dart';
import 'package:vale_helper/core/flow/flow_rules.dart';
import 'package:vale_helper/games/magical_athlete/models/racer.dart';
import 'package:vale_helper/games/magical_athlete/screens/racers_screen.dart';
import 'package:vale_helper/games/magical_athlete/state/lineup.dart';
import 'package:vale_helper/main.dart';

Future<void> pumpApp(WidgetTester tester, {String? lastGame}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'app.lastGame': ?lastGame});
  final data = await tester.runAsync(loadAppData);
  await tester.pumpWidget(HelperApp(loader: () async => data!));
  await tester.pumpAndSettle();
}

Finder navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

T read<T>(WidgetTester tester) => tester.element(find.byType(NavigationBar)).read<T>();

void main() {
  group('Magical Athlete data', () {
    final racers = parseRacers(File('assets/games/magical_athlete/racers.json').readAsStringSync());

    test('has all 36 racers with abilities and images', () {
      expect(racers, hasLength(36));
      for (final r in racers) {
        expect(r.abilities.every((a) => a.trim().isNotEmpty), isTrue, reason: r.name);
        expect(File(r.image!).existsSync(), isTrue, reason: r.image);
      }
    });

    test('rules: draft, 4 races (Mild/Wild), final; unique checklist ids; runs once', () {
      final rules = Rules.fromJson(jsonDecode(
          File('assets/games/magical_athlete/rules_en.json').readAsStringSync()) as Map<String, dynamic>);
      expect(rules.cyclic, isFalse);
      expect(rules.phases.map((p) => p.id), ['draft', 'race1', 'race2', 'race3', 'race4', 'final']);
      expect(rules.phases.map((p) => p.tag), [null, 'Mild', 'Wild', 'Mild', 'Wild', null]);
      final ids = [
        ...rules.setup.checklist.map((i) => i.id),
        for (final p in rules.phases) ...p.checklist.map((i) => i.id),
      ];
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  testWidgets('first launch shows the game picker; picking a game opens it and is remembered',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('Which game?'), findsOneWidget);

    await tester.tap(find.text('Magical Athlete'));
    await tester.pumpAndSettle();
    expect(navLabel('Racers'), findsOneWidget);
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getString(AppState.lastGameKey), 'ma');
  });

  testWidgets('game switcher moves between games', (tester) async {
    await pumpApp(tester, lastGame: 'vale');
    expect(navLabel('Round'), findsOneWidget);

    await tester.tap(find.byKey(const Key('gameSwitcher')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Magical Athlete'));
    await tester.pumpAndSettle();
    expect(navLabel('Racers'), findsOneWidget);
    expect(navLabel('Round'), findsNothing);
  });

  testWidgets('search, add a racer to this race, see it in This race', (tester) async {
    await pumpApp(tester, lastGame: 'ma');
    await tester.enterText(find.byType(TextField), 'banana');
    await tester.pumpAndSettle();
    expect(find.byType(RacerTile), findsOneWidget);

    await tester.tap(find.byType(RacerTile));
    await tester.pumpAndSettle();
    expect(find.text('I trip any racer that passes me.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggleRace')));
    await tester.pumpAndSettle();
    expect(read<Lineup>(tester).ids, ['banana']);
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();

    await tester.tap(navLabel('This race'));
    await tester.pumpAndSettle();
    expect(find.text('1 racers'), findsOneWidget);
    expect(find.text('I trip any racer that passes me.'), findsOneWidget);
  });

  testWidgets('Game flow runs once: the last step offers a new game', (tester) async {
    await pumpApp(tester, lastGame: 'ma');
    await tester.tap(navLabel('Game'));
    await tester.pumpAndSettle();
    expect(find.text('Next: Race 1'), findsOneWidget);

    await tester.tap(find.text('Final'));
    await tester.pumpAndSettle();
    expect(find.text('New game'), findsWidgets);
  });
}
