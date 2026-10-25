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
      final p = FlowState(prefs, prefix: 'mod.mini.', steps: const ['one', 'two', 'three', 'four']);
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
      FlowState(prefs, prefix: 'mod.mini.', steps: const ['one', 'two', 'three', 'four'])
        ..goTo(2)
        ..toggle('x');
      expect(prefs.getInt('mod.mini.phase.index'), 2);
      final reloaded = FlowState(prefs, prefix: 'mod.mini.', steps: const ['one', 'two', 'three', 'four']);
      expect(reloaded.index, 2);
      expect(reloaded.isChecked('x'), isTrue);
    });

    test('saves the step id beside the index', () async {
      final prefs = await SharedPreferences.getInstance();
      FlowState(prefs, prefix: 'mod.mini.', steps: const ['one', 'two', 'three']).goTo(1);
      expect(prefs.getString('mod.mini.phase.step'), 'two');
    });

    test('reopens on its saved step after an expansion inserts a step before it', () async {
      SharedPreferences.setMockInitialValues({'mod.mini.phase.index': 1, 'mod.mini.phase.step': 'two'});
      final prefs = await SharedPreferences.getInstance();
      final f = FlowState(prefs, prefix: 'mod.mini.', steps: const ['one', 'mid', 'two']);
      expect(f.index, 2);
    });

    test('a 3.2.x save (index only) is pinned to its step; a step inserted later cannot move it', () async {
      SharedPreferences.setMockInitialValues({'mod.vale.phase.index': 3});
      final prefs = await SharedPreferences.getInstance();
      FlowState(prefs, prefix: 'mod.vale.', steps: const ['hunting', 'action', 'resolution', 'end']);
      expect(prefs.getString('mod.vale.phase.step'), 'end');
      const withCurse = ['hunting', 'action', 'resolution', 'curse', 'end'];
      final merged = FlowState(prefs, prefix: 'mod.vale.', steps: withCurse);
      expect(merged.index, 4, reason: 'still End of round');
    });

    test('an old save with only an index opens there; an unknown step id falls back to it', () async {
      SharedPreferences.setMockInitialValues({'mod.mini.phase.index': 1});
      final prefs = await SharedPreferences.getInstance();
      expect(FlowState(prefs, prefix: 'mod.mini.', steps: const ['one', 'two']).index, 1);
      await prefs.setString('mod.mini.phase.step', 'gone');
      expect(FlowState(prefs, prefix: 'mod.mini.', steps: const ['one', 'two', 'three']).index, 1);
    });
  });

  group('ZoneState seen through a game', () {
    test('entries for items or zones the game lacks are hidden and kept', () async {
      final p = await SharedPreferences.getInstance();
      ZoneState(p, 'mini')
        ..put('imp', 'a')
        ..put('kraken', 'a')
        ..put('nessie', 'c');
      final z = ZoneState(p, 'mini', items: {'imp', 'nessie'}, zones: {'a', 'b'});
      expect(z.total, 1);
      expect(z.idsIn('a'), ['imp']);
      expect(z.count('a'), 1);
      expect(z.zoneOf('kraken'), isNull);
      expect(z.zoneOf('nessie'), isNull, reason: 'its zone is not in this game');

      z.put('imp', 'b');
      expect(ZoneState(p, 'mini').total, 3, reason: 'hidden entries stay saved through changes');
    });

    test('forget drops the entries of the items and zones named, seen or not, and nothing else', () async {
      final p = await SharedPreferences.getInstance();
      ZoneState(p, 'mini')
        ..put('imp', 'a')
        ..put('kraken', 'a')
        ..put('nessie', 'c')
        ..put('leviathan', 'd');
      final z = ZoneState(p, 'mini', items: {'imp'}, zones: {'a'})..forget(items: {'kraken'}, zones: {'c'});
      final saved = ZoneState(p, 'mini');
      expect([for (final id in ['imp', 'kraken', 'nessie', 'leviathan']) saved.zoneOf(id)], ['a', null, null, 'd']);
      expect(z.total, 1);
    });

    test('clearAll (new game) forgets hidden entries too', () async {
      final p = await SharedPreferences.getInstance();
      ZoneState(p, 'mini').put('kraken', 'a');
      ZoneState(p, 'mini', items: {'imp'}, zones: {'a'}).clearAll();
      expect(ZoneState(p, 'mini').total, 0);
    });
  });
}
