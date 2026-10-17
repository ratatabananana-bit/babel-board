import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/library/module_store.dart';
import 'package:vale_helper/modules/loaded_module.dart';
import 'package:vale_helper/modules/module_files.dart';
import 'package:vale_helper/modules/module_state.dart';

import '../helpers.dart';

Uint8List zipOf(Map<String, List<int>> files) {
  final a = Archive();
  for (final e in files.entries) {
    a.addFile(ArchiveFile(e.key, e.value.length, e.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}

Uint8List jsonBytes(Object j) => Uint8List.fromList(utf8.encode(jsonEncode(j)));

Map<String, dynamic> miniManifest() => jsonDecode(utf8.decode(miniFiles()['module.json']!)) as Map<String, dynamic>;

/// The mini module as one JSON file: collections inline, images as links.
Map<String, dynamic> singleJsonMini({String host = 'https://img.example'}) {
  final m = miniManifest();
  final items = (jsonDecode(utf8.decode(miniFiles()['data/items.json']!)) as Map)['items'] as List;
  for (final it in items) {
    if (it['image'] != null) it['image'] = '$host/${(it['image'] as String).split('/').last}';
  }
  m['collections']['items']['items'] = items;
  m['icon'] = '$host/fire.webp';
  m['symbols'] = {for (final e in (m['symbols'] as Map).entries) e.key: '$host/${(e.value as String).split('/').last}'};
  return m;
}

void main() {
  late Directory parent;
  late Directory root;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    parent = await Directory.systemTemp.createTemp('store_test_');
    root = Directory('${parent.path}${Platform.pathSeparator}modules')..createSync();
  });
  tearDown(() => parent.deleteSync(recursive: true));

  http.Client imageServer({Set<String> notFound = const {}, Set<String> hang = const {}}) => MockClient((req) async {
    final name = req.url.pathSegments.last;
    if (notFound.contains(name)) return http.Response('nope', 404);
    if (hang.contains(name)) return Completer<http.Response>().future;
    final bytes = miniFiles()['images/$name'];
    if (bytes == null) return http.Response('nope', 404);
    return http.Response.bytes(bytes, 200, headers: {'content-type': 'image/webp'});
  });

  test('installs the mini module from zip bytes and lists it', () async {
    final store = ModuleStore(root);
    final m = await store.installBytes(zipOf(miniFiles()));
    expect(m.id, 'mini');
    expect(m.name, 'Mini Game');
    expect(m.version, '1.0.0');
    expect(m.broken, isFalse);
    expect(File('${m.dir!.path}/module.json').existsSync(), isTrue);
    final listed = await store.list();
    expect(listed.map((i) => i.id), ['mini']);
    final loaded = await loadModule(DirectoryModuleFiles(m.dir!));
    expect(loaded.items('items'), hasLength(4));
    expect(root.listSync().where((e) => e.path.contains('.staging')), isEmpty, reason: 'staging cleaned up');
  });

  test('review: a zip whose module.json has inline items downloads their image links too', () async {
    final files = miniFiles();
    final m = singleJsonMini();
    files['module.json'] = jsonBytes(m);
    files.remove('data/items.json');
    final store = ModuleStore(root, client: imageServer(), imageTimeout: const Duration(milliseconds: 300));
    final installed = await store.installBytes(zipOf(files));
    final loaded = await loadModule(DirectoryModuleFiles(installed.dir!));
    final ref = loaded.item('items', 'imp')!.imageRef(loaded.manifest.collections['items']!)!;
    expect(ref, startsWith('images/remote/'), reason: 'works offline after install');
  });

  test('installs a single-JSON module: inline collections written, image links downloaded', () async {
    final store = ModuleStore(root, client: imageServer(), imageTimeout: const Duration(milliseconds: 300));
    final m = await store.installBytes(jsonBytes(singleJsonMini()));
    expect(File('${m.dir!.path}/data/items.json').existsSync(), isTrue);
    final loaded = await loadModule(DirectoryModuleFiles(m.dir!));
    final spec = loaded.manifest.collections['items']!;
    final ref = loaded.item('items', 'imp')!.imageRef(spec)!;
    expect(ref, startsWith('images/remote/'));
    expect(ref, endsWith('.webp'));
    expect(File('${m.dir!.path}/$ref').existsSync(), isTrue);
    expect(loaded.manifest.icon, startsWith('images/remote/'));
    expect(loaded.manifest.symbols['fire'], startsWith('images/remote/'));
    expect(loaded.files.image(ref), isNotNull);
  });

  test('Review Focus 1: a 404 and a timed-out image link leave those refs empty; install still succeeds', () async {
    final store = ModuleStore(
      root,
      client: imageServer(notFound: {'nessie.webp'}, hang: {'undine.webp'}),
      imageTimeout: const Duration(milliseconds: 300),
    );
    final m = await store.installBytes(jsonBytes(singleJsonMini()));
    final loaded = await loadModule(DirectoryModuleFiles(m.dir!));
    final spec = loaded.manifest.collections['items']!;
    expect(loaded.item('items', 'imp')!.imageRef(spec), isNotNull);
    expect(loaded.item('items', 'nessie')!.imageRef(spec), isNull);
    expect(loaded.item('items', 'undine')!.imageRef(spec), isNull);
  });

  test('updating to a higher version keeps saved zones (Review Focus 3, state half)', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ModuleStore(root);
    await store.installBytes(zipOf(miniFiles()));
    ZoneState(prefs, 'mini').put('imp', 'a');

    final files = miniFiles();
    final m2 = miniManifest()..['version'] = '2.0.0';
    files['module.json'] = jsonBytes(m2);
    final updated = await store.installBytes(zipOf(files));
    expect(updated.version, '2.0.0');
    expect((await store.list()).single.version, '2.0.0');
    expect(ZoneState(prefs, 'mini').zoneOf('imp'), 'a');

    // Reinstalling the same version is also fine and keeps state.
    await store.installBytes(zipOf(files));
    expect(ZoneState(prefs, 'mini').zoneOf('imp'), 'a');
    expect(root.listSync().whereType<Directory>().map((d) => d.path.split(Platform.pathSeparator).last), ['mini']);
  });

  test('uninstall removes the folder', () async {
    final store = ModuleStore(root);
    final m = await store.installBytes(zipOf(miniFiles()));
    await store.uninstall('mini');
    expect(m.dir!.existsSync(), isFalse);
    expect(await store.list(), isEmpty);
  });

  test('review: a single-JSON collection name cannot write outside the module folder', () async {
    final victim = File('${root.path}/victim/data/cards.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('ORIGINAL');
    final m = singleJsonMini();
    final items = m['collections']['items'];
    m['collections'] = {'../../../victim/data/cards': items};
    for (final t in (m['tabs'] as List)) {
      final b = t['block'] as Map;
      if (b['collection'] == 'items') b['collection'] = '../../../victim/data/cards';
    }
    final store = ModuleStore(root, client: imageServer(), imageTimeout: const Duration(milliseconds: 300));
    await expectLater(store.installBytes(jsonBytes(m)), throwsA(isA<InstallException>()));
    expect(victim.readAsStringSync(), 'ORIGINAL');
  });

  test('zip entries that escape the module folder are rejected and nothing is written outside root', () async {
    final store = ModuleStore(root);
    for (final bad in ['../x.json', r'..\x.json', '/abs.json', 'C:/x.json', 'a/../../x.json']) {
      final files = miniFiles()..[bad] = Uint8List.fromList(utf8.encode('{}'));
      await expectLater(store.installBytes(zipOf(files)), throwsA(isA<InstallException>()), reason: bad);
    }
    expect(parent.listSync().map((e) => e.path.split(Platform.pathSeparator).last), ['modules']);
    expect(root.listSync().where((e) => !e.path.contains('.staging')), isEmpty);
    expect(
      Directory('${root.path}/.staging').existsSync() ? Directory('${root.path}/.staging').listSync() : [],
      isEmpty,
    );
  });

  test('disallowed file types and oversize files are rejected', () async {
    final store = ModuleStore(root);
    await expectLater(
      store.installBytes(zipOf(miniFiles()..['run.exe'] = Uint8List.fromList([1, 2, 3]))),
      throwsA(isA<InstallException>().having((e) => e.message, 'message', contains('.exe'))),
    );
    await expectLater(
      store.installBytes(zipOf(miniFiles()..['images/huge.png'] = Uint8List(16 * 1024 * 1024))),
      throwsA(isA<InstallException>().having((e) => e.message, 'message', contains('too big'))),
    );
  });

  test('review: wrongly shaped module JSON is rejected with a readable InstallException', () async {
    final store = ModuleStore(root, client: imageServer(), imageTimeout: const Duration(milliseconds: 300));
    final shapes = <String, void Function(Map<String, dynamic>)>{
      'symbol value is a number': (m) => m['symbols'] = {'fire': 3},
      'zones are strings': (m) => m['zones'] = ['table'],
      'icon is a number': (m) => m['icon'] = 5,
      'collection is a string': (m) => m['collections'] = {'items': 'data/items.json'},
      'children are strings': (m) => (m['tabs'] as List)[1]['block']['children'] = ['a', 'b'],
      'tabs is an object': (m) => m['tabs'] = {'a': 1},
      'item is a string': (m) => (m['collections']['items']['items'] as List).add('oops'),
    };
    for (final e in shapes.entries) {
      final m = singleJsonMini();
      e.value(m);
      await expectLater(
        store.installBytes(jsonBytes(m)),
        throwsA(isA<InstallException>().having((x) => x.message, 'message', isNotEmpty)),
        reason: e.key,
      );
    }
    expect(await store.list(), isEmpty);
  });

  test('an invalid module is rejected with its validation issues', () async {
    final store = ModuleStore(root);
    final files = miniFiles();
    final m = miniManifest();
    (m['tabs'] as List)[3]['block'] = {'type': 'dice'};
    files['module.json'] = jsonBytes(m);
    await expectLater(
      store.installBytes(zipOf(files)),
      throwsA(
        isA<InstallException>().having(
          (e) => e.issues.map((i) => i.message).join(),
          'issues',
          contains('Unknown block'),
        ),
      ),
    );
    expect(await store.list(), isEmpty);
  });

  test('neither zip nor JSON is rejected clearly', () async {
    final store = ModuleStore(root);
    await expectLater(
      store.installBytes(Uint8List.fromList(utf8.encode('hello'))),
      throwsA(isA<InstallException>().having((e) => e.message, 'message', contains('zip'))),
    );
  });

  test('list() marks a folder that fails to load as broken', () async {
    final store = ModuleStore(root);
    await store.installBytes(zipOf(miniFiles()));
    File('${root.path}/broken/module.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('not json');
    final listed = await store.list();
    final broken = listed.firstWhere((i) => i.id == 'broken');
    expect(broken.broken, isTrue);
    expect(broken.error, isNotNull);
    expect(listed.firstWhere((i) => i.id == 'mini').broken, isFalse);
  });

  test('images are fetched with the headers the caller gives for their host', () async {
    final seen = <String, Map<String, String>>{};
    final client = MockClient((req) async {
      seen[req.url.host] = req.headers;
      return http.Response.bytes(miniFiles()['images/imp.webp']!, 200);
    });
    final store = ModuleStore(root, client: client);
    final m = singleJsonMini(host: 'https://repo.example/m');
    await store.installBytes(
      jsonBytes(m),
      headersFor: (u) => u.host == 'repo.example' ? {'Authorization': 'Bearer t'} : {},
    );
    expect(seen['repo.example']!['Authorization'], 'Bearer t');
  });
}
