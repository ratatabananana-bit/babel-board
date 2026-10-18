import 'dart:convert';

import '../module_format/manifest.dart';
import '../module_format/validator.dart';
import 'module_files.dart';

export '../module_format/manifest.dart';
export '../module_format/validator.dart' show ValidationIssue;

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
  String? imageRef(CollectionSpec c) {
    final v = data[c.imageField];
    return v is String && v.isNotEmpty ? v : null;
  }
}

class LoadedModule {
  LoadedModule({required this.manifest, required this.collections, required this.files});

  final ModuleManifest manifest;
  final Map<String, List<Item>> collections;
  final ModuleFiles files;

  final Map<String, Map<String, Item>> _index = {};

  Item? item(String collection, String id) {
    final list = collections[collection];
    if (list == null) return null;
    return (_index[collection] ??= {for (final i in list) i.id: i})[id];
  }

  List<Item> items(String collection) => collections[collection] ?? const [];
}

class ModuleLoadException implements Exception {
  ModuleLoadException(this.issues);
  final List<ValidationIssue> issues;

  @override
  String toString() => issues.where((i) => i.fatal).map((i) => '${i.path}: ${i.message}').join('\n');
}

Map<String, dynamic> _decodeObject(String text, String path) {
  final Object? v;
  try {
    v = jsonDecode(text);
  } on FormatException catch (e) {
    throw ModuleLoadException([ValidationIssue(path, 'Not valid JSON: ${e.message}')]);
  }
  if (v is! Map) throw ModuleLoadException([ValidationIssue(path, 'Should be a JSON object')]);
  return v.cast<String, dynamic>();
}

/// Reads `module.json` and the collection files, validates everything, and returns the
/// module. Throws [ModuleLoadException] on any fatal issue.
Future<LoadedModule> loadModule(ModuleFiles files) async {
  final String manifestText;
  try {
    manifestText = await files.readText('module.json');
  } catch (e) {
    throw ModuleLoadException([ValidationIssue('module.json', 'Could not read module.json: $e')]);
  }
  final manifestJson = _decodeObject(manifestText, 'module.json');

  // Collection files, read before validation so the validator sees every item.
  final lists = <String, List<Map<String, dynamic>>>{};
  final readIssues = <ValidationIssue>[];
  final rawCollections = manifestJson['collections'];
  if (rawCollections is Map) {
    for (final e in rawCollections.entries) {
      final name = e.key as String;
      final spec = e.value;
      if (spec is! Map) continue;
      final src = spec['items'];
      if (src is String) {
        try {
          final j = _decodeObject(await files.readText(src), src);
          final items = j['items'];
          if (items is! List) {
            readIssues.add(ValidationIssue('collections.$name', '"$src" should contain {"items": [...]}'));
            continue;
          }
          if (items.any((i) => i is! Map)) {
            readIssues.add(ValidationIssue('collections.$name', 'Every item in "$src" should be an object'));
            continue;
          }
          lists[name] = [for (final i in items) (i as Map).cast<String, dynamic>()];
        } on ModuleLoadException catch (e) {
          readIssues.addAll(e.issues);
        } catch (e) {
          readIssues.add(ValidationIssue('collections.$name', 'Could not read "$src": $e'));
        }
      } else if (src is List) {
        if (src.any((i) => i is! Map)) {
          readIssues.add(ValidationIssue('collections.$name', 'Every item should be an object'));
          continue;
        }
        lists[name] = [for (final i in src) (i as Map).cast<String, dynamic>()];
      }
    }
  }

  final checked = checkModule(manifestJson, collections: lists);
  final issues = [...readIssues, ...checked.issues];
  final manifest = checked.manifest;
  if (manifest == null || issues.any((i) => i.fatal)) throw ModuleLoadException(issues);

  return LoadedModule(
    manifest: manifest,
    files: files,
    collections: {
      for (final e in manifest.collections.entries)
        e.key: [for (final d in lists[e.key] ?? const []) Item('${d[e.value.idField]}', d)],
    },
  );
}
