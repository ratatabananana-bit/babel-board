/// The item sheet template of a collection (`collections.<id>.sheet`): chips, effects,
/// sections, drag-up details, flick-to-zone, and the zone buttons. Pure Dart.
library;

import 'path_expr.dart';
import 'spec_json.dart';

/// One chip of an item's template: text, a symbol, or a labeled row of symbols.
class ChipSpec {
  const ChipSpec({this.symbol, this.text, this.symbols, this.label});

  final String? symbol, text, symbols, label;

  static ChipSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    return ChipSpec(
      symbol: f.optText('symbol'),
      text: f.optText('text'),
      symbols: f.optText('symbols'),
      label: f.optText('label'),
    );
  }
}

/// `sheet.effects`: where an item's effects live and how each effect type is shown.
class EffectsSpec {
  const EffectsSpec({
    this.path = 'effects',
    this.typeLabels = const {},
    this.typeSymbols = const {},
    this.typeHelp = const {},
  });

  /// Path to the list of `{type, text}` effects in an item.
  final String path;
  final Map<String, String> typeLabels;
  final Map<String, String> typeSymbols;
  final Map<String, String> typeHelp;

  static EffectsSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    return EffectsSpec(
      path: f.optText('path') ?? 'effects',
      typeLabels: f.textMap('typeLabels'),
      typeSymbols: f.textMap('typeSymbols'),
      typeHelp: f.textMap('typeHelp'),
    );
  }
}

/// A labeled block of text on the sheet (`sheet.sections[]`, `sheet.details.sections[]`).
class SheetSectionSpec {
  const SheetSectionSpec({required this.path, this.label = '', this.italic = false});

  final String path;
  final String label;

  /// Draw the text in italics (flavour text, quotes). Since 3.3.3.
  final bool italic;

  static SheetSectionSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    return SheetSectionSpec(path: f.text('path'), label: f.optText('label') ?? '', italic: f.optBool('italic') ?? false);
  }
}

/// `sheet.details`: extra text (rulings, story…) hidden below the zone buttons until the
/// sheet is dragged up.
class DetailsSpec {
  const DetailsSpec({this.hint, this.sections = const []});

  /// Label next to the drag-up arrow, or null for the bare arrow.
  final String? hint;
  final List<SheetSectionSpec> sections;

  static DetailsSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    return DetailsSpec(
      hint: f.optText('hint'),
      sections: [for (final s in f.objectList('sections')) SheetSectionSpec.fromJson(s.json, s.where)],
    );
  }
}

/// `sheet.swipe`: flick the sheet left or right to put the item in a zone.
class SwipeSpec {
  const SwipeSpec({this.left, this.right});

  final String? left;
  final String? right;

  bool get isEmpty => left == null && right == null;

  /// Zone id per side (`left` / `right`), only the sides that are set.
  Map<String, String> get sides => {'left': ?left, 'right': ?right};

  static SwipeSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    for (final k in j.keys) {
      if (k != 'left' && k != 'right') f.fail(k, 'Swipe directions are "left" and "right"');
    }
    return SwipeSpec(left: f.optText('left'), right: f.optText('right'));
  }
}

/// The sheet template of a collection.
class SheetSpec {
  const SheetSpec({
    this.chips = const [],
    this.effects,
    this.sections = const [],
    this.secondary,
    this.verifiedPath,
    this.details,
    this.swipe = const SwipeSpec(),
    this.zones = const [],
  });

  static const empty = SheetSpec();

  final List<ChipSpec> chips;
  final EffectsSpec? effects;
  final List<SheetSectionSpec> sections;

  /// Template for the small line under the subtitle.
  final String? secondary;

  /// Path of the item's `verified` flag; `false` shows the "not verified" warning.
  final String? verifiedPath;
  final DetailsSpec? details;
  final SwipeSpec swipe;

  /// The zones offered as buttons, in order.
  final List<String> zones;

  List<SheetSectionSpec> get detailSections => details?.sections ?? const [];

  /// Text of the first chip that resolves to something, for the text-only card.
  String? firstChipText(Map<String, dynamic> item) {
    for (final c in chips) {
      final t = c.text == null ? null : fillTemplate(c.text!, item).trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }

  static SheetSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    final effects = f.optObject('effects');
    final details = f.optObject('details');
    final swipe = f.optObject('swipe');
    return SheetSpec(
      chips: [for (final c in f.objectList('chips')) ChipSpec.fromJson(c.json, c.where)],
      effects: effects == null ? null : EffectsSpec.fromJson(effects.json, effects.where),
      sections: [for (final s in f.objectList('sections')) SheetSectionSpec.fromJson(s.json, s.where)],
      secondary: f.optText('secondary'),
      verifiedPath: f.optText('verifiedPath'),
      details: details == null ? null : DetailsSpec.fromJson(details.json, details.where),
      swipe: swipe == null ? const SwipeSpec() : SwipeSpec.fromJson(swipe.json, swipe.where),
      zones: f.optTextList('zones') ?? const [],
    );
  }
}
