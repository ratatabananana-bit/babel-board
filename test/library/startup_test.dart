import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/library/startup.dart';
import 'package:vale_helper/modules/module_state.dart';

import '../helpers.dart';

Uint8List zipOf(Map<String, List<int>> files) {
  final a = Archive();
  for (final e in files.entries) {
    a.addFile(ArchiveFile(e.key, e.value.length, e.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}

void main() {
  test('installing magical-athlete through the app store adopts the legacy lineup', () async {
    SharedPreferences.setMockInitialValues({
      'ma.lineup': ['banana'],
    });
    final prefs = await SharedPreferences.getInstance();
    final tmp = await Directory.systemTemp.createTemp('startup_test_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final store = createModuleStore(Directory('${tmp.path}/modules'), prefs);

    final files = miniFiles();
    final m = jsonDecode(utf8.decode(files['module.json']!)) as Map<String, dynamic>;
    m['id'] = 'magical-athlete';
    m['zones'] = [
      {'id': 'race', 'label': 'This race', 'icon': 'race', 'accent': 'mint'},
      ...(m['zones'] as List),
    ];
    files['module.json'] = Uint8List.fromList(utf8.encode(jsonEncode(m)));
    await store.installBytes(zipOf(files));

    expect(ZoneState(prefs, 'magical-athlete').idsIn('race'), ['banana']);
    expect(prefs.containsKey('ma.lineup'), isFalse);
  });

  test('web preview loads every module listed in modules/index.json over HTTP', () async {
    final base = Uri.parse('https://preview.example/app/');
    final mini = miniFiles();
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path == '/app/modules/index.json') {
        return http.Response(
          jsonEncode({
            'name': 'Preview',
            'modules': [
              {
                'id': 'mini',
                'name': 'Mini Game',
                'version': '1.0.0',
                'minAppVersion': '3.0.0',
                'zip': 'mini-1.0.0.zip',
              },
              {'id': 'missing', 'name': 'Gone', 'version': '1.0.0', 'minAppVersion': '3.0.0', 'zip': 'gone.zip'},
            ],
          }),
          200,
        );
      }
      const prefix = '/app/modules/mini/';
      if (path.startsWith(prefix)) {
        final b = mini[path.substring(prefix.length)];
        if (b != null) return http.Response.bytes(b, 200);
      }
      return http.Response('', 404);
    });
    final modules = await loadWebModules(base, client: client);
    expect(modules.map((m) => m.manifest.id), ['mini'], reason: 'a module that fails to load is skipped');
    expect(modules.single.items('items'), hasLength(4));
  });

  test('web preview with no index starts empty', () async {
    final modules = await loadWebModules(
      Uri.parse('https://preview.example/'),
      client: MockClient((_) async => http.Response('', 404)),
    );
    expect(modules, isEmpty);
  });
}
