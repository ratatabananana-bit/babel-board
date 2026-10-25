import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/core/app_state.dart';
import 'package:vale_helper/library/library_controller.dart';
import 'package:vale_helper/library/module_store.dart';
import 'package:vale_helper/library/repository.dart';
import 'package:vale_helper/library/startup.dart';

import '../helpers.dart';

Uint8List zipOf(Map<String, List<int>> files) {
  final a = Archive();
  for (final e in files.entries) {
    a.addFile(ArchiveFile(e.key, e.value.length, e.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}

Uint8List jsonBytes(Object j) => Uint8List.fromList(utf8.encode(jsonEncode(j)));

/// Serves the mini module's pictures by file name, like a picture host.
http.Client imageServer() => MockClient((req) async {
  final bytes = miniFiles()['images/${req.url.pathSegments.last}'];
  return bytes == null ? http.Response('nope', 404) : http.Response.bytes(bytes, 200);
});

void main() {
  late Directory parent;
  late Directory root;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    parent = await Directory.systemTemp.createTemp('expansions_test_');
    root = Directory('${parent.path}${Platform.pathSeparator}modules')..createSync();
  });
  tearDown(() => parent.deleteSync(recursive: true));

  List<String> folders() => [
    for (final d in root.listSync().whereType<Directory>()) d.path.split(Platform.pathSeparator).last,
  ];

  group('ModuleStore', () {
    test('an expansion is refused while its base is missing, and leaves nothing behind', () async {
      final store = ModuleStore(root);
      await expectLater(
        store.installBytes(zipOf(plusFiles())),
        throwsA(
          isA<InstallException>().having(
            (e) => e.message,
            'message',
            'Mini Plus is an expansion for mini. Install mini first.',
          ),
        ),
      );
      expect(folders(), isEmpty, reason: 'no module folder and no staging left');
    });

    test('an expansion installs next to its base and lists as an expansion', () async {
      final store = ModuleStore(root);
      await store.installBytes(zipOf(miniFiles()));
      final m = await store.installBytes(zipOf(plusFiles()));
      expect(m.id, 'mini-plus');
      final listed = {for (final i in await store.list()) i.id: i};
      expect(listed.keys, unorderedEquals(['mini', 'mini-plus']));
      expect(listed['mini']!.isExpansion, isFalse);
      final plus = listed['mini-plus']!;
      expect(plus.isExpansion, isTrue);
      expect(plus.expands!.id, 'mini');
      expect(plus.icon, 'images/icon.webp');
      expect(plus.broken, isFalse);
    });

    test('an expansion that does not merge is refused with the merge error', () async {
      final store = ModuleStore(root);
      await store.installBytes(zipOf(miniFiles()));
      await expectLater(
        store.installBytes(
          zipOf(plusFiles((m) => ((m['tabs'] as List)[2]['block']['children'] as List)[0]['after'] = 'gone')),
        ),
        throwsA(isA<InstallException>().having((e) => e.message, 'message', 'No element "gone" to place this after')),
      );
      expect(folders(), ['mini']);
    });

    test('a picture field that is not text is refused in words, not with a type error', () async {
      final store = ModuleStore(root, client: imageServer());
      final game = withManifest(miniFiles(), (m) => m['collections']['items']['backImageField'] = 3);
      await expectLater(
        store.installBytes(zipOf(game)),
        throwsA(isA<InstallException>().having((e) => e.message, 'message', 'Should be text')),
      );
    });

    test('an expansion naming a path as its game is refused before anything is read', () async {
      final store = ModuleStore(root);
      await expectLater(
        store.installBytes(zipOf(plusFiles((m) => m['expands'] = {'id': '../outside'}))),
        throwsA(isA<InstallException>().having((e) => e.message, 'message', startsWith('Should be a module id'))),
      );
    });

    test('an expansion cannot take the place of a game with its id, nor a game of an expansion', () async {
      final store = ModuleStore(root);
      await store.installBytes(zipOf(miniFiles()));
      await store.installBytes(zipOf(plusFiles()));
      final game = withManifest(miniFiles(), (m) => m['id'] = 'mini-plus');
      await expectLater(
        store.installBytes(zipOf(game)),
        throwsA(
          isA<InstallException>().having(
            (e) => e.message,
            'message',
            '"mini-plus" is installed as an expansion; a game cannot replace it',
          ),
        ),
      );
    });

    test('pictures of an expansion are downloaded at install, back pictures and the base\'s image field too', () async {
      final store = ModuleStore(root, client: imageServer());
      final base = withManifest(miniFiles(), (m) => m['collections']['items']['imageField'] = 'art');
      final items = jsonDecode(utf8.decode(base['data/items.json']!)) as Map<String, dynamic>;
      for (final it in items['items'] as List) {
        if (it case {'image': final Object image}) it['art'] = image;
      }
      await store.installBytes(zipOf({...base, 'data/items.json': jsonBytes(items)}));

      final plus = jsonDecode(utf8.decode(plusFiles()['module.json']!)) as Map<String, dynamic>;
      plus['collections'] = {
        'items': {
          'items': [
            {'id': 'kraken', 'name': 'Kraken', 'family': 'water', 'art': 'https://img.example/water.webp'},
          ],
        },
        'tiles': {
          'backImageField': 'back',
          'items': [
            {
              'id': 'tile',
              'name': 'Tile',
              'image': 'https://img.example/fire.webp',
              'back': 'https://img.example/imp.webp',
            },
          ],
        },
      };
      final m = await store.installBytes(jsonBytes(plus));
      String read(String file) => File('${m.dir!.path}/$file').readAsStringSync();
      final kraken = (jsonDecode(read('data/items.json'))['items'] as List).single as Map;
      expect(kraken['art'], startsWith('images/remote/'), reason: 'the base collection names the image field');
      final tile = (jsonDecode(read('data/tiles.json'))['items'] as List).single as Map;
      expect(tile['image'], startsWith('images/remote/'));
      expect(tile['back'], startsWith('images/remote/'));
    });
  });

  group('loadInstalledGames', () {
    Future<ModuleStore> installBoth() async {
      final store = ModuleStore(root);
      await store.installBytes(zipOf(miniFiles()));
      await store.installBytes(zipOf(plusFiles()));
      return store;
    }

    test('an expansion that is on merges into its base', () async {
      final store = await installBoth();
      final r = await loadInstalledGames(prefs, await store.list());
      expect(r.modules.single.manifest.id, 'mini');
      expect(r.modules.single.item('items', 'kraken'), isNotNull);
      expect(r.expansions['mini-plus']!.state, ExpansionState.on);
    });

    test('switched off, it is left out; its saved switch is a module key', () async {
      final store = await installBoth();
      await prefs.setBool(expansionEnabledKey('mini-plus'), false);
      expect(expansionEnabledKey('mini-plus'), 'mod.mini-plus.enabled');
      final r = await loadInstalledGames(prefs, await store.list());
      expect(r.modules.single.item('items', 'kraken'), isNull);
      expect(r.expansions['mini-plus']!.state, ExpansionState.off);
    });

    test('without its base it waits; the Library still lists it', () async {
      final store = await installBoth();
      await store.uninstall('mini');
      final r = await loadInstalledGames(prefs, await store.list());
      expect(r.modules, isEmpty);
      expect(r.expansions['mini-plus']!.state, ExpansionState.needsBase);
    });

    test('a base update that drops the anchor step: the base opens alone, the expansion is broken', () async {
      final store = await installBoth();
      final renamed = withManifest(miniFiles(), (m) {
        m['version'] = '1.1.0';
        ((m['tabs'] as List)[2]['block']['children'] as List)[0]['id'] = 'first';
      });
      await store.installBytes(zipOf(renamed));
      final r = await loadInstalledGames(prefs, await store.list());
      expect(r.modules.single.manifest.version, '1.1.0');
      expect(r.modules.single.item('items', 'kraken'), isNull);
      final status = r.expansions['mini-plus']!;
      expect(status.state, ExpansionState.broken);
      expect(status.message, 'No element "one" to place this after');
    });

    test('Review Focus 1: switched off, its tracked cards are out of sight; on again, back where they were', () async {
      final store = await installBoth();
      await prefs.setString('mod.mini.zones', '{"imp":"a","kraken":"b"}');
      Future<int> tracked() async {
        final r = await loadInstalledGames(prefs, await store.list());
        return OpenGame.load(prefs, r.modules.single).zones.total;
      }

      expect(await tracked(), 2);
      await prefs.setBool(expansionEnabledKey('mini-plus'), false);
      expect(await tracked(), 1);
      await prefs.remove(expansionEnabledKey('mini-plus'));
      expect(await tracked(), 2);
    });
  });

  group('LibraryController', () {
    Future<LibraryController> controller() async {
      final store = ModuleStore(root);
      await store.installBytes(zipOf(miniFiles()));
      await store.installBytes(zipOf(plusFiles()));
      final c = LibraryController(prefs: prefs, app: AppState(prefs, const []), store: store);
      await c.refresh();
      return c;
    }

    test('the switch turns an expansion off and on, and the game follows', () async {
      final c = await controller();
      expect(c.app.games.single.module.expansions.single.id, 'mini-plus');
      await c.setExpansionEnabled('mini-plus', false);
      expect(c.expansions['mini-plus']!.state, ExpansionState.off);
      expect(c.app.games.single.module.expansions, isEmpty);
      expect(prefs.getBool('mod.mini-plus.enabled'), isFalse);
      await c.setExpansionEnabled('mini-plus', true);
      expect(c.expansions['mini-plus']!.state, ExpansionState.on);
      expect(prefs.containsKey('mod.mini-plus.enabled'), isFalse, reason: 'on is the default, nothing saved');
    });

    test('uninstalling an expansion forgets the tracked entries only it provided', () async {
      final c = await controller();
      c.app.games.single.zones
        ..put('imp', 'a')
        ..put('kraken', 'c');
      await c.uninstall('mini-plus');
      expect(c.installedById('mini-plus'), isNull);
      expect(prefs.getString('mod.mini.zones'), '{"imp":"a"}');
    });

    test('uninstalling one expansion keeps the saved cards of another that is switched off', () async {
      final c = await controller();
      // A second expansion of the same game: one more card and one more zone, switched off.
      final extra = withManifest(plusFiles(), (m) {
        m['id'] = 'mini-extra';
        m['name'] = 'Mini Extra';
        m['zones'] = [
          {'id': 'd', 'label': 'Lane D', 'accent': 'amber'},
        ];
        m.remove('tabs');
      });
      extra['data/items.json'] = jsonBytes({
        'items': [
          {'id': 'leviathan', 'name': 'Leviathan', 'family': 'water'},
        ],
      });
      await c.store!.installBytes(zipOf(extra));
      await c.setExpansionEnabled('mini-extra', false);
      c.app.games.single.zones
        ..put('imp', 'a')
        ..put('kraken', 'c');
      await prefs.setString('mod.mini.zones', '{"imp":"a","kraken":"c","leviathan":"a","nessie":"d"}');
      await c.refresh();

      await c.uninstall('mini-plus');
      expect(
        jsonDecode(prefs.getString('mod.mini.zones')!),
        {'imp': 'a', 'leviathan': 'a', 'nessie': 'd'},
        reason: 'only the Kraken and Lane C came from mini-plus',
      );
    });

    test('installing an expansion without its game names the game as the repository does', () async {
      final store = ModuleStore(root);
      final c = LibraryController(prefs: prefs, app: AppState(prefs, const []), store: store)
        ..listing = RepoListing(
          name: 'Repo',
          entries: [
            RepoEntry(id: 'mini', name: 'Mini Game', version: '1.0.0', minAppVersion: '3.0.0', zipUrl: Uri(), size: 0),
          ],
        );
      await expectLater(
        c.installBytes(zipOf(plusFiles())),
        throwsA(
          isA<InstallException>().having(
            (e) => e.message,
            'message',
            'Mini Plus is an expansion for Mini Game. Install Mini Game first.',
          ),
        ),
      );
    });

    test('uninstalling the base keeps the expansion, waiting for it', () async {
      final c = await controller();
      await c.uninstall('mini');
      expect(c.app.games, isEmpty);
      expect(c.installedById('mini-plus'), isNotNull);
      expect(c.expansions['mini-plus']!.state, ExpansionState.needsBase);
    });
  });
}
