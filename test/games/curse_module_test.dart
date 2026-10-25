import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/blocks/item_picture.dart';
import 'package:vale_helper/blocks/item_sheet.dart';
import 'package:vale_helper/module_format/block_specs.dart';
import 'package:vale_helper/module_format/expansion.dart';

import '../helpers.dart';
import 'games.dart';

Map<String, Object> curseGame({Map<String, String> zones = const {}, String? step}) => {
  'app.lastGame': valeId,
  'mod.$valeId.zones': jsonEncode(zones),
  'mod.$valeId.phase.step': ?step,
};

void main() {
  group('Curse module data', () {
    test('28 cards join the base 70: six per family and four dragons, each with its picture', () async {
      final m = await loadValeWithCurse();
      final cards = m.items('cards');
      expect(cards, hasLength(98));
      final curse = [
        for (final c in cards)
          if (splitLayerRef(c.data['image'] as String)?.layer == curseId) c,
      ];
      expect(curse, hasLength(28));
      for (final f in ['fire', 'water', 'earth', 'wind']) {
        expect(curse.where((c) => c.data['family'] == f), hasLength(6), reason: f);
      }
      expect(curse.where((c) => c.data['family'] == 'dragon'), hasLength(4));
      for (final c in curse) {
        final file = splitLayerRef(c.data['image'] as String)!.path;
        expect(File('modules/$curseId/$file').existsSync(), isTrue, reason: file);
        expect(m.files.image(c.data['image'] as String), isNotNull, reason: c.id);
        expect(c.data['cost'], inInclusiveRange(0, 12), reason: c.id);
      }
      expect(m.item('cards', 'hantu_banyu')!.data['curses'], hasLength(3));
      expect(m.item('cards', 'selkie')!.data.containsKey('curses'), isFalse);
    });

    test('8 Summoners, each with a front and a back picture', () async {
      final m = await loadValeWithCurse();
      final spec = m.manifest.collections['summoners']!;
      final summoners = m.items('summoners');
      expect(summoners, hasLength(8));
      for (final s in summoners) {
        expect(m.files.image(s.imageRef(spec)), isNotNull, reason: s.id);
        expect(m.files.image(s.backImageRef(spec)), isNotNull, reason: '${s.id} back');
      }
    });

    test('every symbol the merged game names resolves to a picture', () async {
      final m = await loadValeWithCurse();
      for (final e in m.manifest.symbols.entries) {
        expect(m.files.image(e.value), isNotNull, reason: e.key);
      }
    });

    test('the round gains a Curse step after Resolution; setup and end gain their rows', () async {
      final m = await loadValeWithCurse();
      final round = m.manifest.tabs.firstWhere((t) => t.id == 'round').block as FlowSpec;
      expect([for (final s in round.steps) s.id], ['hunting', 'action', 'resolution', 'curse', 'end']);
      expect([for (final r in round.setup!.checklist) r.id], [
        'setup.first',
        'setup.round',
        'setup.score',
        'setup.curse.tree',
        'setup.curse.wards',
        'setup.curse.summoners',
        'setup.curse.start',
        'setup.app',
      ]);
      final end = round.steps.last;
      expect([for (final r in end.checklist) r.id].sublist(end.checklist.length - 2), ['end.curse.score', 'end.table']);
    });

    test('tabs and lanes: Summoners after Cards; Summoner lane first, Soothed after Field', () async {
      final m = await loadValeWithCurse();
      expect([for (final t in m.manifest.tabs) t.id], ['cards', 'summoners', 'mine', 'round']);
      final board = m.manifest.tabs.firstWhere((t) => t.id == 'mine').block as BoardSpec;
      expect([for (final z in board.zones) z.zone], ['summoner', 'table', 'hand', 'field', 'soothed']);
    });
  });

  group('Vale with Curse in the app', () {
    testWidgets('the new cards sit in their family: Taniwha among the Water cards, Brook not', (tester) async {
      await pumpModules(tester, load: () async => [await loadValeWithCurse()], prefs: curseGame());
      await tester.tap(find.bySemanticsLabel('Family Water'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'taniwha');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Taniwha'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'brook');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Brook'), findsNothing, reason: 'a Dragon, filtered out');
    });

    testWidgets('a cursed card in Field is listed on the Curse step', (tester) async {
      await pumpModules(
        tester,
        load: () async => [await loadValeWithCurse()],
        prefs: curseGame(zones: {'hantu_banyu': 'field', 'selkie': 'field'}, step: 'curse'),
        tab: 'Round',
      );
      expect(find.text('YOUR CURSED CARDS'), findsOneWidget);
      expect(find.text('Hantu Banyu'), findsOneWidget);
      expect(find.text('Selkie'), findsNothing, reason: 'no printed curses');
    });

    testWidgets('a Summoner sheet flips to the back side', (tester) async {
      await pumpModules(tester, load: () async => [await loadValeWithCurse()], prefs: curseGame(), tab: 'Summoners');
      await tester.tap(find.bySemanticsLabel('Iwo'));
      await tester.pumpAndSettle();
      expect(find.byType(ItemSheet), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Flip card'));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is ItemPicture && w.back), findsOneWidget);
    });
  });
}
