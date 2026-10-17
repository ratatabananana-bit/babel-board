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
  } on TypeError {
    fatal('module.json', 'A value has the wrong type (e.g. a number where text belongs)');
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

  // Typed checks for every setting a block or sheet reads, so a module that passes here
  // never fails while a tab is drawn.
  bool isText(Object? v) => v is String;
  void optText(String path, Object? v) {
    if (v != null && v is! String) fatal(path, 'Should be text');
  }

  void optBool(String path, Object? v) {
    if (v != null && v is! bool) fatal(path, 'Should be true or false');
  }

  void optInt(String path, Object? v) {
    if (v != null && v is! int) fatal(path, 'Should be a whole number');
  }

  void optTextList(String path, Object? v) {
    if (v == null) return;
    if (v is! List || !v.every(isText)) fatal(path, 'Should be a list of text');
  }

  /// Checks [v] is a list of objects (or absent); returns the objects with their paths.
  List<(String, Map)> optMapList(String path, Object? v) {
    if (v == null) return const [];
    if (v is! List) {
      fatal(path, 'Should be a list');
      return const [];
    }
    final out = <(String, Map)>[];
    for (var i = 0; i < v.length; i++) {
      if (v[i] is Map) {
        out.add(('$path[$i]', v[i] as Map));
      } else {
        fatal('$path[$i]', 'Should be an object');
      }
    }
    return out;
  }

  Map? optMap(String path, Object? v) {
    if (v == null) return null;
    if (v is! Map) {
      fatal(path, 'Should be an object');
      return null;
    }
    return v;
  }

  void requireCollection(String path, Map settings) {
    final c = settings['collection'];
    if (c is! String) {
      fatal('$path.collection', 'Missing "collection"');
    } else if (!m.collections.containsKey(c)) {
      fatal('$path.collection', 'Unknown collection "$c"');
    }
  }

  void checkFilter(String path, Object? v) {
    final f = optMap(path, v);
    if (f == null) return;
    final zone = f['zone'];
    if (zone != null && !zoneIds.contains(zone)) fatal('$path.zone', 'Unknown zone "$zone"');
    for (final (p, rule) in optMapList('$path.where', f['where'])) {
      if (rule['path'] is! String) fatal('$p.path', 'Every rule needs a "path"');
    }
  }

  // Item sheets.
  for (final e in m.collections.entries) {
    final p = 'collections.${e.key}.sheet';
    final sheet = e.value.sheet;
    for (final (cp, chip) in optMapList('$p.chips', sheet['chips'])) {
      for (final k in ['symbol', 'text', 'symbols', 'label']) {
        optText('$cp.$k', chip[k]);
      }
    }
    final effects = optMap('$p.effects', sheet['effects']);
    if (effects != null) {
      optText('$p.effects.path', effects['path']);
      for (final k in ['typeLabels', 'typeSymbols', 'typeHelp']) {
        final map = optMap('$p.effects.$k', effects[k]);
        if (map != null && !map.values.every(isText)) fatal('$p.effects.$k', 'Values should be text');
      }
    }
    for (final (sp, section) in optMapList('$p.sections', sheet['sections'])) {
      if (section['path'] is! String) fatal('$sp.path', 'Every section needs a "path"');
      optText('$sp.label', section['label']);
    }
    optText('$p.secondary', sheet['secondary']);
    optText('$p.verifiedPath', sheet['verifiedPath']);
    final zones = sheet['zones'];
    if (zones != null) {
      if (zones is! List) {
        fatal('$p.zones', 'Should be a list of zone ids');
      } else {
        for (var i = 0; i < zones.length; i++) {
          if (!zoneIds.contains(zones[i])) fatal('$p.zones[$i]', 'Unknown zone "${zones[i]}"');
        }
      }
    }
  }

  /// A step's settings (also the flow's `setup`). [rowIds] collects checklist ids across
  /// the whole flow, since ticks are saved per id.
  void checkStepSettings(String path, Map s, Set<String> rowIds) {
    for (final k in ['title', 'short', 'tag', 'summary', 'listTitle', 'nextLabel', 'emptyText']) {
      optText('$path.$k', s[k]);
    }
    optTextList('$path.how', s['how']);
    for (final (rp, row) in optMapList('$path.checklist', s['checklist'])) {
      final id = row['id'];
      if (id is! String || id.isEmpty) {
        fatal('$rp.id', 'Every checklist row needs a text "id"');
      } else if (!rowIds.add(id)) {
        fatal('$rp.id', 'Checklist id "$id" is used twice in this flow');
      }
      if (row['text'] is! String) fatal('$rp.text', 'Every checklist row needs "text"');
      optText('$rp.sub', row['sub']);
      optText('$rp.actionLabel', row['actionLabel']);
      final action = row['action'];
      if (action == null) continue;
      if (action is! Map) {
        fatal('$rp.action', 'Action should be {"type": ...}');
        continue;
      }
      final type = action['type'];
      if (!kChecklistActions.contains(type)) {
        fatal('$rp.action.type', 'Action must be one of ${kChecklistActions.join(', ')}: "$type"');
      } else if (type == 'clearZone' && !zoneIds.contains(action['zone'])) {
        fatal('$rp.action.zone', 'Unknown zone "${action['zone']}"');
      }
    }
    final cc = optMap('$path.cardChecklist', s['cardChecklist']);
    if (cc != null) {
      requireCollection('$path.cardChecklist', cc);
      checkFilter('$path.cardChecklist.filter', cc['filter']);
      optText('$path.cardChecklist.sub', cc['sub']);
    }
  }

  var flows = 0;
  void checkBlock(String path, BlockSpec b) {
    if (!kBlockTypes.contains(b.type)) {
      fatal(path, "Unknown block '${b.type}' — this game needs a newer Table Helper");
      return;
    }
    final s = b.settings;
    switch (b.type) {
      case 'gallery':
        requireCollection(path, s);
        optTextList('$path.search', s['search']);
        optBool('$path.tileName', s['tileName']);
        optText('$path.noun', s['noun']);
        optText('$path.searchHint', s['searchHint']);
        for (final (fp, f) in optMapList('$path.filters', s['filters'])) {
          if (f['path'] is! String) fatal('$fp.path', 'Every filter needs a "path"');
          optText('$fp.label', f['label']);
          optText('$fp.allLabel', f['allLabel']);
          for (final (op, o) in optMapList('$fp.options', f['options'])) {
            optText('$op.label', o['label']);
            optText('$op.symbol', o['symbol']);
          }
        }
        final sections = optMap('$path.sections', s['sections']);
        if (sections != null) {
          if (sections['path'] is! String) fatal('$path.sections.path', 'Sections need a "path"');
          optText('$path.sections.label', sections['label']);
          optBool('$path.sections.onlyWhenFiltered', sections['onlyWhenFiltered']);
          optBool('$path.sections.rail', sections['rail']);
          final range = sections['railRange'];
          if (range != null && !(range is List && range.length == 2 && range.every((n) => n is int))) {
            fatal('$path.sections.railRange', 'Should be two whole numbers, e.g. [0, 12]');
          }
        }
      case 'board':
        optText('$path.title', s['title']);
        optText('$path.countLabel', s['countLabel']);
        for (var i = 0; i < b.children.length; i++) {
          if (b.children[i].type != 'zone') {
            fatal('$path.children[$i]', 'A board holds only zones, not "${b.children[i].type}"');
          }
        }
      case 'zone':
        if (!zoneIds.contains(s['zone'])) fatal('$path.zone', 'Unknown zone "${s['zone']}"');
        final list = optMap('$path.list', s['list']);
        if (list != null) {
          try {
            checkBlock('$path.list', BlockSpec.fromJson(list.cast<String, dynamic>(), '$path.list'));
          } on FormatException catch (e) {
            fatal('$path.list', e.message);
          }
        }
      case 'cardList':
        requireCollection(path, s);
        final style = s['style'];
        if (style != null && !const {'mini', 'rows', 'thumbs'}.contains(style)) {
          fatal('$path.style', 'Style must be mini, rows or thumbs: "$style"');
        }
        optInt('$path.columns', s['columns']);
        optBool('$path.removable', s['removable']);
        optText('$path.emptyText', s['emptyText']);
        checkFilter('$path.filter', s['filter']);
      case 'flow':
        flows++;
        if (flows > 1) fatal(path, 'A module can have only one flow');
        optText('$path.title', s['title']);
        optBool('$path.cyclic', s['cyclic']);
        optTextList('$path.reminders', s['reminders']);
        optText('$path.newGameText', s['newGameText']);
        if (b.children.isEmpty) fatal('$path.children', 'A flow needs at least one step');
        final stepIds = <String>{};
        final rowIds = <String>{};
        final setup = optMap('$path.setup', s['setup']);
        if (setup != null) checkStepSettings('$path.setup', setup, rowIds);
        for (var i = 0; i < b.children.length; i++) {
          final c = b.children[i];
          final cp = '$path.children[$i]';
          if (c.type != 'step') {
            fatal(cp, 'A flow holds only steps, not "${c.type}"');
            continue;
          }
          final id = c.settings['id'];
          if (id is! String) {
            fatal('$cp.id', 'Every step needs an id');
          } else if (!stepIds.add(id)) {
            fatal('$cp.id', 'Duplicate step id "$id"');
          }
          checkStepSettings(cp, c.settings, rowIds);
        }
        // Steps were checked above with the flow's shared id set.
        return;
      case 'step':
        // A step outside a flow does nothing; checked here only for its own settings.
        checkStepSettings(path, s, <String>{});
      case 'text':
        optText('$path.title', s['title']);
        optTextList('$path.paragraphs', s['paragraphs']);
        optTextList('$path.bullets', s['bullets']);
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
