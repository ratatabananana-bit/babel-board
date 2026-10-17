import 'package:flutter/material.dart';

import '../models/card.dart';

/// Game symbol image at a fixed square size.
class GameSymbol extends StatelessWidget {
  const GameSymbol(this.asset, {super.key, this.size = 24});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
}

class FamilySymbol extends StatelessWidget {
  const FamilySymbol(this.family, {super.key, this.size = 24});
  final Family family;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: family.label,
    child: GameSymbol(family.asset, size: size),
  );
}

class EffectSymbol extends StatelessWidget {
  const EffectSymbol(this.type, {super.key, this.size = 24});
  final EffectType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final a = type.asset;
    return a == null ? SizedBox(width: size, height: size) : GameSymbol(a, size: size);
  }
}

/// A row of magic-stone symbols, e.g. the stones a family sells for.
class StoneRow extends StatelessWidget {
  const StoneRow(this.stones, {super.key, this.size = 24});
  final List<Stone> stones;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = stones.fold(0, (n, s) => n + s.value);
    return Semantics(
      label: '${stones.length} stones worth $total',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in stones)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: GameSymbol(s.asset, size: size),
            ),
        ],
      ),
    );
  }
}
