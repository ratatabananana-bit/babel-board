import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vale_helper/library/install_sources.dart';
import 'package:vale_helper/library/module_store.dart';
import 'package:vale_helper/library/repository.dart';
import 'package:vale_helper/module_format/block_types.dart';
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
    final bytes = await repo.download(entry.zipUrl);
    expect(bytes.length, entry.size);

    Future<void> installAndLoad(Uint8List b, String folder) async {
      final store = ModuleStore(Directory('${tmp.path}/$folder'));
      final installed = await store.installBytes(b);
      final loaded = await loadModule(DirectoryModuleFiles(installed.dir!));
      expect(loaded.manifest.id, 'mini');
      expect(loaded.items('items'), hasLength(4));
    }

    await installAndLoad(bytes, 'store-repo');

    final linkBytes = await InstallSources(client: client).downloadLink(entry.zipUrl, headersFor: repo.headersFor);
    await installAndLoad(linkBytes, 'store-link');

    await installAndLoad(File('${out.path}/mini-1.0.0.zip').readAsBytesSync(), 'store-file');
  });

  test('module.schema.json is draft 2020-12 and names exactly the app\'s block types', () {
    final schema = jsonDecode(File('modules/module.schema.json').readAsStringSync()) as Map<String, dynamic>;
    expect(schema[r'$schema'], 'https://json-schema.org/draft/2020-12/schema');
    expect(
      (schema['required'] as List).toSet(),
      containsAll(['format', 'id', 'name', 'version', 'minAppVersion', 'tabs']),
    );
    final types = ((schema[r'$defs'] as Map)['blockType'] as Map)['enum'] as List;
    expect(types.toSet(), kBlockTypes);
    final accents = ((schema[r'$defs'] as Map)['zone'] as Map)['properties']['accent']['enum'] as List;
    expect(accents.toSet(), {'amber', 'mint', 'violet'});
  });
}
