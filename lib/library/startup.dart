import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../modules/loaded_module.dart';
import '../modules/module_files.dart';
import '../modules/module_layer.dart';
import 'migration.dart';
import 'module_store.dart';

/// The phone's module store. Every install hands the old built-in games' saved state to
/// the matching module, so tracked cards and round progress reappear after the update.
ModuleStore createModuleStore(Directory root, SharedPreferences prefs) =>
    ModuleStore(root, onInstalled: (id) => adoptLegacyState(prefs, id));

/// The Library's switch for an expansion: `false` when off; absent (the default) is on.
/// A `mod.<id>.` key, so uninstalling the expansion removes it with the rest.
String expansionEnabledKey(String id) => 'mod.$id.enabled';

bool isExpansionEnabled(SharedPreferences prefs, String id) => prefs.getBool(expansionEnabledKey(id)) ?? true;

enum ExpansionState {
  /// Merged into its game.
  on,

  /// Switched off in the Library.
  off,

  /// Its game is not installed, or cannot load.
  needsBase,

  /// It does not load, or does not merge; [ExpansionStatus.message] says why.
  broken,
}

class ExpansionStatus {
  const ExpansionStatus(this.state, [this.message]);
  final ExpansionState state;
  final String? message;
}

/// What the installed modules add up to: the games to open, and where each expansion stands.
class InstalledGames {
  const InstalledGames(this.modules, this.expansions);
  final List<LoadedModule> modules;
  final Map<String, ExpansionStatus> expansions;
}

/// Builds every installed game with its switched-on expansions. The one place the store's
/// modules become games (startup and every Library refresh). A game that fails to load is
/// left out (the store lists it as broken); an expansion that fails only leaves itself out.
Future<InstalledGames> loadInstalledGames(SharedPreferences prefs, List<InstalledModule> installed) async {
  final layers = <String, ModuleLayer>{};
  for (final i in installed) {
    if (i.broken || i.dir == null) continue;
    try {
      layers[i.id] = await readModuleLayer(DirectoryModuleFiles(i.dir!));
    } on ModuleLoadException {
      // Removed or changed since it was listed: as good as broken.
    }
  }

  final expansions = <String, ExpansionStatus>{};
  final waiting = <String, List<ModuleLayer>>{};
  for (final i in installed.where((i) => i.isExpansion)) {
    final layer = layers[i.id];
    final baseId = i.expands?.id;
    if (i.broken || layer == null || baseId == null) {
      expansions[i.id] = ExpansionStatus(ExpansionState.broken, i.error?.split('\n').first);
    } else if (!layers.containsKey(baseId) || layers[baseId]!.isExpansion) {
      expansions[i.id] = const ExpansionStatus(ExpansionState.needsBase);
    } else if (!isExpansionEnabled(prefs, i.id)) {
      expansions[i.id] = const ExpansionStatus(ExpansionState.off);
    } else {
      (waiting[baseId] ??= []).add(layer);
    }
  }

  final modules = <LoadedModule>[];
  for (final i in installed.where((i) => !i.isExpansion)) {
    final base = layers[i.id];
    if (base == null) continue;
    final GameBuild game;
    try {
      game = buildGame(base, waiting[i.id] ?? const []);
    } on ModuleLoadException {
      for (final e in waiting[i.id] ?? const <ModuleLayer>[]) {
        expansions[e.id] = const ExpansionStatus(ExpansionState.needsBase);
      }
      continue;
    }
    modules.add(game.module);
    for (final e in game.module.expansions) {
      expansions[e.id] = const ExpansionStatus(ExpansionState.on);
    }
    for (final r in game.rejected.entries) {
      expansions[r.key] = ExpansionStatus(ExpansionState.broken, r.value.first.message);
    }
  }
  return InstalledGames(modules, expansions);
}

/// Web preview: reads `modules/index.json` next to the app and loads each listed module
/// from its unpacked folder `modules/<id>/`; expansions merge into their games, always on.
/// A module that fails to load is skipped.
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
  final layers = <ModuleLayer>[];
  for (final e in index['modules'] as List) {
    final id = e is Map ? e['id'] : null;
    if (id is! String || id.contains('/') || id.contains('..')) continue;
    try {
      layers.add(await readModuleLayer(HttpModuleFiles(base.resolve('modules/$id/'), client: c)));
    } catch (_) {
      // Skipped; the preview simply doesn't show it.
    }
  }
  final out = <LoadedModule>[];
  for (final game in layers.where((l) => !l.isExpansion)) {
    try {
      out.add(buildGame(game, layers.where((l) => l.expands?.id == game.id)).module);
    } catch (_) {
      // Skipped, as above.
    }
  }
  return out;
}
