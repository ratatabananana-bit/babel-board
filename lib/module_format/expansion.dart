/// Expansions: a module that adds to another module, its base game, instead of standing
/// alone. Its manifest names the base under `expands`; everything after its header is an
/// **overlay** in the shape of a module, holding only what the expansion adds or changes.
///
/// [mergeExpansion] applies one overlay to a base by fixed rules (objects merge, keyed lists
/// merge by key and place new elements with `after`/`before`, other lists append, numbers
/// lists replace); [stackExpansions] applies several and keeps those whose result passes
/// [checkModule]. The merged result is an ordinary manifest, so nothing downstream knows
/// expansions exist. Pure Dart: the app and the tools share this one engine.
library;

import '../app_version.dart';
import 'manifest.dart';
import 'spec_json.dart';
import 'validator.dart';

/// Collection name → its items, inline or read from the collection's file.
typedef ItemLists = Map<String, List<Map<String, dynamic>>>;

/// Header fields describe the package itself and never overlay the base.
const kExpansionHeader = {'format', 'id', 'name', 'version', 'minAppVersion', 'icon', 'players', 'source', 'expands'};

/// `expands`: the base module an expansion adds to.
class ExpansionRef {
  const ExpansionRef({required this.id, this.minVersion});

  final String id;

  /// The oldest base version this expansion merges into; null for any.
  final String? minVersion;

  /// The manifest's `expands`, or null when it has none.
  static ExpansionRef? of(Map<String, dynamic> manifest) {
    final raw = manifest['expands'];
    if (raw == null) return null;
    if (raw is! Map || raw['id'] is! String || (raw['id'] as String).isEmpty) {
      throw SpecFormatException('expands', 'Should be {"id": "<base module id>", "minVersion"?: "x.y.z"}');
    }
    final f = Fields(raw.cast<String, dynamic>(), 'expands');
    return ExpansionRef(id: f.text('id'), minVersion: f.optText('minVersion'));
  }
}

/// A module package as JSON: its manifest and the items of every collection.
class ModuleData {
  const ModuleData(this.manifest, this.items);

  final Map<String, dynamic> manifest;
  final ItemLists items;

  String get id => '${manifest['id']}';

  /// The items of [collection]: the list held in [items], else the manifest's inline list.
  List<Map<String, dynamic>> itemsOf(String collection) {
    if (items[collection] case final list?) return list;
    final inline = (manifest['collections'] as Map?)?[collection]?['items'];
    return inline is List ? [for (final i in inline.whereType<Map>()) i.cast<String, dynamic>()] : const [];
  }
}

// ------------------------------------------------------------------------- layer refs

/// An expansion's relative image ref, as the merged game names it: `@<layerId>/<ref>`.
/// Links and empty refs are left alone.
String layerRef(String layerId, String ref) => ref.isEmpty || ref.startsWith('https://') ? ref : '@$layerId/$ref';

/// The layer and path of a ref made by [layerRef]; null for any other ref.
({String layer, String path})? splitLayerRef(String ref) {
  if (!ref.startsWith('@')) return null;
  final slash = ref.indexOf('/');
  if (slash <= 1 || slash == ref.length - 1) return null;
  return (layer: ref.substring(1, slash), path: ref.substring(slash + 1));
}

// ---------------------------------------------------------------------------- merging

