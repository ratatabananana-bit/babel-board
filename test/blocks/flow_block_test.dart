import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/blocks/flow/flow_state.dart';
import 'package:vale_helper/modules/module_state.dart';

import '../helpers.dart';

Map<String, Object> prefsWith(Map<String, String> zones) => {
  'app.lastGame': 'mini',
  'mod.mini.zones': jsonEncode(zones),
};

void main() {
  testWidgets('phase bar, "n steps left", and Next needs a second tap with open steps', (tester) async {
    await pumpModules(tester, tab: 'Flow');
    expect(find.text('Round'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Wild'), findsOneWidget);
    expect(find.text('Step one'), findsOneWidget);
    expect(find.text('2 steps left'), findsOneWidget);

    await tester.tap(find.text('Next: Step two'));
    await tester.pumpAndSettle();
    expect(find.text('Tap again to skip them'), findsOneWidget);
    expect(scoped<FlowState>(tester).index, 0);

    await tester.tap(find.text('Next: Step two'));
    await tester.pumpAndSettle();
    expect(scoped<FlowState>(tester).index, 1);
    expect(find.text('Step two'), findsOneWidget);
    expect(find.text('Next: Step one'), findsOneWidget, reason: 'cyclic flow wraps');
  });

  testWidgets('ticking every step makes Next go in one tap', (tester) async {
    await pumpModules(tester, tab: 'Flow');
    await tester.tap(find.text('Tick me'));
    await tester.pump();
    await tester.tap(find.text('Clear Lane A'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.text('Next: Step two'));
    await tester.pumpAndSettle();
    expect(scoped<FlowState>(tester).index, 1);
    expect(scoped<FlowState>(tester).isChecked('one.a'), isFalse, reason: 'ticks of the step left are cleared');
  });

  testWidgets('clearZone action pill empties that zone only and ticks its row', (tester) async {
    await pumpModules(tester, tab: 'Flow', prefs: prefsWith({'imp': 'a', 'nessie': 'b'}));
    final zones = scoped<ZoneState>(tester);
    expect(zones.count('a'), 1);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(zones.count('a'), 0);
    expect(zones.zoneOf('nessie'), 'b');
    expect(scoped<FlowState>(tester).isChecked('one.clear'), isTrue);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Clear'), findsNothing, reason: 'the pill hides once the row is ticked');
  });

  testWidgets('non-cyclic flow: the last step offers New game, which resets zones and flow', (tester) async {
    await pumpModules(
      tester,
      tab: 'Flow',
      prefs: prefsWith({'imp': 'a'}),
      edit: (m) => (m['tabs'] as List)[2]['block']['cyclic'] = false,
    );
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(scoped<FlowState>(tester).index, 1);
    expect(find.text('New game'), findsOneWidget);
    expect(find.text('Nothing in Lane B has an active effect.'), findsOneWidget);

    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    expect(find.text('Start a new game?'), findsOneWidget);
    expect(find.text('Clears every lane and goes back to Step one.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'New game'));
    await tester.pumpAndSettle();
    expect(scoped<ZoneState>(tester).total, 0);
    expect(scoped<FlowState>(tester).index, 0);
  });

  testWidgets('cardChecklist lists only the items in zone b matching the filter', (tester) async {
    await pumpModules(tester, tab: 'Flow', prefs: prefsWith({'imp': 'b', 'undine': 'b', 'nessie': 'a'}));
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(find.text('Imp'), findsOneWidget);
    expect(find.text('Recover.'), findsOneWidget);
    expect(find.text('Undine'), findsNothing);
    expect(find.text('Nessie'), findsNothing);
    expect(find.text('0 / 1'), findsOneWidget);
    expect(find.text('1 step left'), findsOneWidget);
    await tester.tap(find.text('Imp'));
    await tester.pumpAndSettle();
    expect(scoped<FlowState>(tester).isChecked('card.imp'), isTrue);
  });

  testWidgets('Rules sheet and Setup sheet open from the header', (tester) async {
    await pumpModules(tester, tab: 'Flow');
    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();
    expect(find.text('Rule one.'), findsOneWidget);
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setup checklist'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a first player'), findsOneWidget);
    expect(find.text('Shuffle everything.'), findsOneWidget);
  });

  testWidgets('a moveZone row moves Lane A into Lane B and ticks itself; clearZones empties both', (tester) async {
    await pumpModules(
      tester,
      tab: 'Flow',
      prefs: prefsWith({'imp': 'a', 'nessie': 'b'}),
      edit: (m) {
        final step = ((m['tabs'] as List)[2]['block']['children'] as List)[0] as Map;
        (step['checklist'] as List).addAll([
          {
            'id': 'one.move',
            'text': 'Return cards',
            'action': {
              'type': 'moveZone',
              'from': ['a'],
              'to': 'b',
            },
          },
          {
            'id': 'one.wipe',
            'text': 'Wipe both lanes',
            'action': {
              'type': 'clearZones',
              'zones': ['a', 'b'],
            },
            'actionLabel': 'Wipe',
          },
        ]);
      },
    );
    final zones = scoped<ZoneState>(tester);
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    expect(zones.zoneOf('imp'), 'b');
    expect(zones.idsIn('b'), ['nessie', 'imp'], reason: 'moved items join the end of the lane');
    expect(scoped<FlowState>(tester).isChecked('one.move'), isTrue);

    await tester.tap(find.text('Wipe'));
    await tester.pumpAndSettle();
    expect(zones.total, 0);
    expect(scoped<FlowState>(tester).isChecked('one.wipe'), isTrue);
  });

  testWidgets('New game from the second flow resets both flows and clears zones', (tester) async {
    await pumpModules(
      tester,
      tab: 'Scenario',
      prefs: prefsWith({'imp': 'a'}),
      edit: (m) => (m['tabs'] as List).add({
        'label': 'Scenario',
        'icon': 'flag',
        'block': {
          'type': 'flow',
          'id': 'scenario',
          'title': 'Scenario',
          'cyclic': false,
          'children': [
            {'type': 'step', 'id': 'sc.setup', 'title': 'Setup'},
            {'type': 'step', 'id': 'sc.cleanup', 'title': 'Cleanup'},
          ],
        },
      }),
    );
    final flows = scoped<FlowStates>(tester);
    flows.first!.goTo(1);
    await tester.tap(find.text('Cleanup'));
    await tester.pumpAndSettle();
    expect(flows['scenario']!.index, 1);
    expect(flows.first!.index, 1);

    // The last step of a non-cyclic flow offers New game as its Next button.
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    expect(find.text('Start a new game?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'New game'));
    await tester.pumpAndSettle();
    expect(scoped<ZoneState>(tester).total, 0);
    expect(flows['scenario']!.index, 0);
    expect(flows.first!.index, 0, reason: 'New game is for the whole module, not one tracker');
  });
}
