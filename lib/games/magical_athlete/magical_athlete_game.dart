import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/flow/flow_rules.dart';
import '../../core/flow/flow_screen.dart';
import '../../blocks/flow/flow_state.dart';
import '../../core/game_module.dart';
import '../../core/theme.dart';
import 'models/racer.dart';
import 'screens/racers_screen.dart';
import 'screens/this_race_screen.dart';
import 'state/lineup.dart';

/// Magical Athlete: racer lookup (English abilities), this race's lineup, and the game flow.
class MagicalAthleteGame implements GameModule {
  @override
  String get id => 'ma';

  @override
  String get title => 'Magical Athlete';

  @override
  Widget icon(double size) => Builder(
    builder: (context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: context.pal.mint, shape: BoxShape.circle),
      child: Icon(Icons.directions_run_rounded, size: size * 0.6, color: context.pal.onAccent),
    ),
  );

  late final List<Racer> racers;
  late final Rules rules;
  late final Lineup lineup;
  late final FlowState flow;

  @override
  Future<void> load(AssetBundle bundle, SharedPreferences prefs) async {
    racers = await loadRacers(bundle);
    rules = await loadRules(bundle, 'assets/games/magical_athlete/rules_en.json');
    lineup = Lineup(prefs, prefix: '$id.');
    flow = FlowState(prefs, prefix: '$id.', phaseCount: rules.phases.length);
  }

  late final FlowConfig _flow = FlowConfig(
    rules: rules,
    newGameBody: 'Clears this race\'s lineup and goes back to the start.',
    resetGame: (_) => lineup.clear(),
    runAction: (context, action) async {
      if (action != 'clearRace') return false;
      lineup.clear();
      return true;
    },
  );

  @override
  List<GameTab> get tabs => [
    GameTab(label: 'Racers', icon: Icons.style_rounded, builder: (_) => const RacersScreen()),
    GameTab(
      label: 'This race',
      icon: Icons.sports_score_rounded,
      builder: (_) => const ThisRaceScreen(),
      badge: (context) => context.watch<Lineup>().count,
    ),
    GameTab(label: 'Game', icon: Icons.flag_rounded, builder: (_) => const FlowScreen()),
  ];

  @override
  Widget wrap(Widget child) => MultiProvider(
    providers: [
      Provider<List<Racer>>.value(value: racers),
      ChangeNotifierProvider<Lineup>.value(value: lineup),
      ChangeNotifierProvider<FlowState>.value(value: flow),
      Provider<FlowConfig>.value(value: _flow),
    ],
    child: child,
  );
}
