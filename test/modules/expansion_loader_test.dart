import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/module_format/block_specs.dart';
import 'package:vale_helper/modules/loaded_module.dart';
import 'package:vale_helper/modules/module_files.dart';
import 'package:vale_helper/modules/module_layer.dart';

import '../helpers.dart';

Future<ModuleLayer> mini() => readModuleLayer(DirectoryModuleFiles(miniDir));
Future<ModuleLayer> plus([void Function(Map<String, dynamic> manifest)? edit]) =>
    readModuleLayer(edit == null ? DirectoryModuleFiles(plusDir) : MemoryModuleFiles(plusFiles(edit)));

void main() {
  test('a layer knows what it is: the base game, or an expansion of one', () async {
    final base = await mini();
    expect(base.id, 'mini');
    expect(base.expands, isNull);
    final e = await plus();
    expect(e.id, 'mini-plus');
    expect(e.name, 'Mini Plus');
    expect(e.icon, 'images/icon.webp');
    expect(e.expands!.id, 'mini');
    expect(e.data.items['items']!.single['id'], 'kraken');
  });

  test('a layer names the item and zone ids it declares itself', () async {
    final e = await plus();
    expect(e.itemIds, {'kraken'});
    expect(e.zoneIds, {'c'});
    final base = await mini();
    expect(base.itemIds, containsAll(['imp', 'nessie']));
    expect(base.zoneIds, {'a', 'b'});
  });

  test('base + mini-plus: items, zone, lane, step, tab and picture all merge', () async {
    final g = buildGame(await mini(), [await plus()]);
    expect(g.rejected, isEmpty);
    final m = g.module;
    expect(m.manifest.id, 'mini', reason: 'the game stays the base game');
    expect(m.item('items', 'kraken'), isNotNull);
    expect(m.items('items'), hasLength(5));
    expect([for (final z in m.manifest.zones) z.id], ['a', 'b', 'c']);
    expect([for (final t in m.manifest.tabs) t.id], ['gallery', 'more', 'board', 'flow', 'text']);
    expect([for (final z in (m.manifest.tabs[2].block as BoardSpec).zones) z.zone], ['c', 'a', 'b']);
    final flow = m.manifest.tabs[3].block as FlowSpec;
    expect([for (final s in flow.steps) s.id], ['one', 'mid', 'two']);
    expect(flow.reminders, ['Rule one.', 'Rule two.', 'Rule three.']);
    final kraken = m.item('items', 'kraken')!;
    expect(kraken.imageRef(m.manifest.collections['items']!), '@mini-plus/images/kraken.webp');
    expect(m.files.image('@mini-plus/images/kraken.webp'), isA<ModuleFileImage>());
    expect(m.files.image('images/imp.webp'), isA<ModuleFileImage>(), reason: 'base pictures still resolve');
    expect([for (final x in m.expansions) (x.id, x.name, x.version)], [('mini-plus', 'Mini Plus', '1.0.0')]);
  });

  test('an expansion whose anchor is gone is rejected; the base still builds', () async {
    final g = buildGame(await mini(), [
      await plus((m) => ((m['tabs'] as List)[2]['block']['children'] as List)[0]['after'] = 'gone'),
    ]);
    expect(g.rejected['mini-plus']!.single.message, 'No element "gone" to place this after');
    expect(g.module.item('items', 'kraken'), isNull);
    expect(g.module.expansions, isEmpty);
    expect(g.module.files, isA<DirectoryModuleFiles>(), reason: 'no layers when nothing merged');
  });

  test('an expansion for another game is rejected', () async {
    final g = buildGame(await mini(), [
      await plus((m) => m['expands'] = {'id': 'other'}),
    ]);
    expect(g.rejected['mini-plus']!.single.message, 'This is an expansion for "other", not for "mini"');
  });

  test('an expansion whose collection file is missing is rejected with the read error', () async {
    final g = buildGame(await mini(), [await plus((m) => m['collections']['items']['items'] = 'data/nope.json')]);
    expect(g.rejected['mini-plus']!.single.path, 'collections.items');
  });

  test('loadModule refuses an expansion on its own', () async {
    await expectLater(
      loadModule(DirectoryModuleFiles(plusDir)),
      throwsA(isA<ModuleLoadException>().having((e) => e.issues.map((i) => i.path), 'paths', contains('expands'))),
    );
  });

  test('a broken base throws, whatever its expansions', () async {
    final broken = await readModuleLayer(MemoryModuleFiles(withManifest(miniFiles(), (m) => m['tabs'] = [])));
    final expansion = await plus();
    expect(() => buildGame(broken, [expansion]), throwsA(isA<ModuleLoadException>()));
  });

  test('LayeredModuleFiles reads text from the base and pictures from the named layer', () async {
    final files = LayeredModuleFiles(DirectoryModuleFiles(miniDir), {'mini-plus': DirectoryModuleFiles(plusDir)});
    expect(await files.readText('module.json'), contains('"id": "mini"'));
    expect((files.image('@mini-plus/images/kraken.webp') as ModuleFileImage).path, contains('mini_expansion'));
    expect(files.image('@mini-plus/images/none.webp'), isNull);
    expect(files.image('@someone-else/images/imp.webp'), isNull, reason: 'an unknown layer is a missing file');
    expect(files.image('https://example.com/x.png'), isNotNull);
  });
}
