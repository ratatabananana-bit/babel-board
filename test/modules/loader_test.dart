import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/modules/loaded_module.dart';
import 'package:vale_helper/modules/module_files.dart';

Uint8List bytes(Object json) => Uint8List.fromList(utf8.encode(jsonEncode(json)));

void main() {
  final fixture = Directory('test/fixtures/mini_module');

  test('loads the mini module from a directory', () async {
    final m = await loadModule(DirectoryModuleFiles(fixture));
    expect(m.manifest.id, 'mini');
    expect(m.manifest.tabs, hasLength(4));
    expect(m.collections['items'], hasLength(4));
    final imp = m.item('items', 'imp')!;
    final spec = m.manifest.collections['items']!;
    expect(imp.title(spec), 'Imp');
    expect(imp.subtitle(spec), 'Fire');
    expect(imp.imageRef(spec), 'images/imp.webp');
    expect(imp.data['cost'], 2);
    expect(m.item('items', 'ghost')!.imageRef(spec), isNull);
    expect(m.item('items', 'nope'), isNull);
    expect(m.item('nope', 'imp'), isNull);
  });

  test('directory files give a path-keyed image for real refs and null otherwise', () {
    final f = DirectoryModuleFiles(fixture);
    expect(f.image('images/imp.webp'), isA<ModuleFileImage>());
    expect(f.image('images/imp.webp'), equals(f.image('images/imp.webp')), reason: 'same cache key');
    expect(f.image(null), isNull);
    expect(f.image(''), isNull);
    expect(f.image('images/missing.webp'), isNull);
    expect(f.image('../secret.png'), isNull);
    expect(f.image('/etc/passwd'), isNull);
    expect(f.image('https://example.com/x.png'), isA<NetworkImage>());
  });

  test('http files resolve against the base', () {
    final f = HttpModuleFiles(Uri.parse('https://host.example/modules/mini/'));
    final img = f.image('images/imp.webp') as NetworkImage;
    expect(img.url, 'https://host.example/modules/mini/images/imp.webp');
    expect(f.image(null), isNull);
  });

  test('memory files: inline collection, unknown block throws ModuleLoadException', () async {
    final manifest = {
      'format': 1,
      'id': 'mem',
      'name': 'Mem',
      'version': '1.0.0',
      'minAppVersion': '3.0.0',
      'collections': {
        'items': {
          'items': [
            {'id': 'x', 'name': 'X'},
          ],
        },
      },
      'tabs': [
        {
          'label': 'T',
          'icon': 'book',
          'block': {'type': 'dice'},
        },
      ],
    };
    final files = MemoryModuleFiles({'module.json': bytes(manifest)});
    await expectLater(
      loadModule(files),
      throwsA(
        isA<ModuleLoadException>().having(
          (e) => e.issues.map((i) => i.message).join(),
          'issues',
          contains('Unknown block'),
        ),
      ),
    );

    (manifest['tabs'] as List)[0]['block'] = {
      'type': 'text',
      'paragraphs': ['hi'],
    };
    final ok = await loadModule(MemoryModuleFiles({'module.json': bytes(manifest)}));
    expect(ok.collections['items']!.single.id, 'x');
    expect(ok.files.image('images/none.webp'), isNull);
  });

  test('a missing collection file is a load error', () async {
    final manifest = {
      'format': 1,
      'id': 'mem',
      'name': 'Mem',
      'version': '1.0.0',
      'minAppVersion': '3.0.0',
      'collections': {
        'items': {'items': 'data/items.json'},
      },
      'tabs': [
        {
          'label': 'T',
          'icon': 'book',
          'block': {
            'type': 'text',
            'paragraphs': ['hi'],
          },
        },
      ],
    };
    await expectLater(
      loadModule(MemoryModuleFiles({'module.json': bytes(manifest)})),
      throwsA(
        isA<ModuleLoadException>().having(
          (e) => e.issues.map((i) => i.path).join(),
          'issues',
          contains('collections.items'),
        ),
      ),
    );
  });
}
