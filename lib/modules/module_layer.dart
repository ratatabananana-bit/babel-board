import 'dart:convert';

import '../module_format/expansion.dart';
import '../module_format/spec_json.dart';
import '../module_format/validator.dart';
import 'module_files.dart';

export '../module_format/expansion.dart' show ExpansionRef, ModuleData;

class ModuleLoadException implements Exception {
  ModuleLoadException(this.issues);
  final List<ValidationIssue> issues;

  @override
  String toString() => issues.where((i) => i.fatal).map((i) => '${i.path}: ${i.message}').join('\n');
}

/// One module package as read from where it lives, before anything is validated: a game,
/// or an expansion of one. `loaded_module.dart` builds games from layers.
class ModuleLayer {
  ModuleLayer({required this.files, required this.data, this.readIssues = const []});

  final ModuleFiles files;

  /// The manifest and the items of every collection (inline ones included).
  final ModuleData data;

  /// Collection files that could not be read, as validation issues.
  final List<ValidationIssue> readIssues;

  Map<String, dynamic> get manifest => data.manifest;
  String get id => data.id;
  String get name => '${manifest['name'] ?? id}';
  String get version => '${manifest['version'] ?? '?'}';
  String? get icon => manifest['icon'] is String ? manifest['icon'] as String : null;

  /// The ids of the items this package itself declares, in every collection (an item's id
  /// is under the collection's `idField`, else `id`).
  Set<String> get itemIds => {
    for (final e in data.items.entries)
      for (final item in e.value)
        if (item[_idFieldOf(e.key)] case final String id) id,
  };

  /// The ids of the zones this package itself declares.
  Set<String> get zoneIds => {
    if (manifest['zones'] case final List zones)
      for (final z in zones)
        if (z case {'id': final String id}) id,
  };

  String _idFieldOf(String collection) {
    final field = (manifest['collections'] as Map?)?[collection]?['idField'];
    return field is String ? field : 'id';
  }

  /// True when the manifest says `expands`, even in a shape [expands] cannot read.
  bool get isExpansion => manifest['expands'] != null;

  /// The base this layer expands; null for a game, or for an `expands` of the wrong shape
  /// (which `checkExpansion` reports).
  ExpansionRef? get expands {
    try {
      return ExpansionRef.of(manifest);
    } on SpecFormatException {
      return null;
    }
  }
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

/// Reads `module.json` and every collection's items. Throws [ModuleLoadException] only
/// when `module.json` itself cannot be read; a collection file that cannot is a read issue.
Future<ModuleLayer> readModuleLayer(ModuleFiles files) async {
  final String manifestText;
  try {
    manifestText = await files.readText('module.json');
  } catch (e) {
    throw ModuleLoadException([ValidationIssue('module.json', 'Could not read module.json: $e')]);
  }
  final manifest = _decodeObject(manifestText, 'module.json');

  final items = <String, List<Map<String, dynamic>>>{};
  final readIssues = <ValidationIssue>[];
  final rawCollections = manifest['collections'];
  if (rawCollections is Map) {
    for (final e in rawCollections.entries) {
      final name = e.key as String;
      final spec = e.value;
      if (spec is! Map) continue;
      final src = spec['items'];
      if (src is String) {
        try {
          final j = _decodeObject(await files.readText(src), src);
          final list = j['items'];
          if (list is! List) {
            readIssues.add(ValidationIssue('collections.$name', '"$src" should contain {"items": [...]}'));
            continue;
          }
          if (list.any((i) => i is! Map)) {
            readIssues.add(ValidationIssue('collections.$name', 'Every item in "$src" should be an object'));
            continue;
          }
          items[name] = [for (final i in list) (i as Map).cast<String, dynamic>()];
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
        items[name] = [for (final i in src) (i as Map).cast<String, dynamic>()];
      }
    }
  }
  return ModuleLayer(files: files, data: ModuleData(manifest, items), readIssues: readIssues);
}
