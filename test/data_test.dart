import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/data/loaders.dart';
import 'package:vale_helper/models/card.dart';
import 'package:vale_helper/models/rules.dart';

void main() {
  final cards = parseCards(File('assets/cards.json').readAsStringSync());

  test('has all 70 base-game cards', () {
    expect(cards, hasLength(70));
  });

  test('family counts match the base game (15 each, 10 dragons)', () {
    int n(Family f) => cards.where((c) => c.family == f).length;
    expect(n(Family.fire), 15);
    expect(n(Family.water), 15);
    expect(n(Family.earth), 15);
    expect(n(Family.wind), 15);
    expect(n(Family.dragon), 10);
  });

  test('every card has at least one effect with text and a sane cost', () {
    for (final c in cards) {
      expect(c.effects, isNotEmpty, reason: c.name);
      expect(c.effects.every((e) => e.text.trim().isNotEmpty), isTrue, reason: c.name);
      expect(c.cost, inInclusiveRange(0, 12), reason: c.name);
    }
  });

  test('every image file exists', () {
    for (final c in cards) {
      expect(c.image, isNotNull, reason: c.name);
      expect(File(c.image!).existsSync(), isTrue, reason: c.image);
    }
  });

  test('cards are sorted by family then cost', () {
    for (var i = 1; i < cards.length; i++) {
      final a = cards[i - 1], b = cards[i];
      final ok = a.family.index < b.family.index ||
          (a.family == b.family && a.cost <= b.cost);
      expect(ok, isTrue, reason: '${a.name} before ${b.name}');
    }
  });

  test('duplicate ids are rejected', () {
    const raw = '{"cards":['
        '{"id":"x","name":"X","family":"fire","cost":1,"effects":[{"type":"instant","text":"t"}]},'
        '{"id":"x","name":"X","family":"fire","cost":1,"effects":[{"type":"instant","text":"t"}]}]}';
    expect(() => parseCards(raw), throwsFormatException);
  });

  test('rules file parses with the 4-phase cycle and unique checklist ids', () {
    final rules = Rules.fromJson(
        jsonDecode(File('assets/rules_en.json').readAsStringSync()) as Map<String, dynamic>);
    expect(rules.phases.map((p) => p.id), ['hunting', 'action', 'resolution', 'end']);
    final ids = [
      ...rules.setup.checklist.map((i) => i.id),
      for (final p in rules.phases) ...p.checklist.map((i) => i.id),
    ];
    expect(ids.toSet(), hasLength(ids.length));
  });
}
