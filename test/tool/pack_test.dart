import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vale_helper/library/install_sources.dart';
import 'package:vale_helper/library/module_store.dart';
import 'package:vale_helper/library/repository.dart';
import 'package:vale_helper/module_format/block_specs.dart';
import 'package:vale_helper/modules/loaded_module.dart';
import 'package:vale_helper/modules/module_files.dart';

import '../../tool/pack.dart';
import '../../tool/validate.dart';

/// Copies a module folder so a test can break it.
Directory copyDir(Directory from, Directory to) {
  for (final f in from.listSync(recursive: true).whereType<File>()) {
    final rel = f.path.substring(from.path.length + 1);
    File('${to.path}/$rel')
      ..createSync(recursive: true)
      ..writeAsBytesSync(f.readAsBytesSync());
  }
  return to;
}

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('pack_test_'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold a handle briefly; the temp dir is disposable.
    }
  });

  Directory modulesWith(Map<String, Directory> folders) {
    final dir = Directory('${tmp.path}/modules')..createSync();
    for (final e in folders.entries) {
      copyDir(e.value, Directory('${dir.path}/${e.key}'));
    }
    return dir;
  }

  test('validate: OK line for a good module, ERROR lines and exit 1 for a bad one', () {
    final good = validatePath('test/fixtures/mini_module');
    expect(good.exitCode, 0);
    expect(good.lines.last, 'OK mini 1.0.0');
    expect(good.lines.where((l) => l.startsWith('WARN')), hasLength(1), reason: 'the unverified Ghost card');

    final viaFile = validatePath('test/fixtures/mini_module/module.json');
    expect(viaFile.lines.last, 'OK mini 1.0.0');

    final broken = copyDir(Directory('test/fixtures/mini_module'), Directory('${tmp.path}/broken'));
    final m = jsonDecode(File('${broken.path}/module.json').readAsStringSync()) as Map<String, dynamic>;
    (m['tabs'] as List)[0]['block'] = {'type': 'dice'};
    File('${broken.path}/module.json').writeAsStringSync(jsonEncode(m));
    final bad = validatePath(broken.path);
    expect(bad.exitCode, 1);
    expect(bad.lines.any((l) => l.startsWith('ERROR tabs[0].block: Unknown block')), isTrue);
    expect(bad.lines.any((l) => l.startsWith('OK')), isFalse);

    expect(validatePath('${tmp.path}/nowhere').exitCode, 1);
  });

  test('validate warns about local image files that are missing', () {
    final dir = copyDir(Directory('test/fixtures/mini_module'), Directory('${tmp.path}/m'));
    File('${dir.path}/images/imp.webp').deleteSync();
    final r = validatePath(dir.path);
    expect(r.exitCode, 0);
    expect(r.lines.any((l) => l.startsWith('WARN') && l.contains('images/imp.webp')), isTrue);
  });

  test('pack writes a zip, an icon and an index with relative links and exact size', () {
    final modules = modulesWith({'mini': Directory('test/fixtures/mini_module')});
    final out = Directory('${tmp.path}/out');
    final r = packModules(modules, out, name: 'Test repo');
    expect(r.exitCode, 0, reason: r.lines.join('\n'));

    final index = jsonDecode(File('${out.path}/index.json').readAsStringSync()) as Map<String, dynamic>;
    expect(index['name'], 'Test repo');
    final entry = (index['modules'] as List).single as Map<String, dynamic>;
    expect(entry['id'], 'mini');
    expect(entry['version'], '1.0.0');
    expect(entry['minAppVersion'], '3.0.0');
    expect(entry['zip'], 'mini-1.0.0.zip');
    expect(Uri.parse(entry['zip'] as String).hasScheme, isFalse);
    expect(entry['size'], File('${out.path}/mini-1.0.0.zip').lengthSync());
    expect(entry['icon'], 'icons/mini.webp');
    expect(File('${out.path}/icons/mini.webp').existsSync(), isTrue);
    expect(Directory('${out.path}/mini').existsSync(), isFalse, reason: 'no unpacked copy unless asked');
  });

  group('expansions', () {
    final plus = Directory('test/fixtures/mini_expansion');

    /// Rewrites module.json of a copied folder.
    void editManifest(Directory dir, void Function(Map<String, dynamic> m) edit) {
      final f = File('${dir.path}/module.json');
      final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      edit(m);
      f.writeAsStringSync(jsonEncode(m));
    }

    test('validate checks an expansion merged into the base folder next to it', () {
      final modules = modulesWith({'mini': Directory('test/fixtures/mini_module'), 'mini-plus': plus});
      final r = validatePath('${modules.path}/mini-plus');
      expect(r.exitCode, 0, reason: r.lines.join('\n'));
      expect(r.lines.last, 'OK mini-plus 1.0.0');
    });

    test('validate --base names the base; a merge error names the expansion\'s own path', () {
      expect(validatePath(plus.path, base: 'test/fixtures/mini_module').lines.last, 'OK mini-plus 1.0.0');
      final broken = copyDir(plus, Directory('${tmp.path}/broken'));
      editManifest(broken, (m) => ((m['tabs'] as List)[2]['block']['children'] as List)[0]['after'] = 'gone');
      final r = validatePath(broken.path, base: 'test/fixtures/mini_module');
      expect(r.exitCode, 1);
      expect(
        r.lines,
        contains('ERROR tabs[2].block.children[0].after: No element "gone" to place this after (merging into mini 1.0.0)'),
      );
    });

    test('validate without a base in sight warns and checks the expansion on its own', () {
      final r = validatePath(plus.path);
      expect(r.exitCode, 0);
      expect(r.lines, contains('WARN expands: Base "mini" not found next to this folder; checked on its own'));
      expect(r.lines.last, 'OK mini-plus 1.0.0');
    });

    test('Review Focus 5: an item replacing a base item is a warning, not an error', () {
      final modules = modulesWith({'mini': Directory('test/fixtures/mini_module'), 'mini-plus': plus});
      final data = File('${modules.path}/mini-plus/data/items.json');
      final items = jsonDecode(data.readAsStringSync()) as Map<String, dynamic>;
      ((items['items'] as List).single as Map)['id'] = 'imp';
      data.writeAsStringSync(jsonEncode(items));
      final r = validatePath('${modules.path}/mini-plus');
      expect(r.exitCode, 0, reason: r.lines.join('\n'));
      expect(r.lines, contains('WARN collections.items: item "imp" replaces the base game\'s item'));
    });

    test('validate reports a picture field that is not text, without crashing', () {
      final dir = copyDir(plus, Directory('${tmp.path}/bad'));
      editManifest(dir, (m) => m['collections']['items']['backImageField'] = 3);
      final r = validatePath(dir.path, base: 'test/fixtures/mini_module');
      expect(r.exitCode, 1);
      expect(r.lines, contains(startsWith('ERROR collections.items.backImageField')));
    });

    test('validate reports an expansion\'s own missing picture files', () {
      final dir = copyDir(plus, Directory('${tmp.path}/p'));
      File('${dir.path}/images/kraken.webp').deleteSync();
      final r = validatePath(dir.path, base: 'test/fixtures/mini_module');
      expect(r.lines.any((l) => l.startsWith('WARN') && l.contains('images/kraken.webp')), isTrue);
    });

    test('pack writes "expands" into the index and fails on an expansion that does not merge', () {
      final modules = modulesWith({'mini': Directory('test/fixtures/mini_module'), 'mini-plus': plus});
      final out = Directory('${tmp.path}/out');
      final r = packModules(modules, out);
      expect(r.exitCode, 0, reason: r.lines.join('\n'));
      final index = jsonDecode(File('${out.path}/index.json').readAsStringSync()) as Map<String, dynamic>;
      final entries = {for (final e in index['modules'] as List) e['id']: e as Map};
      expect(entries['mini-plus']!['expands'], 'mini');
      expect(entries['mini']!.containsKey('expands'), isFalse);

      editManifest(Directory('${modules.path}/mini-plus'), (m) => m['zones'] = [{'id': 'a', 'label': 'A', 'accent': 'red'}]);
      expect(packModules(modules, Directory('${tmp.path}/out2')).exitCode, 1);
    });
  });

  test('pack --unpacked also writes each module folder for the web preview', () {
    final modules = modulesWith({'mini': Directory('test/fixtures/mini_module')});
    final out = Directory('${tmp.path}/out');
    expect(packModules(modules, out, unpacked: true).exitCode, 0);
    expect(File('${out.path}/mini/module.json').existsSync(), isTrue);
    expect(File('${out.path}/mini/images/imp.webp').existsSync(), isTrue);
  });

  test('a broken module makes pack fail with exit code 1 and write no index', () {
    final modules = modulesWith({'mini': Directory('test/fixtures/mini_module')});
    final broken = copyDir(Directory('test/fixtures/mini_module'), Directory('${modules.path}/broken'));
    final m = jsonDecode(File('${broken.path}/module.json').readAsStringSync()) as Map<String, dynamic>;
    m['id'] = 'broken';
    m.remove('name');
    File('${broken.path}/module.json').writeAsStringSync(jsonEncode(m));
    final out = Directory('${tmp.path}/out');
    final r = packModules(modules, out);
    expect(r.exitCode, 1);
    expect(r.lines.any((l) => l.contains('broken') && l.contains('ERROR')), isTrue);
    expect(File('${out.path}/index.json').existsSync(), isFalse);
  });

  test('end to end: packed repository → fetchIndex → download → install → load; also as link and file', () async {
    final modules = modulesWith({'mini': Directory('test/fixtures/mini_module')});
    final out = Directory('${tmp.path}/out');
    expect(packModules(modules, out, name: 'E2E').exitCode, 0);

    final base = Uri.parse('https://raw.example/owner/repo/main/');
    final client = MockClient((req) async {
      expect(req.headers['Authorization'], 'Bearer tok');
      final rel = req.url.path.substring(base.path.length);
      final f = File('${out.path}/$rel');
      return f.existsSync() ? http.Response.bytes(f.readAsBytesSync(), 200) : http.Response('', 404);
    });

    final repo = RepoClient(
      RepoConfig(indexUrl: base.resolve('index.json'), token: 'tok'),
      client: client,
    );
    final listing = await repo.fetchIndex();
    expect(listing.name, 'E2E');
    final entry = listing.entries.single;
    final download = await repo.download(entry.zipUrl);
    final bytes = (download as FileSource).file.readAsBytesSync();
    expect(bytes.length, entry.size);

    Future<void> installAndLoad(Uint8List b, String folder) async {
      final store = ModuleStore(Directory('${tmp.path}/$folder'));
      final installed = await store.installBytes(b);
      final loaded = await loadModule(DirectoryModuleFiles(installed.dir!));
      expect(loaded.manifest.id, 'mini');
      expect(loaded.items('items'), hasLength(4));
    }

    await installAndLoad(bytes, 'store-repo');
    // The repository download is a temp file the store deletes after installing it.
    final installedFromFile = await ModuleStore(Directory('${tmp.path}/store-stream')).install(download);
    expect(installedFromFile.id, 'mini');
    expect(download.file.existsSync(), isFalse);

    final link = await InstallSources(client: client).downloadLink(entry.zipUrl, headersFor: repo.headersFor);
    final linkFile = (link as FileSource).file;
    expect(linkFile.lengthSync(), entry.size, reason: 'the link download is spooled to a file');
    await installAndLoad(linkFile.readAsBytesSync(), 'store-link');
    linkFile.deleteSync();

    await installAndLoad(File('${out.path}/mini-1.0.0.zip').readAsBytesSync(), 'store-file');
  });

  test('module.schema.json is draft 2020-12 and names exactly the app\'s block types', () {
    final schema = jsonDecode(File('modules/module.schema.json').readAsStringSync()) as Map<String, dynamic>;
    expect(schema[r'$schema'], 'https://json-schema.org/draft/2020-12/schema');
    expect(
      (schema['required'] as List).toSet(),
      containsAll(['format', 'id', 'name', 'version', 'minAppVersion']),
    );
    expect(schema['if'], {
      'required': ['expands'],
    }, reason: 'an expansion is an overlay; only a game must have tabs');
    expect((schema['else'] as Map)['required'], ['tabs']);
    final types = ((schema[r'$defs'] as Map)['blockType'] as Map)['enum'] as List;
    expect(types.toSet(), kBlockTypes);
    final accents = ((schema[r'$defs'] as Map)['zone'] as Map)['properties']['accent']['enum'] as List;
    expect(accents.toSet(), {'amber', 'mint', 'violet'});
  });
}
