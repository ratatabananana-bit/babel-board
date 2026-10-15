import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/flow/flow_rules.dart';
import '../../core/flow/flow_screen.dart';
import '../../core/flow/flow_state.dart';
import '../../core/game_module.dart';
import 'data/loaders.dart';
import 'models/card.dart';
import 'models/zone.dart';
import 'screens/cards_screen.dart';
import 'screens/my_cards_screen.dart';
import 'state/tracker.dart';
import 'widgets/card_art.dart';

/// Vale of Eternity: card lookup, your Table / Hand / Field, and the round checklist.
class ValeGame implements GameModule {
  @override
  String get id => 'vale';

  @override
  String get title => 'Vale of Eternity';

  @override
  Widget icon(double size) =>
      ClipOval(child: Image.asset('assets/symbols/dragon.webp', width: size, height: size));

  late final List<GameCard> cards;
  late final Rules rules;
  late final Tracker tracker;
  late final FlowState flow;

  @override
  Future<void> load(AssetBundle bundle, SharedPreferences prefs) async {
    cards = await loadCards(bundle);
    rules = await loadRules(bundle, 'assets/rules_en.json');
    tracker = Tracker(prefs, prefix: '$id.');
    flow = FlowState(prefs, prefix: '$id.', phaseCount: rules.phases.length);
  }

  late final FlowConfig _flow = FlowConfig(
    rules: rules,
    newGameBody: 'Clears all your tracked cards and goes back to Hunting.',
    resetGame: (_) => tracker.clearAll(),
    runAction: (context, action) async {
      if (action != 'clearTable') return false;
      tracker.clearZone(Zone.table);
      return true;
    },
    // In Resolution, your Field cards with Active effects are the checklist.
    itemsFor: (context, phase) {
      if (phase.id != 'resolution') return null;
      final byId = {for (final c in cards) c.id: c};
      return [
        for (final id in context.watch<Tracker>().idsIn(Zone.field))
          if (byId[id] case final c? when c.hasActive)
            FlowItem(
              id: 'res.${c.id}',
              text: c.name,
              sub: c.effects.firstWhere((e) => e.type == EffectType.active).text,
              leading: CardArt(c, radius: 6),
            ),
      ];
    },
  );

  @override
  List<GameTab> get tabs => [
        GameTab(label: 'Cards', icon: Icons.style_rounded, builder: (_) => const CardsScreen()),
        GameTab(
          label: 'My cards',
          icon: Icons.back_hand_rounded,
          builder: (_) => const MyCardsScreen(),
          badge: (context) => context.watch<Tracker>().total,
        ),
        GameTab(label: 'Round', icon: Icons.flag_rounded, builder: (_) => const FlowScreen()),
      ];

  @override
  Widget wrap(Widget child) => MultiProvider(
        providers: [
          Provider<List<GameCard>>.value(value: cards),
          ChangeNotifierProvider<Tracker>.value(value: tracker),
          ChangeNotifierProvider<FlowState>.value(value: flow),
          Provider<FlowConfig>.value(value: _flow),
        ],
        child: child,
      );
}
