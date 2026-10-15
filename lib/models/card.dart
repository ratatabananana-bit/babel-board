import 'package:flutter/material.dart';

enum Stone {
  red(1),
  blue(3),
  purple(6);

  const Stone(this.value);
  final int value;

  String get asset => 'assets/symbols/stone_$name.webp';
}

enum Family {
  fire('Fire', Color(0xFFD84315), [Stone.red, Stone.red, Stone.red]),
  water('Water', Color(0xFF1E88E5), [Stone.blue]),
  earth('Earth', Color(0xFF43A047), [Stone.red, Stone.red, Stone.red, Stone.red]),
  wind('Wind', Color(0xFF8E24AA), [Stone.red, Stone.blue]),
  dragon('Dragon', Color(0xFFF9A825), [Stone.purple]);

  const Family(this.label, this.color, this.sellsFor);
  final String label;
  final Color color;

  /// Stones received when selling a hunted card of this family.
  final List<Stone> sellsFor;

  /// The game's own family symbol.
  String get asset => 'assets/symbols/$name.webp';

  static Family parse(String s) => Family.values.firstWhere(
        (f) => f.name == s.toLowerCase(),
        orElse: () => throw FormatException('Unknown family "$s"'),
      );
}

enum EffectType {
  instant('Instant', 'Triggers once, when the card is summoned.'),
  permanent('Permanent', 'Always active while the card is in your area.'),
  active('Active', 'Use once per round, during the Resolution Phase.'),
  none('None', 'No effect.');

  const EffectType(this.label, this.explain);
  final String label;
  final String explain;

  /// The game's own effect-type symbol (none for [EffectType.none]).
  String? get asset => this == none ? null : 'assets/symbols/$name.webp';

  static EffectType parse(String s) => EffectType.values.firstWhere(
        (t) => t.name == s.toLowerCase(),
        orElse: () => throw FormatException('Unknown effect type "$s"'),
      );
}

class CardEffect {
  const CardEffect(this.type, this.text);

  final EffectType type;
  final String text;

  factory CardEffect.fromJson(Map<String, dynamic> j) =>
      CardEffect(EffectType.parse(j['type'] as String), j['text'] as String);
}

class GameCard {
  const GameCard({
    required this.id,
    required this.name,
    required this.nameZh,
    required this.family,
    required this.cost,
    required this.effects,
    required this.verified,
    required this.image,
  });

  final String id;
  final String name;
  final String? nameZh;
  final Family family;
  final int cost;

  /// Most cards have one effect; a few have two (e.g. Instant + Active).
  final List<CardEffect> effects;
  final bool verified;

  /// Asset path, e.g. `assets/cards/hydra.webp`. Null if no image.
  final String? image;

  bool get hasActive => effects.any((e) => e.type == EffectType.active);

  /// One-line summary, e.g. "Instant: Earn 2 red stones. · Active: Recover."
  String get effectSummary => effects.map((e) => '${e.type.label}: ${e.text}').join(' · ');

  factory GameCard.fromJson(Map<String, dynamic> j) => GameCard(
        id: j['id'] as String,
        name: j['name'] as String,
        nameZh: j['nameZh'] as String?,
        family: Family.parse(j['family'] as String),
        cost: j['cost'] as int,
        effects: (j['effects'] as List)
            .map((e) => CardEffect.fromJson(e as Map<String, dynamic>))
            .toList(),
        verified: j['verified'] as bool? ?? false,
        image: j['image'] as String?,
      );
}
