/// Checks a module before it is installed or shown. Shared by the app and the CLI tools.
library;

import '../app_version.dart';
import 'block_types.dart';
import 'manifest.dart';

class ValidationIssue {
  ValidationIssue(this.path, this.message, {this.fatal = true});

  /// Where in `module.json` (or `collections.<id>[n].<field>`) the problem is.
  final String path;
  final String message;
  final bool fatal;

  @override
  String toString() => '${fatal ? 'ERROR' : 'WARN'} $path: $message';
}

const kNeedsNewerApp = 'This game needs a newer Table Helper';
const kZoneAccents = {'amber', 'mint', 'violet'};
const kChecklistActions = {'clearZone', 'newGame'};

/// Compares `x.y.z` versions; missing parts count as 0.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
  final pa = parts(a), pb = parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

final _driveLetter = RegExp(r'^[A-Za-z]:');
final _plainName = RegExp(r'^[A-Za-z0-9_-]+$');

/// True for `https://…` links and relative paths that stay inside the module folder.
bool isSafeImageRef(String ref) {
  if (ref.startsWith('https://')) return true;
  if (ref.contains('://')) return false;
  if (ref.startsWith('/') || ref.startsWith(r'\')) return false;
  if (_driveLetter.hasMatch(ref)) return false;
  final parts = ref.replaceAll(r'\', '/').split('/');
  return !parts.contains('..');
}

/// Validates the manifest JSON plus the resolved item lists of its collections.
/// Inline collections need no entry in [collections]; they are read from the manifest.
List<ValidationIssue> validateModule(
  Map<String, dynamic> manifestJson, {
  required Map<String, List<Map<String, dynamic>>> collections,
  String appVersion = kAppVersion,
}) {
  final issues = <ValidationIssue>[];
  void fatal(String path, String message) => issues.add(ValidationIssue(path, message));

  for (final k in ['format', 'id', 'name', 'version', 'minAppVersion']) {
    if (manifestJson[k] == null) fatal(k, 'Missing required field "$k"');
  }
  if (issues.isNotEmpty) return issues;

  final ModuleManifest m;
  try {
    m = ModuleManifest.fromJson(manifestJson);
  } on FormatException catch (e) {
    fatal('module.json', e.message);
    return issues;
  }

  if (m.format > kModuleFormat) {
    fatal('format', '$kNeedsNewerApp (module format ${m.format}, app understands $kModuleFormat)');
  }
  if (compareVersions(m.minAppVersion, appVersion) > 0) {
    fatal('minAppVersion', '$kNeedsNewerApp (needs ${m.minAppVersion}, this is $appVersion)');
  }
  if (m.tabs.isEmpty) fatal('tabs', 'A module needs at least one tab');

  void checkImage(String path, Object? ref) {
    if (ref == null) return;
    if (ref is! String) {
      fatal(path, 'Image should be a path or https link');
    } else if (ref.isNotEmpty && !isSafeImageRef(ref)) {
      fatal(
        path,
        'Image must be an https link or a relative path inside the module (no "..", no leading slash or drive letter): "$ref"',
      );
    }
  }

  checkImage('icon', m.icon);
  for (final e in m.symbols.entries) {
    checkImage('symbols.${e.key}', e.value);
  }

  final zoneIds = <String>{};
  for (var i = 0; i < m.zones.length; i++) {
    final z = m.zones[i];
    if (!zoneIds.add(z.id)) fatal('zones[$i].id', 'Duplicate zone id "${z.id}"');
    if (!kZoneAccents.contains(z.accent)) {
      fatal('zones[$i].accent', 'Accent must be one of ${kZoneAccents.join(', ')}: "${z.accent}"');
    }
  }

  // Collections: resolved items, unique ids, safe image refs, unverified count.
  for (final e in m.collections.entries) {
    final name = e.key;
    final spec = e.value;
    if (!_plainName.hasMatch(name)) {
      fatal('collections.$name', 'Collection names may only use letters, digits, "-" and "_"');
      continue;
    }
    final items = spec.isInline ? spec.inlineItems : collections[name];
    if (items == null) {
      fatal('collections.$name', 'Collection file "${spec.path}" was not loaded');
      continue;
    }
    final ids = <String>{};
    var unverified = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final id = item[spec.idField];
      if (id is! String || id.isEmpty) {
        fatal('collections.$name[$i].${spec.idField}', 'Every item needs a text id');
      } else if (!ids.add(id)) {
        fatal('collections.$name[$i].${spec.idField}', 'Duplicate item id "$id"');
      }
      checkImage('collections.$name[$i].${spec.imageField}', item[spec.imageField]);
      if (item['verified'] == false) unverified++;
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

  void requireCollection(String path, Map<String, dynamic> settings) {
    final c = settings['collection'];
    if (c is! String) {
      fatal('$path.collection', 'Missing "collection"');
    } else if (!m.collections.containsKey(c)) {
      fatal('$path.collection', 'Unknown collection "$c"');
    }
  }

  void checkChecklist(String path, Object? list) {
    if (list is! List) return;
    for (var i = 0; i < list.length; i++) {
      final row = list[i];
      if (row is! Map) continue;
      final action = row['action'];
      if (action == null) continue;
      if (action is! Map) {
        fatal('$path[$i].action', 'Action should be {"type": ...}');
        continue;
      }
      final type = action['type'];
      if (!kChecklistActions.contains(type)) {
        fatal('$path[$i].action.type', 'Action must be one of ${kChecklistActions.join(', ')}: "$type"');
      } else if (type == 'clearZone' && !zoneIds.contains(action['zone'])) {
        fatal('$path[$i].action.zone', 'Unknown zone "${action['zone']}"');
      }
    }
  }

  void checkBlock(String path, BlockSpec b) {
    if (!kBlockTypes.contains(b.type)) {
      fatal(path, "Unknown block '${b.type}' — this game needs a newer Table Helper");
      return;
    }
    final s = b.settings;
    switch (b.type) {
      case 'gallery':
        requireCollection(path, s);
      case 'board':
        for (var i = 0; i < b.children.length; i++) {
          if (b.children[i].type != 'zone') {
            fatal('$path.children[$i]', 'A board holds only zones, not "${b.children[i].type}"');
          }
        }
      case 'zone':
        if (!zoneIds.contains(s['zone'])) fatal('$path.zone', 'Unknown zone "${s['zone']}"');
        final list = s['list'];
        if (list is Map) {
          checkBlock('$path.list', BlockSpec.fromJson(list.cast<String, dynamic>(), '$path.list'));
        }
      case 'cardList':
        requireCollection(path, s);
      case 'flow':
        if (b.children.isEmpty) fatal('$path.children', 'A flow needs at least one step');
        final stepIds = <String>{};
        for (var i = 0; i < b.children.length; i++) {
          final c = b.children[i];
          if (c.type != 'step') {
            fatal('$path.children[$i]', 'A flow holds only steps, not "${c.type}"');
            continue;
          }
          final id = c.settings['id'];
          if (id is! String) {
            fatal('$path.children[$i].id', 'Every step needs an id');
          } else if (!stepIds.add(id)) {
            fatal('$path.children[$i].id', 'Duplicate step id "$id"');
          }
        }
        final setup = s['setup'];
        if (setup is Map) checkChecklist('$path.setup.checklist', setup['checklist']);
      case 'step':
        checkChecklist('$path.checklist', s['checklist']);
        final cc = s['cardChecklist'];
        if (cc is Map) requireCollection('$path.cardChecklist', cc.cast<String, dynamic>());
      case 'text':
        break;
    }
    for (var i = 0; i < b.children.length; i++) {
      checkBlock('$path.children[$i]', b.children[i]);
    }
  }

  for (var i = 0; i < m.tabs.length; i++) {
    checkBlock('tabs[$i].block', m.tabs[i].block);
  }
  return issues;
}
