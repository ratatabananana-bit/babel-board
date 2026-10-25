import '../module_format/expansion.dart';
import '../module_format/manifest.dart';
import '../module_format/validator.dart';
import 'module_files.dart';
import 'module_layer.dart';

export '../module_format/manifest.dart';
export '../module_format/validator.dart' show ValidationIssue;
export 'module_layer.dart' show ModuleLoadException;

/// One item of a collection (a card, a racer…).
class Item {
  Item(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;

  String title(CollectionSpec c) => '${data[c.titleField] ?? id}';

  String? subtitle(CollectionSpec c) {
    final f = c.subtitleField;
    if (f == null) return null;
    final v = data[f];
    return v == null || '$v'.isEmpty ? null : '$v';
  }

  /// The image ref (relative path or https link), or null when the item has none.
  String? imageRef(CollectionSpec c) => _ref(c.imageField);

  /// The second picture's ref (the back), or null when the item or collection has none.
  String? backImageRef(CollectionSpec c) => c.backImageField == null ? null : _ref(c.backImageField!);

  String? _ref(String field) {
    final v = data[field];
    return v is String && v.isNotEmpty ? v : null;
  }
}

/// An expansion merged into a game, as the Library names it.
class ExpansionInfo {
  const ExpansionInfo({required this.id, required this.name, required this.version});
  final String id;
  final String name;
  final String version;
}

class LoadedModule {
  LoadedModule({required this.manifest, required this.collections, required this.files, this.expansions = const []});

  final ModuleManifest manifest;
  final Map<String, List<Item>> collections;
  final ModuleFiles files;

  /// The expansions merged into this game, in the order they were applied.
  final List<ExpansionInfo> expansions;

  final Map<String, Map<String, Item>> _index = {};

  Item? item(String collection, String id) {
    final list = collections[collection];
    if (list == null) return null;
    return (_index[collection] ??= {for (final i in list) i.id: i})[id];
  }

  List<Item> items(String collection) => collections[collection] ?? const [];
}

LoadedModule _assemble(
  ModuleManifest m,
  ItemLists items,
  ModuleFiles files, [
  List<ExpansionInfo> expansions = const [],
]) => LoadedModule(
  manifest: m,
  files: files,
  expansions: expansions,
  collections: {
    for (final e in m.collections.entries)
      e.key: [for (final d in items[e.key] ?? const <Map<String, dynamic>>[]) Item('${d[e.value.idField]}', d)],
  },
);

/// Validates a game's [layer] and builds it. Throws [ModuleLoadException] on any fatal
/// issue, an expansion on its own included (it is not a game).
LoadedModule buildModule(ModuleLayer layer) {
  final checked = checkModule(layer.manifest, collections: layer.data.items);
  final issues = [...layer.readIssues, ...checked.issues];
  final manifest = checked.manifest;
  if (manifest == null || issues.any((i) => i.fatal)) throw ModuleLoadException(issues);
  return _assemble(manifest, layer.data.items, layer.files);
}

/// A game built from its base and expansions, and the expansions left out with why.
class GameBuild {
  const GameBuild(this.module, this.rejected);
  final LoadedModule module;
  final Map<String, List<ValidationIssue>> rejected;
}

/// Builds the game of [base] with every one of [expansions] that merges. The base must
/// stand on its own (else [ModuleLoadException]); an expansion that does not merge is only
/// left out, so it can never take its base down with it.
GameBuild buildGame(ModuleLayer base, Iterable<ModuleLayer> expansions) {
  final alone = buildModule(base);
  final rejected = <String, List<ValidationIssue>>{};
  final readable = <String, ModuleLayer>{};
  for (final e in expansions) {
    final unread = [...e.readIssues.where((i) => i.fatal)];
    if (unread.isEmpty) {
      readable[e.id] = e;
    } else {
      rejected[e.id] = unread;
    }
  }
  if (readable.isEmpty) return GameBuild(alone, rejected);

  final stack = stackExpansions(base.data, [for (final e in readable.values) e.data]);
  rejected.addAll(stack.rejected);
  if (stack.merged.isEmpty) return GameBuild(alone, rejected);
  final merged = [for (final id in stack.merged) readable[id]!];
  return GameBuild(
    _assemble(
      stack.manifest,
      stack.data.items,
      LayeredModuleFiles(base.files, {for (final e in merged) e.id: e.files}),
      [for (final e in merged) ExpansionInfo(id: e.id, name: e.name, version: e.version)],
    ),
    rejected,
  );
}

/// Reads and validates a game from [files]. Throws [ModuleLoadException] on any fatal issue.
Future<LoadedModule> loadModule(ModuleFiles files) async => buildModule(await readModuleLayer(files));
