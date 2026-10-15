import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../models/racer.dart';
import '../state/lineup.dart';
import '../widgets/racer_card.dart';

/// Racer detail as a bottom sheet: the ability is the biggest thing on it.
Future<void> showRacerSheet(BuildContext context, Racer racer) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
    builder: (_) => RacerSheet(racer: racer),
  );
}

class RacerSheet extends StatelessWidget {
  const RacerSheet({super.key, required this.racer});
  final Racer racer;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final lineup = context.watch<Lineup>();
    final inRace = lineup.contains(racer.id);
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
                        GestureDetector(
                          onTap: () => _showFull(context),
                          child: SizedBox(
                            width: 88,
                            child: RacerCard(racer, radius: 8),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(racer.name,
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
                              if (racer.powerName != null) ...[
                                const SizedBox(height: 4),
                                Text(racer.powerName!,
                                    style: T.body.copyWith(color: p.text2, fontStyle: FontStyle.italic)),
                              ],
                              if (racer.nameZh != null) ...[
                                const SizedBox(height: 6),
                                Text('${racer.nameZh}  (fan translation)',
                                    style: T.caption.copyWith(color: p.muted)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('ABILITY', style: T.caption.copyWith(color: p.text2, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    for (final a in racer.abilities)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(a, style: T.effect.copyWith(color: p.text)),
                      ),
                    if (racer.notes != null) ...[
                      const SizedBox(height: 6),
                      Text('RULEBOOK NOTES', style: T.caption.copyWith(color: p.text2, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(racer.notes!, style: T.body.copyWith(color: p.text.withValues(alpha: 0.85))),
                      const SizedBox(height: 10),
                    ],
                    if (!racer.verified)
                      Text('⚠ Ability text not verified. Check the physical card.',
                          style: T.caption.copyWith(color: p.warn)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: inRace ? p.mint : p.surface2,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                key: const Key('toggleRace'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => lineup.toggle(racer.id),
                child: SizedBox(
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(inRace ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                          color: inRace ? p.onAccent : p.mint),
                      const SizedBox(width: 8),
                      Text(inRace ? 'In this race' : 'Add to this race',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700, color: inRace ? p.onAccent : p.text)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFull(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (d) => GestureDetector(
        onTap: () => Navigator.pop(d),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: InteractiveViewer(
              maxScale: 4,
              child: SizedBox(width: 300, child: RacerCard(racer, radius: 14)),
            ),
          ),
        ),
      ),
    );
  }
}
