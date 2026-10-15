import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/models/zone.dart';
import 'package:vale_helper/state/phase_state.dart';
import 'package:vale_helper/state/settings.dart';
import 'package:vale_helper/state/tracker.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Tracker', () {
    test('a card lives in one zone and moves between zones', () async {
      final t = Tracker(await SharedPreferences.getInstance());
      t.put('imp', Zone.table);
      t.put('imp', Zone.hand);
      expect(t.zoneOf('imp'), Zone.hand);
      expect(t.count(Zone.table), 0);
      expect(t.idsIn(Zone.hand), ['imp']);
    });

    test('put with beforeId inserts at that position (drag to reorder)', () async {
      final t = Tracker(await SharedPreferences.getInstance());
      t
        ..put('a', Zone.hand)
        ..put('b', Zone.hand)
        ..put('c', Zone.table);
      t.put('c', Zone.hand, beforeId: 'a');
      expect(t.idsIn(Zone.hand), ['c', 'a', 'b']);
      t.put('a', Zone.hand, beforeId: 'missing');
      expect(t.idsIn(Zone.hand), ['c', 'b', 'a']);
    });

    test('clearZone only clears that zone', () async {
      final t = Tracker(await SharedPreferences.getInstance());
      t.put('a', Zone.table);
      t.put('b', Zone.field);
      t.clearZone(Zone.table);
      expect(t.zoneOf('a'), isNull);
      expect(t.zoneOf('b'), Zone.field);
    });

    test('survives a restart', () async {
      final prefs = await SharedPreferences.getInstance();
      Tracker(prefs)
        ..put('a', Zone.hand)
        ..put('b', Zone.field);
      final reloaded = Tracker(prefs);
      expect(reloaded.zoneOf('a'), Zone.hand);
      expect(reloaded.zoneOf('b'), Zone.field);
    });
  });

  group('PhaseState', () {
    test('next wraps around and clears ticks of the phase left', () async {
      final prefs = await SharedPreferences.getInstance();
      final p = PhaseState(prefs, phaseCount: 4);
      p.toggle('hunting.markers');
      p.toggle('action.stones');
      p.next(['hunting.markers']);
      expect(p.index, 1);
      expect(p.isChecked('hunting.markers'), isFalse);
      expect(p.isChecked('action.stones'), isTrue);
      p
        ..next([])
        ..next([])
        ..next([]);
      expect(p.index, 0);
    });

    test('survives a restart', () async {
      final prefs = await SharedPreferences.getInstance();
      PhaseState(prefs, phaseCount: 4)
        ..goTo(2)
        ..toggle('x');
      final reloaded = PhaseState(prefs, phaseCount: 4);
      expect(reloaded.index, 2);
      expect(reloaded.isChecked('x'), isTrue);
    });
  });

  test('Settings clamps the column count to 2..8 and persists it', () async {
    final prefs = await SharedPreferences.getInstance();
    final s = Settings(prefs)..columns = 20;
    expect(s.columns, Settings.maxColumns);
    s.columns = 3;
    expect(Settings(prefs).columns, 3);
  });
}
