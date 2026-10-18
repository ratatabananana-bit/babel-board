/// The module manifest (`module.json`): what a game module declares, parsed once into
/// typed specs. Pure Dart so tool scripts can import it.
library;

import 'block_specs.dart';
import 'sheet_spec.dart';
import 'spec_json.dart';

/// Runs [parse]; a [SpecFormatException] is handed to [report] (and null returned) when
/// one is given, else rethrown. Lets the validator list every broken element instead of
/// stopping at the first.
T? _collect<T>(void Function(SpecFormatException e)? report, T Function() parse) {
  try {
    return parse();
  } on SpecFormatException catch (e) {
    if (report == null) rethrow;
    report(e);
    return null;
  }
}

class ModuleManifest {
  ModuleManifest({
    required this.format,
    required this.id,
    required this.name,
    required this.version,
    required this.minAppVersion,
    this.icon,
    this.players,
    this.source,
    this.collections = const {},
    this.symbols = const {},
    this.zones = const [],
    this.tabs = const [],
  });

  final int format;
  final String id;
  final String name;
  final String version;
  final String minAppVersion;
  final String? icon;
  final String? players;
  final String? source;
  final Map<String, CollectionSpec> collections;
  final Map<String, String> symbols;
  final List<ZoneSpec> zones;
  final List<TabSpec> tabs;

  /// Parses a manifest; throws [SpecFormatException] at the first wrong value.
  static ModuleManifest fromJson(Map<String, dynamic> j) => parse(j);

  /// Parses a manifest. With [report], a collection, zone, tab or sheet that fails to
  /// parse is reported and left out (a sheet falls back to [SheetSpec.empty]) instead of
  /// thrown, so every problem gets listed; the header fields still throw.
  static ModuleManifest parse(Map<String, dynamic> j, {void Function(SpecFormatException e)? report}) {
    final f = Fields(j, '');
    final collections = <String, CollectionSpec>{};
    final rawCollections = j['collections'];
    if (rawCollections is Map) {
      for (final e in rawCollections.entries) {
        final where = 'collections.${e.key}';
        final spec = _collect(report, () {
          if (e.value is! Map) throw SpecFormatException(where, 'Should be an object');
          return CollectionSpec.fromJson((e.value as Map).cast<String, dynamic>(), where, report: report);
        });
        if (spec != null) collections['${e.key}'] = spec;
      }
    }
    final symbols = <String, String>{};
    final rawSymbols = j['symbols'];
    if (rawSymbols is Map) {
      for (final e in rawSymbols.entries) {
        if (e.value is! String) throw SpecFormatException('symbols.${e.key}', 'Should be text (an image path or link)');
        symbols['${e.key}'] = e.value as String;
      }
    }
    return ModuleManifest(
      format: f.optInt('format') ?? f.fail('format', 'Missing "format"'),
      id: f.text('id'),
      name: f.text('name'),
      version: f.text('version'),
      minAppVersion: f.text('minAppVersion'),
      icon: f.optText('icon'),
      players: f.optText('players'),
      source: f.optText('source'),
      collections: collections,
      symbols: symbols,
      zones: [for (final z in f.objectList('zones')) ?_collect(report, () => ZoneSpec.fromJson(z.json, z.where))],
      tabs: [for (final t in f.objectList('tabs')) ?_collect(report, () => TabSpec.fromJson(t.json, t.where))],
    );
  }
}

/// A list of items (cards, racers…) with free-form fields.
class CollectionSpec {
  CollectionSpec({
    required this.items,
    this.idField = 'id',
    this.imageField = 'image',
    this.imageShape = 'card',
    this.cardAspect = 0.716,
    this.titleField = 'name',
    this.subtitleField,
    this.sheet = SheetSpec.empty,
  });

  /// A `String` path to a `{"items":[...]}` file inside the module, or the inline
  /// `List<Map<String, dynamic>>` of items.
  final Object items;
  final String idField;
  final String imageField;

  /// `card` (picture fills the printed shape) or `square` (framed card with title below).
  final String imageShape;

  /// Width / height of the printed card.
  final double cardAspect;
  final String titleField;
  final String? subtitleField;

  /// Item sheet template (chips, effects, sections, zones…).
  final SheetSpec sheet;

  bool get isInline => items is List;
  String? get path => items is String ? items as String : null;
  List<Map<String, dynamic>> get inlineItems => items is List ? (items as List).cast<Map<String, dynamic>>() : const [];

  static CollectionSpec fromJson(
    Map<String, dynamic> j,
    String where, {
    void Function(SpecFormatException e)? report,
  }) {
    final f = Fields(j, where);
    final raw = j['items'];
    final Object items;
    if (raw is String) {
      items = raw;
    } else if (raw is List) {
      items = [for (final i in f.objectList('items')) i.json];
    } else {
      f.fail('items', '"items" should be a path or a list');
    }
    final sheet = f.optObject('sheet');
    return CollectionSpec(
      items: items,
      idField: f.optText('idField') ?? 'id',
      imageField: f.optText('imageField') ?? 'image',
      imageShape: f.optText('imageShape') ?? 'card',
      cardAspect: f.optNumber('cardAspect') ?? 0.716,
      titleField: f.optText('titleField') ?? 'name',
      subtitleField: f.optText('subtitleField'),
      sheet: sheet == null
          ? SheetSpec.empty
          : _collect(report, () => SheetSpec.fromJson(sheet.json, sheet.where)) ?? SheetSpec.empty,
    );
  }
}

class ZoneSpec {
  ZoneSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.accent,
    this.hint,
    this.band,
    this.phrase,
  });

  final String id;
  final String label;
  final String icon;

  /// `amber`, `mint` or `violet`.
  final String accent;

  /// Short reminder shown in the lane header.
  final String? hint;

  /// Text of the band on tracked tiles; defaults to [label].
  final String? band;

  /// How the zone reads inside a sentence ("Add to this race"); defaults to [label].
  final String? phrase;
  String get inSentence => phrase ?? label;

  static ZoneSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    return ZoneSpec(
      id: f.text('id'),
      label: f.text('label'),
      icon: f.optText('icon') ?? 'grid',
      accent: f.optText('accent') ?? 'amber',
      hint: f.optText('hint'),
      band: f.optText('band'),
      phrase: f.optText('phrase'),
    );
  }
}

class TabSpec {
  TabSpec({required this.label, required this.icon, required this.block, this.badge});

  final String label;
  final String icon;

  /// `zoneCount` shows the number of tracked items on the tab.
  final String? badge;

  /// The tab's block, parsed into its typed spec.
  final BlockSpec block;

  static TabSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    final block = f.optObject('block') ?? f.fail('block', 'Missing "block"');
    return TabSpec(
      label: f.text('label'),
      icon: f.optText('icon') ?? 'grid',
      badge: f.optText('badge'),
      block: BlockSpec.fromJson(block.json, block.where),
    );
  }
}
