/// The module manifest (`module.json`): what a game module declares.
/// Pure Dart so tool scripts can import it.
library;

T _req<T>(Map<String, dynamic> j, String key, String where) {
  final v = j[key];
  if (v is T) return v;
  if (v == null) throw FormatException('$where: missing "$key"');
  throw FormatException('$where: "$key" should be $T, got ${v.runtimeType}');
}

List<Map<String, dynamic>> _mapList(Object? v, String where) {
  if (v == null) return const [];
  if (v is! List) throw FormatException('$where should be a list');
  return [
    for (var i = 0; i < v.length; i++)
      if (v[i] is Map)
        (v[i] as Map).cast<String, dynamic>()
      else
        throw FormatException('$where[$i] should be an object'),
  ];
}

/// Runs [parse] and turns a wrong-typed value (a cast failure) into a [FormatException]
/// naming where it is, so a slightly wrong module gets a readable error, not a crash.
T _guard<T>(String where, T Function() parse) {
  try {
    return parse();
  } on FormatException {
    rethrow;
  } on TypeError {
    throw FormatException('$where has a value of the wrong type');
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

  static ModuleManifest fromJson(Map<String, dynamic> j) {
    const w = 'module.json';
    final collections = <String, CollectionSpec>{};
    final rawCollections = j['collections'];
    if (rawCollections is Map) {
      for (final e in rawCollections.entries) {
        final where = 'collections.${e.key}';
        if (e.value is! Map) throw FormatException('$where should be an object');
        collections['${e.key}'] = _guard(
          where,
          () => CollectionSpec.fromJson((e.value as Map).cast<String, dynamic>(), where),
        );
      }
    }
    final symbols = <String, String>{};
    final rawSymbols = j['symbols'];
    if (rawSymbols is Map) {
      for (final e in rawSymbols.entries) {
        if (e.value is! String) throw FormatException('symbols.${e.key} should be text (an image path or link)');
        symbols['${e.key}'] = e.value as String;
      }
    }
    final zones = _mapList(j['zones'], 'zones');
    final tabs = _mapList(j['tabs'], 'tabs');
    return ModuleManifest(
      format: _req<int>(j, 'format', w),
      id: _req<String>(j, 'id', w),
      name: _req<String>(j, 'name', w),
      version: _req<String>(j, 'version', w),
      minAppVersion: _req<String>(j, 'minAppVersion', w),
      icon: _guard('icon', () => j['icon'] as String?),
      players: _guard('players', () => j['players'] as String?),
      source: _guard('source', () => j['source'] as String?),
      collections: collections,
      symbols: symbols,
      zones: [
        for (var i = 0; i < zones.length; i++) _guard('zones[$i]', () => ZoneSpec.fromJson(zones[i], 'zones[$i]')),
      ],
      tabs: [for (var i = 0; i < tabs.length; i++) _guard('tabs[$i]', () => TabSpec.fromJson(tabs[i], 'tabs[$i]'))],
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
    this.sheet = const {},
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

  /// Item sheet template (chips, effects, sections, zones…); interpreted by the item view.
  final Map<String, dynamic> sheet;

  bool get isInline => items is List;
  String? get path => items is String ? items as String : null;
  List<Map<String, dynamic>> get inlineItems => items is List ? (items as List).cast<Map<String, dynamic>>() : const [];

  static CollectionSpec fromJson(Map<String, dynamic> j, String where) {
    final raw = j['items'];
    final Object items;
    if (raw is String) {
      items = raw;
    } else if (raw is List) {
      items = _mapList(raw, '$where.items');
    } else {
      throw FormatException('$where: "items" should be a path or a list');
    }
    return CollectionSpec(
      items: items,
      idField: j['idField'] as String? ?? 'id',
      imageField: j['imageField'] as String? ?? 'image',
      imageShape: j['imageShape'] as String? ?? 'card',
      cardAspect: (j['cardAspect'] as num?)?.toDouble() ?? 0.716,
      titleField: j['titleField'] as String? ?? 'name',
      subtitleField: j['subtitleField'] as String?,
      sheet: (j['sheet'] as Map?)?.cast<String, dynamic>() ?? const {},
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

  static ZoneSpec fromJson(Map<String, dynamic> j, String where) => ZoneSpec(
    id: _req<String>(j, 'id', where),
    label: _req<String>(j, 'label', where),
    icon: j['icon'] as String? ?? 'grid',
    accent: j['accent'] as String? ?? 'amber',
    hint: j['hint'] as String?,
    band: j['band'] as String?,
    phrase: j['phrase'] as String?,
  );
}

class TabSpec {
  TabSpec({required this.label, required this.icon, required this.block, this.badge});

  final String label;
  final String icon;

  /// `zoneCount` shows the number of tracked items on the tab.
  final String? badge;
  final BlockSpec block;

  static TabSpec fromJson(Map<String, dynamic> j, String where) => TabSpec(
    label: _req<String>(j, 'label', where),
    icon: j['icon'] as String? ?? 'grid',
    badge: j['badge'] as String?,
    block: BlockSpec.fromJson(_req<Map>(j, 'block', where).cast<String, dynamic>(), '$where.block'),
  );
}

/// One node of a tab's block tree: a type, its settings, and sub-blocks.
class BlockSpec {
  BlockSpec({required this.type, this.settings = const {}, this.children = const []});

  final String type;

  /// Every key except `type` and `children`.
  final Map<String, dynamic> settings;
  final List<BlockSpec> children;

  /// The block as JSON again, for the typed parsers in `block_specs.dart`.
  Map<String, dynamic> get json => {
    'type': type,
    ...settings,
    if (children.isNotEmpty) 'children': [for (final c in children) c.json],
  };

  static BlockSpec fromJson(Map<String, dynamic> j, String where) {
    final kids = _mapList(j['children'], '$where.children');
    return BlockSpec(
      type: _req<String>(j, 'type', where),
      settings: {
        for (final e in j.entries)
          if (e.key != 'type' && e.key != 'children') e.key: e.value,
      },
      children: [for (var i = 0; i < kids.length; i++) BlockSpec.fromJson(kids[i], '$where.children[$i]')],
    );
  }
}
