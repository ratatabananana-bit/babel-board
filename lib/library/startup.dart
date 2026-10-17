import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../modules/loaded_module.dart';
import '../modules/module_files.dart';
import 'migration.dart';
import 'module_store.dart';

/// The phone's module store. Every install hands the old built-in games' saved state to
/// the matching module, so tracked cards and round progress reappear after the update.
ModuleStore createModuleStore(Directory root, SharedPreferences prefs) =>
    ModuleStore(root, onInstalled: (id) => adoptLegacyState(prefs, id));

/// Web preview: reads `modules/index.json` next to the app and loads each listed module
/// from its unpacked folder `modules/<id>/`. A module that fails to load is skipped.
Future<List<LoadedModule>> loadWebModules(Uri base, {http.Client? client}) async {
  final c = client ?? http.Client();
  final indexUrl = base.resolve('modules/index.json');
  final Object? index;
  try {
    final res = await c.get(indexUrl);
    if (res.statusCode != 200) return const [];
    index = jsonDecode(utf8.decode(res.bodyBytes));
  } catch (_) {
    return const [];
  }
  if (index is! Map || index['modules'] is! List) return const [];
  final out = <LoadedModule>[];
  for (final e in index['modules'] as List) {
    final id = e is Map ? e['id'] : null;
    if (id is! String || id.contains('/') || id.contains('..')) continue;
    try {
      out.add(await loadModule(HttpModuleFiles(base.resolve('modules/$id/'), client: c)));
    } catch (_) {
      // Skipped; the preview simply doesn't show it.
    }
  }
  return out;
}
