import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/blocks/flow/flow_state.dart';
import 'package:vale_helper/core/app_state.dart';
import 'package:vale_helper/library/migration.dart';
import 'package:vale_helper/modules/module_state.dart';

void main() {
  test('migrateLegacyPrefs maps the last game to module ids and keeps legacy keys', () async {
    SharedPreferences.setMockInitialValues({
      'vale.tracker.zones': '{"imp":"hand"}',
      'ma.lineup': ['banana'],
      'app.lastGame': 'ma',
    });
    final p = await SharedPreferences.getInstance();
    await migrateLegacyPrefs(p);
    expect(p.getString(AppState.lastGameKey), 'magical-athlete');
    expect(p.getString('vale.tracker.zones'), '{"imp":"hand"}');
    expect(p.getStringList('ma.lineup'), ['banana']);

    await p.setString(AppState.lastGameKey, 'vale');
    await migrateLegacyPrefs(p);
    expect(p.getString(AppState.lastGameKey), 'vale-of-eternity');
  });

  test('pre-multi-game Vale keys move under vale. and Vale reopens (today\'s behavior)', () async {
    SharedPreferences.setMockInitialValues({
      'tracker.zones': '{"imp":"hand"}',
      'phase.index': 2,
      'phase.checked': ['x'],
    });
    final p = await SharedPreferences.getInstance();
    await migrateLegacyPrefs(p);
    expect(p.containsKey('tracker.zones'), isFalse);
    expect(p.getString('vale.tracker.zones'), '{"imp":"hand"}');
    expect(p.getInt('vale.phase.index'), 2);
    expect(p.getStringList('vale.phase.checked'), ['x']);
    expect(p.getString(AppState.lastGameKey), 'vale-of-eternity');
  });

  test('does nothing on a fresh install', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await migrateLegacyPrefs(p);
    expect(p.getKeys(), isEmpty);
  });

  test('adoptLegacyState moves Magical Athlete lineup and phase into the module; twice is a no-op', () async {
    SharedPreferences.setMockInitialValues({
      'ma.lineup': ['banana', 'baba_yaga'],
      'ma.phase.index': 2,
      'ma.phase.checked': ['race2.reveal'],
      'vale.tracker.zones': '{"imp":"hand"}',
    });
    final p = await SharedPreferences.getInstance();
    await adoptLegacyState(p, 'magical-athlete');
    final zones = ZoneState(p, 'magical-athlete');
    expect(zones.idsIn('race'), ['banana', 'baba_yaga']);
    final flow = FlowState(p, prefix: 'mod.magical-athlete.', phaseCount: 6);
    expect(flow.index, 2);
    expect(flow.isChecked('race2.reveal'), isTrue);
    expect(p.containsKey('ma.lineup'), isFalse);
    expect(p.containsKey('ma.phase.index'), isFalse);
    expect(p.getString('vale.tracker.zones'), '{"imp":"hand"}', reason: 'the other game is untouched');

    zones.remove('banana');
    await adoptLegacyState(p, 'magical-athlete');
    expect(ZoneState(p, 'magical-athlete').idsIn('race'), ['baba_yaga']);
  });

  test('adoptLegacyState moves Vale zones and phase, never over existing module state', () async {
    SharedPreferences.setMockInitialValues({
      'vale.tracker.zones': '{"imp":"hand","nessie":"field"}',
      'vale.phase.index': 1,
      'vale.phase.checked': ['action.stones'],
    });
    final p = await SharedPreferences.getInstance();
    await adoptLegacyState(p, 'vale-of-eternity');
    expect(ZoneState(p, 'vale-of-eternity').zoneOf('nessie'), 'field');
    expect(FlowState(p, prefix: 'mod.vale-of-eternity.', phaseCount: 4).index, 1);
    expect(p.containsKey('vale.tracker.zones'), isFalse);

    // Legacy keys reappearing later never overwrite what the module already saved.
    await p.setString('vale.tracker.zones', '{"imp":"table"}');
    await adoptLegacyState(p, 'vale-of-eternity');
    expect(ZoneState(p, 'vale-of-eternity').zoneOf('imp'), 'hand');
    expect(p.containsKey('vale.tracker.zones'), isFalse, reason: 'stale legacy keys are dropped');
  });

  test('adoptLegacyState ignores modules without legacy state', () async {
    SharedPreferences.setMockInitialValues({
      'ma.lineup': ['banana'],
    });
    final p = await SharedPreferences.getInstance();
    await adoptLegacyState(p, 'heat');
    expect(p.getStringList('ma.lineup'), ['banana']);
    expect(p.getKeys(), hasLength(1));
  });
}
