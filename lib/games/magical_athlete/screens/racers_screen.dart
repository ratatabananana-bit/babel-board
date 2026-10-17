import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/settings.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/reflow_grid.dart';
import '../../../core/widgets/search_top_bar.dart';
import '../models/racer.dart';
import '../state/lineup.dart';
import '../widgets/racer_card.dart';
import 'racer_sheet.dart';

/// Every racer as a card picture; search by name or ability. Tap for the English ability.
class RacersScreen extends StatefulWidget {
  const RacersScreen({super.key});

  @override
  State<RacersScreen> createState() => _RacersScreenState();
}

class _RacersScreenState extends State<RacersScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final all = context.read<List<Racer>>();
    final columns = context.watch<Settings>().columns;
    final q = _search.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? all
        : all
              .where(
                (r) =>
                    r.name.toLowerCase().contains(q) ||
                    (r.nameZh?.contains(q) ?? false) ||
                    r.abilities.any((a) => a.toLowerCase().contains(q)),
              )
              .toList();

    return Column(
      children: [
        SearchTopBar(search: _search, hint: 'Search racers'),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text('No racers match "${_search.text}".', style: T.body.copyWith(color: p.text2)),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    ReflowGrid<Racer>(
                      items: shown,
                      idOf: (r) => r.id,
                      columns: columns,
                      aspect: racerAspect,
                      extraHeight: RacerTile.nameHeight,
                      tileBuilder: (r) => RacerTile(racer: r),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Card picture with the English name below; racers in this race get a mint ring and band.
class RacerTile extends StatelessWidget {
  const RacerTile({super.key, required this.racer});
  final Racer racer;

  /// The name is printed on the card itself, so nothing goes below the tile.
  static const nameHeight = 0.0;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final inRace = context.select<Lineup, bool>((l) => l.contains(racer.id));
    return Semantics(
      button: true,
      label: inRace ? '${racer.name}, in this race' : racer.name,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => showRacerSheet(context, racer),
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              foregroundDecoration: inRace
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.mint, width: 2.5),
                    )
                  : null,
              child: Stack(
                children: [
                  RacerCard(racer),
                  if (inRace)
                    // Top edge, so the racer's name on the card stays readable.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.mint,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'IN RACE',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: p.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
