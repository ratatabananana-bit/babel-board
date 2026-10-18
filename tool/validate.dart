// Checks a game module the same way the app does on install, with readable errors.
//   dart run tool/validate.dart <module folder | module.json>
// Prints `OK <id> <version>` when the module is valid, after any WARN lines; otherwise one
// `ERROR <path>: <message>` line per problem, and exits with code 1.
import 'dart:convert';
import 'dart:io';

import 'package:vale_helper/module_format/validator.dart';

class ToolResult {
  ToolResult(this.exitCode, this.lines);
  final int exitCode;
  final List<String> lines;
}

/// A module folder read from disk: its manifest JSON, its path-form collections, and any
/// problems reading them.
class ModuleFolder {
  ModuleFolder(this.dir, this.manifest, this.collections, this.issues);
  final Directory dir;
  final Map<String, dynamic>? manifest;
  final Map<String, List<Map<String, dynamic>>> collections;
  final List<ValidationIssue> issues;

  bool get ok => manifest != null && issues.every((i) => !i.fatal);
}

String _p(Directory dir, String rel) =>
    '${dir.path}${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}';

/// Reads and validates a module folder, including a check that local images exist.
ModuleFolder readModuleFolder(Directory dir) {
  final manifestFile = File(_p(dir, 'module.json'));
  if (!manifestFile.existsSync()) {
    return ModuleFolder(dir, null, const {}, [ValidationIssue('module.json', 'Not found in ${dir.path}')]);
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(manifestFile.readAsStringSync());
  } on FormatException catch (e) {
    return ModuleFolder(dir, null, const {}, [ValidationIssue('module.json', 'Not valid JSON: ${e.message}')]);
  }
  if (decoded is! Map) {
    return ModuleFolder(dir, null, const {}, [ValidationIssue('module.json', 'Should be a JSON object')]);
  }
  final manifest = decoded.cast<String, dynamic>();
  final issues = <ValidationIssue>[];
  final collections = <String, List<Map<String, dynamic>>>{};

  final rawCollections = manifest['collections'];
  if (rawCollections is Map) {
    for (final e in rawCollections.entries) {
      final spec = e.value;
      final src = spec is Map ? spec['items'] : null;
      if (src is! String) continue;
      if (!isSafeImageRef(src) || src.startsWith('https://')) {
        issues.add(ValidationIssue('collections.${e.key}.items', 'Must be a relative path inside the module: "$src"'));
        continue;
      }
      final f = File(_p(dir, src));
      if (!f.existsSync()) {
        issues.add(ValidationIssue('collections.${e.key}', 'File not found: "$src"'));
        continue;
      }
      try {
        final j = jsonDecode(f.readAsStringSync());
        if (j is! Map || j['items'] is! List) {
          issues.add(ValidationIssue('collections.${e.key}', '"$src" should contain {"items": [...]}'));
          continue;
        }
        collections[e.key as String] = [for (final i in j['items'] as List) (i as Map).cast<String, dynamic>()];
      } on FormatException catch (err) {
        issues.add(ValidationIssue('collections.${e.key}', '"$src" is not valid JSON: ${err.message}'));
      }
    }
  }

  final checked = checkModule(manifest, collections: collections);
  issues.addAll(checked.issues);

  // Local images that don't exist are not fatal (the app draws the text-only card), but an
  // author wants to know.
  if (checked.manifest case final m? when issues.every((i) => !i.fatal)) {
    void checkFile(String path, Object? ref) {
      if (ref is! String || ref.isEmpty || ref.startsWith('https://') || !isSafeImageRef(ref)) return;
      if (!File(_p(dir, ref)).existsSync()) {
        issues.add(ValidationIssue(path, 'Image file not found: "$ref"', fatal: false));
      }
    }

    checkFile('icon', m.icon);
    m.symbols.forEach((k, v) => checkFile('symbols.$k', v));
    for (final e in m.collections.entries) {
      final items = e.value.isInline ? e.value.inlineItems : collections[e.key] ?? const [];
      for (var i = 0; i < items.length; i++) {
        checkFile('collections.${e.key}[$i].${e.value.imageField}', items[i][e.value.imageField]);
      }
    }
  }
  return ModuleFolder(dir, manifest, collections, issues);
}

ToolResult validatePath(String path) {
  final dir = path.toLowerCase().endsWith('.json') ? File(path).parent : Directory(path);
  final folder = readModuleFolder(dir);
  final lines = [
    for (final i in folder.issues.where((i) => !i.fatal)) '$i',
    for (final i in folder.issues.where((i) => i.fatal)) '$i',
  ];
  if (!folder.ok) return ToolResult(1, lines);
  lines.add('OK ${folder.manifest!['id']} ${folder.manifest!['version']}');
  return ToolResult(0, lines);
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/validate.dart <module folder | module.json>');
    exit(2);
  }
  final r = validatePath(args.single);
  r.lines.forEach(stdout.writeln);
  exit(r.exitCode);
}
