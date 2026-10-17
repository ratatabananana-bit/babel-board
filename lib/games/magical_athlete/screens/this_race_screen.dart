import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/game_switcher.dart';
import '../../../core/theme.dart';
import '../models/racer.dart';
import '../state/lineup.dart';
import '../widgets/racer_card.dart';
import 'racer_sheet.dart';

/// The racers on the track right now, with every ability in full, so you can see how they
/// interact. Add racers from their sheet in the Racers tab.
class ThisRaceScreen extends StatelessWidget {
  const ThisRaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final lineup = context.watch<Lineup>();
    final byId = {for (final r in context.read<List<Racer>>()) r.id: r};
    final racers = [for (final id in lineup.ids) ?byId[id]];

    return Column(
      children: [
        SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
            child: Row(
              children: [
                const GameSwitcherButton(),
                const SizedBox(width: 10),
                const Text('This race', style: T.title),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${racers.length} racers', style: T.body.copyWith(color: p.text2)),
                ),
                if (racers.isNotEmpty) TextButton(onPressed: lineup.clear, child: const Text('Clear')),
              ],
            ),
          ),
        ),
        Expanded(
          child: racers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No racers yet.\nIn Racers, tap a racer and choose "Add to this race" for every '
                      'racer on the track.',
                      textAlign: TextAlign.center,
                      style: T.body.copyWith(color: p.text2),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: racers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _RaceRow(racer: racers[i]),
                ),
        ),
      ],
    );
  }
}

class _RaceRow extends StatelessWidget {
  const _RaceRow({required this.racer});
  final Racer racer;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showRacerSheet(context, racer),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 64, child: RacerArt(racer)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(racer.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    if (racer.powerName != null)
                      Text(
                        racer.powerName!,
                        style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: p.text2),
                      ),
                    const SizedBox(height: 4),
                    for (final a in racer.abilities)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(a, style: TextStyle(fontSize: 15.5, height: 1.35, color: p.text)),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove from this race',
                icon: Icon(Icons.close_rounded, color: p.muted),
                onPressed: () => context.read<Lineup>().remove(racer.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
