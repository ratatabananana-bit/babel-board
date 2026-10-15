import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card.dart';
import '../models/zone.dart';
import '../state/tracker.dart';
import '../theme.dart';
import '../widgets/card_image.dart';
import '../widgets/symbols.dart';

/// Card detail as a bottom sheet over the current screen. Swipe down or tap outside to close.
Future<void> showCardSheet(BuildContext context, GameCard card) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
    builder: (_) => CardSheet(card: card),
  );
}

class CardSheet extends StatelessWidget {
  const CardSheet({super.key, required this.card});

  final GameCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final tracker = context.watch<Tracker>();
    final current = tracker.zoneOf(card.id);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Thumb(card),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(card.name,
                                        style: const TextStyle(
                                            fontSize: 26, height: 1.1, fontWeight: FontWeight.w800)),
                                  ),
                                  IconButton(
                                    tooltip: 'Close',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => Navigator.pop(context),
                                    icon: Icon(Icons.close_rounded, color: p.text2),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _Chip(children: [
                                    FamilySymbol(card.family, size: 22),
                                    const SizedBox(width: 6),
                                    Text(card.family.label),
                                  ]),
                                  _Chip(children: [Text('Cost ${card.cost}')]),
                                  _Chip(children: [
                                    const Text('Sells'),
                                    const SizedBox(width: 4),
                                    StoneRow(card.family.sellsFor, size: 20),
                                  ]),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    for (final e in card.effects) _Effect(e),
                    if (!card.verified)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('⚠ Effect text not verified. Check the physical card.',
                            style: T.caption.copyWith(color: p.warn)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final z in Zone.values) ...[
                  Expanded(child: _ZoneButton(zone: z, active: current == z, cardId: card.id)),
                  const SizedBox(width: 6),
                ],
                Tooltip(
                  message: 'Stop tracking',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: current == null ? null : () => tracker.remove(card.id),
                    child: Container(
                      key: const Key('untrack'),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.line, width: 1.5),
                      ),
                      child: Icon(Icons.remove_done_rounded,
                          color: current == null ? p.line : p.text),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb(this.card);
  final GameCard card;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (d) => GestureDetector(
          onTap: () => Navigator.pop(d),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: InteractiveViewer(maxScale: 4, child: CardImage(card, radius: 14)),
            ),
          ),
        ),
      ),
      child: SizedBox(
        width: 88,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(blurRadius: 12, offset: Offset(0, 4), color: Colors.black38)],
              ),
              child: CardImage(card, radius: 8),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(color: Color(0xCC121315), shape: BoxShape.circle),
                child: const Icon(Icons.open_in_full_rounded, size: 16, color: Color(0xFFF2EDE4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(15)),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _Effect extends StatelessWidget {
  const _Effect(this.effect);
  final CardEffect effect;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Long-press the icon to see what the effect type means.
          Tooltip(
            message: effect.type.explain,
            triggerMode: TooltipTriggerMode.longPress,
            child: EffectSymbol(effect.type, size: 38),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(effect.type.label.toUpperCase(), style: T.caption.copyWith(color: p.text2, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(effect.text, style: T.effect.copyWith(color: p.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle: tap to move the card to this zone; tap the active zone again to untrack.
class _ZoneButton extends StatelessWidget {
  const _ZoneButton({required this.zone, required this.active, required this.cardId});
  final Zone zone;
  final bool active;
  final String cardId;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final zc = p.zone(zone);
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? zc : p.surface2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final t = context.read<Tracker>();
            active ? t.remove(cardId) : t.put(cardId, zone);
          },
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(zone.icon, size: 21, color: active ? p.onAccent : zc),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(zone.label,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: active ? p.onAccent : p.text)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
