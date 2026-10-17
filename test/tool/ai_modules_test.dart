import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vale_helper/library/module_store.dart';
import 'package:vale_helper/modules/loaded_module.dart';
import 'package:vale_helper/modules/module_files.dart';

/// Installs a single-JSON module offline (every image link answers 404) and loads it.
Future<LoadedModule> installOffline(String json) async {
  final tmp = await Directory.systemTemp.createTemp('ai_module_');
  addTearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Disposable.
    }
  });
  final store = ModuleStore(
    Directory('${tmp.path}/modules'),
    client: MockClient((_) async => http.Response('', 404)),
    imageTimeout: const Duration(seconds: 2),
  );
  final m = await store.installBytes(Uint8List.fromList(utf8.encode(json)));
  return loadModule(DirectoryModuleFiles(m.dir!));
}

/// The JSON of the "complete small example" in AI_INSTRUCTIONS.md.
String exampleJson(String text) {
  final start = text.indexOf('## A complete small example');
  return RegExp(r'```json\r?\n([\s\S]*?)\r?\n```').firstMatch(text.substring(start))!.group(1)!;
}

void main() {
  test('review: the example is found whatever the line endings (git may check out CRLF)', () {
    final lf = File('modules/AI_INSTRUCTIONS.md').readAsStringSync().replaceAll('\r\n', '\n');
    final crlf = lf.replaceAll('\n', '\r\n');
    expect(exampleJson(crlf).replaceAll('\r\n', '\n'), exampleJson(lf));
  });

  test('the complete example in AI_INSTRUCTIONS.md installs', () async {
    final m = await installOffline(exampleJson(File('modules/AI_INSTRUCTIONS.md').readAsStringSync()));
    expect(m.manifest.id, 'example-duel');
    expect(m.manifest.tabs, hasLength(4));
  });

  test('a module written by a fresh AI from AI_INSTRUCTIONS.md alone installs', () async {
    // test/fixtures/ai_generated.json: a subagent's first try at "a small game of your choice
    // using only public rules text", given only modules/AI_INSTRUCTIONS.md.
    final m = await installOffline(File('test/fixtures/ai_generated.json').readAsStringSync());
    expect(m.manifest.id, 'crazy-eights');
    expect(m.items('cards'), hasLength(13));
    expect(m.items('suits'), hasLength(4));
  });
}
