import 'dart:convert';

import 'package:flutter/services.dart';

/// One Magical Athlete racer card.
class Racer {
  const Racer({
    required this.id,
    required this.name,
    required this.abilities,
    required this.verified,
    this.nameZh,
    this.number,
    this.powerName,
    this.notes,
    this.image,
  });

  final String id;
  final String name;

  /// Unofficial fan translation; the Chinese edition's own names weren't found.
  final String? nameZh;

  /// Subtitle printed on the card, e.g. "The Slip".
  final String? powerName;

  /// Rulebook clarifications for this racer.
  final String? notes;

  /// Printed card number, if the cards have one.
  final int? number;

  /// The ability text; usually one paragraph, sometimes several parts.
  final List<String> abilities;
  final bool verified;

  /// Asset path of the card picture, or null.
  final String? image;

  factory Racer.fromJson(Map<String, dynamic> j) => Racer(
        id: j['id'] as String,
        name: j['name'] as String,
        nameZh: j['nameZh'] as String?,
        number: j['number'] as int?,
        powerName: j['powerName'] as String?,
        notes: j['notes'] as String?,
        abilities: (j['abilities'] as List).cast<String>(),
        verified: j['verified'] as bool? ?? false,
        image: j['image'] as String?,
      );
}

/// Racer tiles are drawn in the printed card's shape (width / height).
const racerAspect = 0.716;

List<Racer> parseRacers(String raw) {
  final list = (jsonDecode(raw) as Map<String, dynamic>)['racers'] as List;
  final racers = list.map((e) => Racer.fromJson(e as Map<String, dynamic>)).toList();
  final ids = <String>{};
  for (final r in racers) {
    if (!ids.add(r.id)) throw FormatException('Duplicate racer id "${r.id}"');
  }
  racers.sort((a, b) {
    if (a.number != null && b.number != null) return a.number!.compareTo(b.number!);
    return a.name.compareTo(b.name);
  });
  return racers;
}

Future<List<Racer>> loadRacers(AssetBundle bundle) async =>
    parseRacers(await bundle.loadString('assets/games/magical_athlete/racers.json'));