/// Merges [expansion] into [base]. Never changes its inputs. Issues carry paths in the
/// expansion's own `module.json`; all are fatal except the warning that an item replaces a
/// base item of the same id (errata). With a fatal issue, `data` is not to be used.
({ModuleData data, List<ValidationIssue> issues}) mergeExpansion(ModuleData base, ModuleData expansion) {
  final issues = <ValidationIssue>[];
  ({ModuleData data, List<ValidationIssue> issues}) refused() => (data: base, issues: issues);

  final ExpansionRef? ref;
  try {
    ref = ExpansionRef.of(expansion.manifest);
  } on SpecFormatException catch (e) {
    return refused()..issues.add(ValidationIssue(e.path, e.message));
  }
  if (ref == null) {
    return refused()
      ..issues.add(ValidationIssue('expands', 'Missing "expands": an expansion names the module it adds to'));
  }
  if (ref.id != base.id) {
    return refused()
      ..issues.add(ValidationIssue('expands.id', 'This is an expansion for "${ref.id}", not for "${base.id}"'));
  }
  final baseVersion = '${base.manifest['version']}';
  if (ref.minVersion case final min? when compareVersions(min, baseVersion) > 0) {
    return refused()
      ..issues.add(
        ValidationIssue(
          'expands.minVersion',
          'Needs ${base.manifest['name']} $min or newer, $baseVersion is installed',
        ),
      );
  }

  final overlay = <String, dynamic>{
    for (final e in expansion.manifest.entries)
      if (!kExpansionHeader.contains(e.key)) e.key: _copy(e.value),
  };
  final overlayCollections = overlay.remove('collections');
  final baseCollections = (base.manifest['collections'] as Map?) ?? const {};

  final manifest = _copy(base.manifest) as Map<String, dynamic>;
  final items = <String, List<Map<String, dynamic>>>{
    for (final name in baseCollections.keys) '$name': [for (final i in base.itemsOf('$name')) _copyItem(i)],
  };

  if (overlayCollections is Map) {
    final collections = (manifest['collections'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    manifest['collections'] = collections;
    for (final e in overlayCollections.entries) {
      final name = '${e.key}';
      final at = 'collections.$name';
      final spec = e.value;
      if (spec is! Map) {
        issues.add(ValidationIssue(at, 'Should be an object'));
        continue;
      }
      final baseSpec = baseCollections[name];
      final added = [
        for (final i in expansion.itemsOf(name))
          _withLayerRefs(i, expansion.id, [
            _text(spec['imageField']) ?? (baseSpec is Map ? _text(baseSpec['imageField']) : null) ?? 'image',
            ?(_text(spec['backImageField']) ?? (baseSpec is Map ? _text(baseSpec['backImageField']) : null)),
          ]),
      ];
      if (baseSpec is Map) {
        final settings = Map.of(spec)..remove('items');
        collections[name] = _overlay(baseSpec, settings, at, issues);
        final idField = '${spec['idField'] ?? baseSpec['idField'] ?? 'id'}';
        items[name] = _joinItems(items[name]!, added, idField, at, issues);
      } else {
        collections[name] = _copy(spec);
        items[name] = added;
      }
    }
  }

  if (overlay['symbols'] case final Map symbols) {
    overlay['symbols'] = {
      for (final e in symbols.entries) e.key: e.value is String ? layerRef(expansion.id, e.value as String) : e.value,
    };
  }
  if (overlay['tabs'] case final List tabs) _rewriteEntryImages(tabs, expansion.id);

  for (final e in overlay.entries) {
    manifest[e.key] = manifest.containsKey(e.key)
        ? _overlay(manifest[e.key], e.value, e.key, issues)
        : _fresh(e.value, e.key, issues);
  }
  return (data: ModuleData(manifest, items), issues: issues);
}

/// Base items with [added] joined by [idField]: a new id appends, a known id replaces the
/// base item in place (errata) and says so.
List<Map<String, dynamic>> _joinItems(
  List<Map<String, dynamic>> baseItems,
  List<Map<String, dynamic>> added,
  String idField,
  String at,
  List<ValidationIssue> issues,
) {
  final out = [...baseItems];
  for (final item in added) {
    final id = item[idField];
    final i = id is String ? out.indexWhere((b) => b[idField] == id) : -1;
    if (i < 0) {
      out.add(item);
    } else {
      out[i] = item;
      issues.add(ValidationIssue(at, 'item "$id" replaces the base game\'s item', fatal: false));
    }
  }
  return out;
}

/// The overlay rules. [path] is where [over] sits in the expansion's `module.json`.
Object? _overlay(Object? base, Object? over, String path, List<ValidationIssue> issues) {
  if (over == null) {
    issues.add(ValidationIssue(path, 'An expansion cannot remove base content; leave the key out'));
    return _copy(base);
  }
  if (base is Map && over is Map) {
    // A block of another type is another block: it replaces, nothing of the old one stays.
    if (base['type'] != null && over['type'] != null && base['type'] != over['type']) {
      return _fresh(over, path, issues);
    }
    final out = <String, dynamic>{for (final e in base.entries) '${e.key}': _copy(e.value)};
    for (final e in over.entries) {
      final k = '${e.key}';
      final at = specPath(path, k);
      out[k] = out.containsKey(k) ? _overlay(out[k], e.value, at, issues) : _fresh(e.value, at, issues);
    }
    return out;
  }
  if (base is List && over is List) return _overlayList(base, over, path, issues);
  return _fresh(over, path, issues);
}

/// [value] as new content: copied, with any `after`/`before` inside it checked against the
/// (empty) lists it creates.
Object? _fresh(Object? value, String path, List<ValidationIssue> issues) => switch (value) {
  Map() => _overlay(const <String, dynamic>{}, value, path, issues),
  List() => _overlay(const <Object?>[], value, path, issues),
  _ => value,
};

/// The key a list merges by: `id` when every element has a text id, `zone` for a board's
/// lanes; null for a list that appends.
String? _listKey(List base, List over) {
  bool all(bool Function(Object? e) test) => base.every(test) && over.every(test);
  if (base.isEmpty && over.isEmpty) return null;
  if (all((e) => e is Map && e['id'] is String)) return 'id';
  if (all((e) => e is Map && e['type'] == 'zone' && e['zone'] is String)) return 'zone';
  return null;
}

List<Object?> _overlayList(List base, List over, String path, List<ValidationIssue> issues) {
  final key = _listKey(base, over);
  final out = [for (final e in base) _copy(e)];
  if (key == null) {
    // A list of numbers is a value (a range), not a collection of things.
    if (over.isNotEmpty && over.every((e) => e is num)) return [...over];
    for (var i = 0; i < over.length; i++) {
      final at = '$path[$i]';
      final e = over[i];
      if (e is Map && (e.containsKey('after') || e.containsKey('before'))) {
        final word = e.containsKey('after') ? 'after' : 'before';
        issues.add(ValidationIssue('$at.$word', '"$word" needs a list whose elements have ids'));
        continue;
      }
      final v = _fresh(e, at, issues);
      if (!out.any((x) => _same(x, v))) out.add(v);
    }
    return out;
  }

  int indexOf(Object? k) => out.indexWhere((e) => (e as Map)[key] == k);
  for (var i = 0; i < over.length; i++) {
    final at = '$path[$i]';
    final e = over[i] as Map;
    final after = e['after'], before = e['before'];
    final existing = indexOf(e[key]);
    if (existing >= 0) {
      if (after != null || before != null) {
        final word = after != null ? 'after' : 'before';
        issues.add(ValidationIssue('$at.$word', '"$word" only places new elements; "${e[key]}" is already there'));
      } else {
        out[existing] = _overlay(out[existing], e, at, issues);
      }
      continue;
    }
    if (after != null && before != null) {
      issues.add(ValidationIssue(at, 'Use "after" or "before", not both'));
      continue;
    }
    final element = _fresh(
      Map.of(e)
        ..remove('after')
        ..remove('before'),
      at,
      issues,
    );
    if (after == null && before == null) {
      out.add(element);
      continue;
    }
    final word = after != null ? 'after' : 'before';
    final anchor = indexOf(after ?? before);
    if (anchor < 0) {
      issues.add(ValidationIssue('$at.$word', 'No element "${after ?? before}" to place this $word'));
      continue;
    }
    out.insert(after != null ? anchor + 1 : anchor, element);
  }
  return out;
}

/// The ref fields of [item] named by [fields], rewritten to [layerId]'s folder.
Map<String, dynamic> _withLayerRefs(Map<String, dynamic> item, String layerId, List<String> fields) {
  final out = _copyItem(item);
  for (final f in fields) {
    if (out[f] case final String ref) out[f] = layerRef(layerId, ref);
  }
  return out;
}

/// Hub entries may sit at any depth of a tab's blocks; their pictures come from the layer.
void _rewriteEntryImages(Object? node, String layerId) {
  switch (node) {
    case Map m:
      if (m['type'] == 'entry' && m['image'] is String) m['image'] = layerRef(layerId, m['image'] as String);
      for (final v in m.values) {
        _rewriteEntryImages(v, layerId);
      }
    case List l:
      for (final v in l) {
        _rewriteEntryImages(v, layerId);
      }
  }
}

Object? _copy(Object? v) => switch (v) {
  Map() => <String, dynamic>{for (final e in v.entries) '${e.key}': _copy(e.value)},
  List() => <Object?>[for (final e in v) _copy(e)],
  _ => v,
};

Map<String, dynamic> _copyItem(Map<String, dynamic> item) => _copy(item) as Map<String, dynamic>;

bool _same(Object? a, Object? b) => switch ((a, b)) {
  (Map a, Map b) => a.length == b.length && a.keys.every((k) => b.containsKey(k) && _same(a[k], b[k])),
  (List a, List b) => a.length == b.length && [for (var i = 0; i < a.length; i++) _same(a[i], b[i])].every((x) => x),
  _ => a == b,
};

// ------------------------------------------------------------------------- stacking

/// A base game with its expansions applied: the merged data and manifest, which
/// expansions made it in (in the order applied) and why the others did not.
class StackResult {
  const StackResult({
    required this.data,
    required this.manifest,
    required this.merged,
    required this.rejected,
    required this.warnings,
  });

  final ModuleData data;
  final ModuleManifest manifest;
  final List<String> merged;
  final Map<String, List<ValidationIssue>> rejected;

  /// What merging the accepted expansions warned about (an item replacing a base item).
  final List<ValidationIssue> warnings;
}

/// Applies [expansions] to [base] in id order, each on top of the ones before it. One that
/// fails to merge, or whose result fails [checkModule], is rejected and the rest go on, so
/// an expansion can never break its base. [base] must already pass [checkModule].
StackResult stackExpansions(ModuleData base, Iterable<ModuleData> expansions) {
  var data = base;
  var checked = checkModule(base.manifest, collections: base.items);
  if (checked.manifest == null || checked.issues.any((i) => i.fatal)) {
    throw ArgumentError.value(base.id, 'base', 'does not pass checkModule');
  }
  final merged = <String>[];
  final rejected = <String, List<ValidationIssue>>{};
  final mergeWarnings = <ValidationIssue>[];
  for (final e in [...expansions]..sort((a, b) => a.id.compareTo(b.id))) {
    final r = mergeExpansion(data, e);
    var fatal = [...r.issues.where((i) => i.fatal)];
    if (fatal.isEmpty) {
      final c = checkModule(r.data.manifest, collections: r.data.items);
      fatal = [...c.issues.where((i) => i.fatal)];
      if (fatal.isEmpty && c.manifest != null) {
        data = r.data;
        checked = c;
        merged.add(e.id);
        mergeWarnings.addAll(r.issues);
        continue;
      }
    }
    rejected[e.id] = fatal;
  }
  return StackResult(
    data: data,
    manifest: checked.manifest!,
    merged: merged,
    rejected: rejected,
    warnings: mergeWarnings,
  );
}

// ------------------------------------------------------------------------- checking

/// Checks an expansion on its own, before any base is in sight: its header, `expands`, and
/// the items and pictures it brings. What it adds to the base is checked after merging.
List<ValidationIssue> checkExpansion(ModuleData expansion, {String appVersion = kAppVersion}) {
  final m = expansion.manifest;
  final issues = <ValidationIssue>[
    for (final k in ['format', 'id', 'name', 'version', 'minAppVersion'])
      if (m[k] == null) ValidationIssue(k, 'Missing required field "$k"'),
  ];
  try {
    final ref = ExpansionRef.of(m);
    if (ref == null) {
      issues.add(ValidationIssue('expands', 'Missing "expands": an expansion names the module it adds to'));
    } else if (ref.id == m['id']) {
      issues.add(ValidationIssue('expands.id', 'An expansion cannot expand itself'));
    } else if (!isModuleId(ref.id)) {
      issues.add(
        ValidationIssue(
          'expands.id',
          'Should be a module id (lowercase letters, digits, "-", "_" and "."): "${ref.id}"',
        ),
      );
    }
  } on SpecFormatException catch (e) {
    issues.add(ValidationIssue(e.path, e.message));
  }
  if (m['format'] case final int format when m['minAppVersion'] is String) {
    issues.addAll(versionIssues(format, m['minAppVersion'] as String, appVersion));
  }

  void ref(String path, Object? value) {
    if (imageRefIssue(path, value) case final issue?) issues.add(issue);
  }

  if (m['symbols'] case final Map symbols) {
    for (final e in symbols.entries) {
      ref('symbols.${e.key}', e.value);
    }
  }
  void entries(Object? node, String path) {
    switch (node) {
      case Map n:
        if (n['type'] == 'entry') ref('$path.image', n['image']);
        for (final e in n.entries) {
          entries(e.value, '$path.${e.key}');
        }
      case List l:
        for (var i = 0; i < l.length; i++) {
          entries(l[i], '$path[$i]');
        }
    }
  }

  entries(m['tabs'], 'tabs');
  if (m['collections'] case final Map collections) {
    for (final e in collections.entries) {
      final name = '${e.key}';
      if (!isPlainName(name)) {
        issues.add(ValidationIssue('collections.$name', 'Collection names may only use letters, digits, "-" and "_"'));
        continue;
      }
      final spec = e.value is Map ? e.value as Map : const {};
      final idField = '${spec['idField'] ?? 'id'}';
      for (final key in ['imageField', 'backImageField']) {
        if (spec[key] != null && spec[key] is! String) {
          issues.add(ValidationIssue('collections.$name.$key', 'Should be text (the name of a field)'));
        }
      }
      final fields = [_text(spec['imageField']) ?? 'image', ?_text(spec['backImageField'])];
      final ids = <String>{};
      final items = expansion.itemsOf(name);
      var unverified = 0;
      for (var i = 0; i < items.length; i++) {
        final at = 'collections.$name[$i]';
        final id = items[i][idField];
        if (id is! String || id.isEmpty) {
          issues.add(ValidationIssue('$at.$idField', 'Every item needs a text id'));
        } else if (!ids.add(id)) {
          issues.add(ValidationIssue('$at.$idField', 'Duplicate item id "$id"'));
        }
        for (final f in fields) {
          ref('$at.$f', items[i][f]);
        }
        if (items[i]['verified'] == false) unverified++;
      }
      if (unverified > 0) {
        issues.add(
          ValidationIssue(
            'collections.$name',
            '$unverified item${unverified == 1 ? '' : 's'} marked verified: false',
            fatal: false,
          ),
        );
      }
    }
  }
  return issues;
}

/// [value] when it is text, else null: settings read from JSON never cast.
String? _text(Object? value) => value is String ? value : null;
