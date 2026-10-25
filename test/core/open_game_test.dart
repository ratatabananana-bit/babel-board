import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/core/app_state.dart';
import 'package:vale_helper/modules/loaded_module.dart';
import 'package:vale_helper/modules/module_files.dart';
import 'package:vale_helper/modules/module_layer.dart';

import '../helpers.dart';

Map<String, Object> flowTab(String id, {bool inHub = false}) {
  final flow = {
    'type': 'flow',
    'id': id,
    'cyclic': false,
    'children': [
      {'type': 'step', 'id': '$id.setup', 'title': 'Setup'},
      {'type': 'step', 'id': '$id.play', 'title': 'Play'},
    ],
  };
  return {
    'label': id,
    'icon': 'flag',
    'block': inHub
        ? {
            'type': 'hub',
            'children': [
              {'type': 'entry', 'label': id, 'block': flow},
            ],
          }
        : flow,
  };
}

void main() {
  test('the first flow keeps the legacy keys, a second flow gets its own prefix', () async {
    SharedPreferences.setMockInitialValues({'mod.mini.phase.index': 1});
    final prefs = await SharedPreferences.getInstance();
    final module = await loadMini(edit: (m) => (m['tabs'] as List).add(flowTab('scenario')));
    final g = OpenGame.load(prefs, module);
    expect(g.flows.first!.index, 1, reason: 'the legacy key is read by the first flow');
    expect(g.flow, same(g.flows.first), reason: 'the old accessor still names the first flow');
    g.flows['scenario']!.next(const []);
    expect(prefs.getInt('mod.mini.flow.scenario.phase.index'), 1);
    expect(prefs.getInt('mod.mini.phase.index'), 1, reason: 'untouched');
  });

  test('a flow inside a hub gets a FlowState too', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final module = await loadMini(edit: (m) => (m['tabs'] as List).add(flowTab('inner', inHub: true)));
    final g = OpenGame.load(prefs, module);
    expect(g.flows['inner'], isNotNull);
    expect(g.flows['flow'], isNotNull, reason: "the mini module's own flow has the default id");
    expect(g.flows.byId.length, 2);
  });

  test('a game sees its own items, zones and steps: with the expansion and without it', () async {
    SharedPreferences.setMockInitialValues({
      'mod.mini.phase.index': 1,
      'mod.mini.phase.step': 'two',
      'mod.mini.zones': '{"imp":"a","kraken":"c"}',
    });
    final prefs = await SharedPreferences.getInstance();
    final base = await readModuleLayer(DirectoryModuleFiles(miniDir));
    final plus = await readModuleLayer(DirectoryModuleFiles(plusDir));

    final merged = OpenGame.load(prefs, buildGame(base, [plus]).module);
    expect(merged.flow!.index, 2, reason: 'step "two" moved down one when "mid" was inserted');
    expect(merged.zones.total, 2);

    final alone = OpenGame.load(prefs, buildModule(base));
    expect(alone.flow!.index, 1);
    expect(alone.zones.total, 1, reason: 'the Kraken in Lane C is not part of the base game');
  });
}
