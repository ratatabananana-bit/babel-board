import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/card.dart';
import '../models/rules.dart';

Future<List<GameCard>> loadCards(AssetBundle bundle) async {
  final raw = await bundle.loadString('assets/cards.json');
  return parseCards(raw);
}

List<GameCard> parseCards(String raw) {
  final list = (jsonDecode(raw) as Map<String, dynamic>)['cards'] as List;
  final cards = list.map((e) => GameCard.fromJson(e as Map<String, dynamic>)).toList();
  final ids = <String>{};
  for (final c in cards) {
    if (!ids.add(c.id)) throw FormatException('Duplicate card id "${c.id}"');
  }
  cards.sort((a, b) {
    final f = a.family.index.compareTo(b.family.index);
    if (f != 0) return f;
    final c = a.cost.compareTo(b.cost);
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  return cards;
}

Future<Rules> loadRules(AssetBundle bundle) async {
  final raw = await bundle.loadString('assets/rules_en.json');
  return Rules.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
