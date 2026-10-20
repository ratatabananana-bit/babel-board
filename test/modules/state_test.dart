import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/blocks/flow/flow_state.dart';
import 'package:vale_helper/modules/module_state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ZoneState', () {
    test('an item lives in one zone and moves between zones', () async {
      final z = ZoneState(await SharedPreferences.getInstance(), 'mini');
      z.put('imp', 'a');
      z.put('imp', 'b');
      expect(z.zoneOf('imp'), 'b');
      expect(z.count('a'), 0);
      expect(z.idsIn('b'), ['imp']);
      expect(z.total, 1);
    });

    test('put with beforeId inserts at that position (drag to reorder)', () async {
      final z = ZoneState(await SharedPreferences.getInstance(), 'mini');
      z
        ..put('a', 'b')
        ..put('b', 'b')
        ..put('c', 'a');
      z.put('c', 'b', beforeId: 'a');
      expect(z.idsIn('b'), ['c', 'a', 'b']);
      z.put('a', 'b', beforeId: 'missing');
      expect(z.idsIn('b'), ['c', 'b', 'a']);
    });

    test('moveAll moves items from several zones into one, keeping order', () async {
      final z = ZoneState(await SharedPreferences.getInstance(), 'mini');
      z
        ..put('a', 'hand')
        ..put('b', 'discard')
        ..put('c', 'lost')
        ..put('d', 'pool');
      z.moveAll(['hand', 'discard', 'lost'], 'pool');
      expect(z.idsIn('pool'), ['d', 'a', 'b', 'c'], reason: 'moved items join the end of the lane');
      expect(z.count('hand') + z.count('discard') + z.count('lost'), 0);
      var notified = 0;
      z.addListener(() => notified++);
      z.moveAll(['hand'], 'pool');
      expect(notified, 0, reason: 'nothing moved, nothing saved');
    });

    test('clearZone only clears that zone; remove and clearAll', () async {
      final z = ZoneState(await SharedPreferences.getInstance(), 'mini');
      z.put('x', 'a');
      z.put('y', 'b');
      z.clearZone('a');
      expect(z.zoneOf('x'), isNull);
      expect(z.zoneOf('y'), 'b');
      z.remove('y');
      expect(z.total, 0);
      z.put('x', 'a');
      z.clearAll();
      expect(z.total, 0);
    });

    test('survives a restart under mod.<id>.zones', () async {
      final prefs = await SharedPreferences.getInstance();
      ZoneState(prefs, 'mini')
        ..put('x', 'a')
        ..put('y', 'b');
      expect(prefs.getString('mod.mini.zones'), isNotNull);
      final reloaded = ZoneState(prefs, 'mini');
      expect(reloaded.zoneOf('x'), 'a');
      expect(reloaded.idsIn('b'), ['y']);
    });

    test('two module ids never share state', () async {
      final prefs = await SharedPreferences.getInstance();
      ZoneState(prefs, 'one').put('x', 'a');
      expect(ZoneState(prefs, 'two').zoneOf('x'), isNull);
      expect(ZoneState(prefs, 'two').total, 0);
    });
  });

  group('FlowState', () {
    test('next wraps around and clears ticks of the step left', () async {
      final prefs = await SharedPreferences.getInstance();
      final p = FlowState(prefs, prefix: 'mod.mini.', phaseCount: 4);
      p.toggle('one.a');
      p.toggle('two.b');
      p.next(['one.a']);
      expect(p.index, 1);
      expect(p.isChecked('one.a'), isFalse);
      expect(p.isChecked('two.b'), isTrue);
      p
        ..next([])
        ..next([])
        ..next([]);
      expect(p.index, 0);
    });

    test('survives a restart under the module prefix', () async {
      final prefs = await SharedPreferences.getInstance();
      FlowState(prefs, prefix: 'mod.mini.', phaseCount: 4)
        ..goTo(2)
        ..toggle('x');
      expect(prefs.getInt('mod.mini.phase.index'), 2);
      final reloaded = FlowState(prefs, prefix: 'mod.mini.', phaseCount: 4);
      expect(reloaded.index, 2);
      expect(reloaded.isChecked('x'), isTrue);
    });
  });
}
