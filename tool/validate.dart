// Checks a game module the same way the app does on install, with readable errors.
//   dart run tool/validate.dart <module folder | module.json> [--base <folder>]
// Prints `OK <id> <version>` when the module is valid, after any WARN lines; otherwise one
// `ERROR <path>: <message>` line per problem, and exits with code 1. An expansion is checked
// merged into its base: the folder given with --base, else the folder next to it named by
// its `expands.id`; with neither, it is checked on its own and a WARN says so.
import 'dart:convert';
import 'dart:io';

import 'package:vale_helper/module_format/expansion.dart';
import 'package:vale_helper/module_format/validator.dart';

class ToolResult {
  ToolResult(this.exitCode, this.lines);
  final int exitCode;
  final List<String> lines;
}

/// A module folder read from disk: its manifest JSON, its path-form collections, and any
/// problems reading or checking them.
class ModuleFolder {
  ModuleFolder(this.dir, this.manifest, this.collections, this.issues);
  final Directory dir;
  final Map<String, dynamic>? manifest;
  final Map<String, List<Map<String, dynamic>>> collections;
  final List<ValidationIssue> issues;

  bool get ok => manifest != null && issues.every((i) => !i.fatal);
  bool get isExpansion => manifest?['expands'] != null;
  ModuleData get data => ModuleData(manifest!, collections);
}

String _p(Directory dir, String rel) =>
    '${dir.path}${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}';

/// Reads `module.json` and the path-form collections of [dir], without checking them.
ModuleFolder _read(Directory dir) {
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
  return ModuleFolder(dir, manifest, collections, issues);
}

/// Reads and validates a module folder, including a check that local images exist. An
/// expansion is merged into [base] (else the sibling folder its `expands.id` names).
ModuleFolder readModuleFolder(Directory dir, {Directory? base}) {
  final folder = _read(dir);
  final manifest = folder.manifest;
  if (manifest == null) return folder;
  final issues = folder.issues;
  Object? baseCollections;
  if (folder.isExpansion) {
    issues.addAll(checkExpansion(folder.data));
    if (issues.every((i) => !i.fatal)) baseCollections = _checkMerged(folder, base, issues);
  } else {
    issues.addAll(checkModule(manifest, collections: folder.collections).issues);
  }
  // Local images that don't exist are not fatal (the app draws the text-only card), but an
  // author wants to know.
  if (issues.every((i) => !i.fatal)) {
    for (final (path, ref) in _imageRefs(folder.data, baseCollections)) {
      if (ref is! String || ref.isEmpty || ref.startsWith('https://') || !isSafeImageRef(ref)) continue;
      if (!File(_p(dir, ref)).existsSync()) {
        issues.add(ValidationIssue(path, 'Image file not found: "$ref"', fatal: false));
      }
    }
  }
  return folder;
}

/// Merges the expansion [folder] into its base and adds what that says to [issues]; returns
/// the base's collections (their picture fields apply to the expansion's items).
Object? _checkMerged(ModuleFolder folder, Directory? baseDir, List<ValidationIssue> issues) {
  final baseId = ExpansionRef.of(folder.manifest!)!.id;
  final dir = baseDir ?? Directory('${folder.dir.parent.path}${Platform.pathSeparator}$baseId');
  final base = File(_p(dir, 'module.json')).existsSync() ? readModuleFolder(dir) : null;
  if (base == null) {
    issues.add(
      ValidationIssue('expands', 'Base "$baseId" not found next to this folder; checked on its own', fatal: false),
    );
    return null;
  }
  if (!base.ok || base.isExpansion) {
    issues.add(
      ValidationIssue('expands', 'Base "$baseId" in ${dir.path} does not load; checked on its own', fatal: false),
    );
    return null;
  }
  final into = 'merging into ${base.manifest!['id']} ${base.manifest!['version']}';
  final stack = stackExpansions(base.data, [folder.data]);
  for (final i in [...stack.warnings, ...?stack.rejected[folder.data.id]]) {
    issues.add(ValidationIssue(i.path, i.fatal ? '${i.message} ($into)' : i.message, fatal: i.fatal));
  }
  return base.manifest!['collections'];
}

/// Every picture ref a module's JSON names, with its path: icon, symbols, hub entries and
/// each item's picture fields (an expansion's collections fall back to [baseCollections]).
Iterable<(String, Object?)> _imageRefs(ModuleData data, Object? baseCollections) sync* {
  final m = data.manifest;
  yield ('icon', m['icon']);
  if (m['symbols'] case final Map symbols) {
    for (final e in symbols.entries) {
      yield ('symbols.${e.key}', e.value);
    }
  }
  if (m['collections'] case final Map collections) {
    for (final e in collections.entries) {
      final spec = e.value is Map ? e.value as Map : const {};
      final baseSpec = baseCollections is Map ? baseCollections[e.key] : null;
      String? setting(String key) => switch (spec[key] ?? (baseSpec is Map ? baseSpec[key] : null)) {
        final String text => text,
        _ => null,
      };
      final fields = [setting('imageField') ?? 'image', ?setting('backImageField')];
      final items = data.itemsOf('${e.key}');
      for (var i = 0; i < items.length; i++) {
        for (final f in fields) {
          yield ('collections.${e.key}[$i].$f', items[i][f]);
        }
      }
    }
  }
  yield* _entryImages(m['tabs'], 'tabs');
}

Iterable<(String, Object?)> _entryImages(Object? node, String path) sync* {
  switch (node) {
    case Map m:
      if (m['type'] == 'entry') yield ('$path.image', m['image']);
      for (final e in m.entries) {
        yield* _entryImages(e.value, '$path.${e.key}');
      }
    case List l:
      for (var i = 0; i < l.length; i++) {
        yield* _entryImages(l[i], '$path[$i]');
      }
  }
}

ToolResult validatePath(String path, {String? base}) {
  final dir = path.toLowerCase().endsWith('.json') ? File(path).parent : Directory(path);
  final folder = readModuleFolder(dir, base: base == null ? null : Directory(base));
  final lines = [
    for (final i in folder.issues.where((i) => !i.fatal)) '$i',
    for (final i in folder.issues.where((i) => i.fatal)) '$i',
  ];
  if (!folder.ok) return ToolResult(1, lines);
  lines.add('OK ${folder.manifest!['id']} ${folder.manifest!['version']}');
  return ToolResult(0, lines);
}

void main(List<String> args) {
  final positional = <String>[];
  String? base;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--base' && i + 1 < args.length) {
      base = args[++i];
    } else {
      positional.add(args[i]);
    }
  }
  if (positional.length != 1) {
    stderr.writeln('Usage: dart run tool/validate.dart <module folder | module.json> [--base <folder>]');
    exit(2);
  }
  final r = validatePath(positional.single, base: base);
  r.lines.forEach(stdout.writeln);
  exit(r.exitCode);
}
