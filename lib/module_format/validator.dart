/// Checks a module before it is installed or shown. Shared by the app and the CLI tools.
library;

import '../app_version.dart';
import 'block_specs.dart';
import 'filter.dart';
import 'manifest.dart';
import 'sheet_spec.dart';
import 'spec_json.dart';

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

  // From here on the typed parsers do the shape checks (block_specs.dart, sheet_spec.dart):
  // a module that parses never fails while a tab is drawn. What is left to check here is
  // what the parsers cannot know: that the zones and collections a spec names exist.
  void report(SpecFormatException e) => fatal(e.path, e.message);

  void checkZoneId(String path, String? id) {
    if (!zoneIds.contains(id)) fatal(path, 'Unknown zone "$id"');
  }

  void requireCollection(String path, String name) {
    if (!m.collections.containsKey(name)) fatal(path, 'Unknown collection "$name"');
  }

  void checkFilter(String path, ItemFilter? f) {
    if (f?.zone case final zone?) checkZoneId('$path.zone', zone);
  }

  // Item sheets.
  for (final e in m.collections.entries) {
    final p = 'collections.${e.key}.sheet';
    final SheetSpec sheet;
    try {
      sheet = SheetSpec.fromJson(e.value.sheet, p);
    } on SpecFormatException catch (e) {
      report(e);
      continue;
    }
    for (final side in sheet.swipe.sides.entries) {
      checkZoneId('$p.swipe.${side.key}', side.value);
    }
    for (var i = 0; i < sheet.zones.length; i++) {
      checkZoneId('$p.zones[$i]', sheet.zones[i]);
    }
  }

  void checkCardList(String path, CardListSpec list) {
    requireCollection('$path.collection', list.collection);
    checkFilter('$path.filter', list.filter);
  }

  void checkZone(String path, ZoneBlockSpec z) {
    checkZoneId('$path.zone', z.zone);
    if (z.list case final list?) checkCardList('$path.list', list);
  }

  /// A step (also the flow's `setup`): its actions and card checklist name real things.
  void checkStep(String path, StepSpec s) {
    for (var i = 0; i < s.checklist.length; i++) {
      final action = s.checklist[i].action;
      if (action?.type == 'clearZone') checkZoneId('$path.checklist[$i].action.zone', action!.zone);
    }
    if (s.cardChecklist case final cc?) {
      requireCollection('$path.cardChecklist.collection', cc.collection);
      checkFilter('$path.cardChecklist.filter', cc.filter);
    }
  }

  var flows = 0;
  void checkBlock(String path, BlockSpec b) {
    final parse = blockParsers[b.type];
    if (parse == null) {
      fatal(path, "Unknown block '${b.type}' — this game needs a newer Table Helper");
      return;
    }
    final Object spec;
    try {
      spec = parse(b.json, path);
    } on SpecFormatException catch (e) {
      report(e);
      return;
    }
    switch (spec) {
      case GallerySpec g:
        requireCollection('$path.collection', g.collection);
      case BoardSpec board:
        for (var i = 0; i < board.zones.length; i++) {
          checkZone('$path.children[$i]', board.zones[i]);
        }
      case ZoneBlockSpec z:
        checkZone(path, z);
      case CardListSpec list:
        checkCardList(path, list);
      case FlowSpec f:
        flows++;
        if (flows > 1) fatal(path, 'A module can have only one flow');
        if (f.setup case final setup?) checkStep('$path.setup', setup);
        for (var i = 0; i < f.steps.length; i++) {
          checkStep('$path.children[$i]', f.steps[i]);
        }
      case StepSpec s:
        // A step outside a flow does nothing; checked here only for its own settings.
        checkStep(path, s);
      case TextSpec():
        break;
    }
  }

  for (var i = 0; i < m.tabs.length; i++) {
    checkBlock('tabs[$i].block', m.tabs[i].block);
  }
  return issues;
}
