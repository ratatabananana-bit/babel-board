/// The typed settings of every block type, parsed once from a block's JSON. Pure Dart so
/// the validator and the tool scripts share the parsers with the app. Each `fromJson`
/// takes the block's whole object (`type`, its settings, `children`) and the path of
/// that object in `module.json`, and throws [SpecFormatException] at the offending path
/// when a value has the wrong shape.
library;

import 'filter.dart';
import 'spec_json.dart';

const kChecklistActions = {'clearZone', 'newGame'};
const kCardListStyles = {'mini', 'rows', 'thumbs'};

/// One node of a tab's block tree, in its typed form. [fromJson] picks the parser by
/// `type`; a type the app does not know is an error that reads "needs a newer Table Helper".
sealed class BlockSpec {
  const BlockSpec();

  /// The block type this spec was parsed from, one of [kBlockTypes].
  String get type;

  static BlockSpec fromJson(Map<String, dynamic> j, String where) {
    final type = Fields(j, where).text('type');
    final parse = blockParsers[type];
    if (parse == null) {
      throw SpecFormatException(where, "Unknown block '$type' — this game needs a newer Table Helper");
    }
    return parse(j, where);
  }
}

// ---------------------------------------------------------------------------- gallery

class FilterOption {
  const FilterOption({required this.value, required this.label, this.symbol});

  final Object? value;
  final String label;
  final String? symbol;

  static FilterOption fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    final value = j['value'];
    return FilterOption(value: value, label: f.optText('label') ?? '$value', symbol: f.optText('symbol'));
  }
}

/// One single-select filter dock: `{path, label?, allLabel?, options: [{value, label?, symbol?}]}`.
class FilterSpec {
  const FilterSpec({required this.path, this.label = '', this.allLabel = 'All', this.options = const []});

  final String path;
  final String label;
  final String allLabel;
  final List<FilterOption> options;

  static FilterSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    return FilterSpec(
      path: f.text('path'),
      label: f.optText('label') ?? '',
      allLabel: f.optText('allLabel') ?? 'All',
      options: [for (final o in f.objectList('options')) FilterOption.fromJson(o.json, o.where)],
    );
  }
}

/// Grouping of the gallery by a field, with an optional jump rail.
class SectionsSpec {
  const SectionsSpec({
    required this.path,
    this.label = '{value}',
    this.onlyWhenFiltered = false,
    this.rail = false,
    this.railRange,
  });

  final String path;
  final String label;
  final bool onlyWhenFiltered;
  final bool rail;

  /// `[first, last]`: fixed rail slots for this range of values.
  final List<int>? railRange;

  static SectionsSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    final range = j['railRange'];
    if (range != null && !(range is List && range.length == 2 && range.every((n) => n is int))) {
      f.fail('railRange', 'Should be two whole numbers, e.g. [0, 12]');
    }
    return SectionsSpec(
      path: f.text('path'),
      label: f.optText('label') ?? '{value}',
      onlyWhenFiltered: f.optBool('onlyWhenFiltered') ?? false,
      rail: f.optBool('rail') ?? false,
      railRange: (range as List?)?.cast<int>(),
    );
  }
}

/// `gallery`: `{collection, search?: [path], tileName?, filters?: [...], sections?: {...}, noun?, searchHint?}`.
class GallerySpec extends BlockSpec {
  @override
  String get type => 'gallery';

  const GallerySpec({
    required this.collection,
    this.search = const ['name'],
    this.tileName = true,
    this.filters = const [],
    this.sections,
    this.noun = 'cards',
    String? searchHint,
  }) : searchHint = searchHint ?? 'Search $noun';

  final String collection;
  final List<String> search;
  final bool tileName;
  final List<FilterSpec> filters;
  final SectionsSpec? sections;

  /// What the summary counts, e.g. "cards".
  final String noun;
  final String searchHint;

  static GallerySpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    final sections = f.optObject('sections');
    return GallerySpec(
      collection: f.text('collection'),
      search: f.optTextList('search') ?? const ['name'],
      tileName: f.optBool('tileName') ?? true,
      filters: [for (final x in f.objectList('filters')) FilterSpec.fromJson(x.json, x.where)],
      sections: sections == null ? null : SectionsSpec.fromJson(sections.json, sections.where),
      noun: f.optText('noun') ?? 'cards',
      searchHint: f.optText('searchHint'),
    );
  }
}

// ------------------------------------------------------------------- board / cardList

/// `cardList`: `{collection, style?: mini|rows|thumbs, columns?, filter?, removable?, emptyText?, title?}`.
/// Also the list style inside a `zone`.
class CardListSpec extends BlockSpec {
  @override
  String get type => 'cardList';

  const CardListSpec({
    required this.collection,
    this.style = 'mini',
    this.columns = 2,
    this.filter,
    this.removable = false,
    this.emptyText,
    this.title,
  });

  final String collection;
  final String style;
  final int columns;
  final ItemFilter? filter;
  final bool removable;

  /// Shown in the lane when it has no items (and nothing can be dragged in).
  final String? emptyText;

  /// Heading when the list stands on its own (not inside a zone).
  final String? title;

  static CardListSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    final style = f.optText('style') ?? 'mini';
    if (!kCardListStyles.contains(style)) f.fail('style', 'Style must be mini, rows or thumbs: "$style"');
    final filter = f.optObject('filter');
    return CardListSpec(
      collection: f.text('collection'),
      style: style,
      columns: f.optInt('columns') ?? 2,
      filter: filter == null ? null : ItemFilter.fromJson(filter.json, filter.where),
      removable: f.optBool('removable') ?? false,
      emptyText: f.optText('emptyText'),
      title: f.optText('title'),
    );
  }
}

/// `zone`: one lane of a board, `{zone: id, list?: {type: cardList, ...}}`.
class ZoneBlockSpec extends BlockSpec {
  @override
  String get type => 'zone';

  const ZoneBlockSpec({required this.zone, this.list});

  /// The id of a declared zone.
  final String zone;

  /// How the lane lists its items; null means a plain `cardList` of the first collection.
  final CardListSpec? list;

  static ZoneBlockSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    final list = f.optObject('list');
    if (list != null) {
      final t = list.text('type');
      if (t != 'cardList') list.fail('type', 'A zone lists its items with a cardList, not "$t"');
    }
    return ZoneBlockSpec(
      zone: f.text('zone'),
      list: list == null ? null : CardListSpec.fromJson(list.json, list.where),
    );
  }
}

/// `board`: `{title?, countLabel?: template with {count}, children: [zone]}`.
class BoardSpec extends BlockSpec {
  @override
  String get type => 'board';

  const BoardSpec({this.title = 'Board', this.countLabel = '{count} tracked', this.zones = const []});

  final String title;
  final String countLabel;
  final List<ZoneBlockSpec> zones;

  static BoardSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    final zones = <ZoneBlockSpec>[];
    for (final c in f.objectList('children')) {
      final t = c.text('type');
      if (t != 'zone') throw SpecFormatException(c.where, 'A board holds only zones, not "$t"');
      zones.add(ZoneBlockSpec.fromJson(c.json, c.where));
    }
    return BoardSpec(
      title: f.optText('title') ?? 'Board',
      countLabel: f.optText('countLabel') ?? '{count} tracked',
      zones: zones,
    );
  }
}

// ----------------------------------------------------------------------- flow / step

/// What a checklist row's button does: `{"type": "clearZone", "zone": id}` or `{"type": "newGame"}`.
class ChecklistAction {
  const ChecklistAction({required this.type, this.zone});

  final String type;
  final String? zone;

  static ChecklistAction fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    final type = j['type'];
    if (type is! String || !kChecklistActions.contains(type)) {
      f.fail('type', 'Action must be one of ${kChecklistActions.join(', ')}: "$type"');
    }
    return ChecklistAction(type: type, zone: type == 'clearZone' ? f.text('zone') : f.optText('zone'));
  }
}

/// A checklist row from module data: `{id, text, sub?, action?, actionLabel?}`.
class ChecklistRow {
  const ChecklistRow({required this.id, required this.text, this.sub, this.action, this.actionLabel});

  final String id;
  final String text;
  final String? sub;
  final ChecklistAction? action;
  final String? actionLabel;

  static ChecklistRow fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    final id = f.optText('id');
    if (id == null || id.isEmpty) f.fail('id', 'Every checklist row needs a text "id"');
    final action = f.optObject('action');
    return ChecklistRow(
      id: id,
      text: f.text('text'),
      sub: f.optText('sub'),
      action: action == null ? null : ChecklistAction.fromJson(action.json, action.where),
      actionLabel: f.optText('actionLabel'),
    );
  }
}

/// `step.cardChecklist`: the rows are the items of [collection] matching [filter].
class CardChecklistSpec {
  CardChecklistSpec({required this.collection, ItemFilter? filter, this.sub}) : filter = filter ?? ItemFilter();

  final String collection;
  final ItemFilter filter;

  /// Template for the line under each item's name.
  final String? sub;

  static CardChecklistSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    final filter = f.optObject('filter');
    return CardChecklistSpec(
      collection: f.text('collection'),
      filter: filter == null ? null : ItemFilter.fromJson(filter.json, filter.where),
      sub: f.optText('sub'),
    );
  }
}

/// One step of a flow (a `step` block, or the flow's `setup`).
class StepSpec extends BlockSpec {
  @override
  String get type => 'step';

  const StepSpec({
    this.id = 'step',
    this.title = '',
    this.short,
    this.tag,
    this.summary = '',
    this.listTitle = 'Checklist',
    this.nextLabel,
    this.emptyText,
    this.how = const [],
    this.checklist = const [],
    this.cardChecklist,
  });

  final String id;
  final String title;
  final String? short;
  final String? tag;
  final String summary;
  final String listTitle;
  final String? nextLabel;
  final String? emptyText;
  final List<String> how;
  final List<ChecklistRow> checklist;

  /// When set, the rows are the matching items instead of [checklist].
  final CardChecklistSpec? cardChecklist;

  static StepSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    final cc = f.optObject('cardChecklist');
    final rows = f.objectList('checklist');
    final checklist = <ChecklistRow>[];
    final ids = <String>{};
    for (final r in rows) {
      final row = ChecklistRow.fromJson(r.json, r.where);
      if (!ids.add(row.id)) r.fail('id', 'Checklist id "${row.id}" is used twice');
      checklist.add(row);
    }
    return StepSpec(
      id: f.optText('id') ?? 'step',
      title: f.optText('title') ?? '',
      short: f.optText('short'),
      tag: f.optText('tag'),
      summary: f.optText('summary') ?? '',
      listTitle: f.optText('listTitle') ?? 'Checklist',
      nextLabel: f.optText('nextLabel'),
      emptyText: f.optText('emptyText'),
      how: f.optTextList('how') ?? const [],
      checklist: checklist,
      cardChecklist: cc == null ? null : CardChecklistSpec.fromJson(cc.json, cc.where),
    );
  }
}

/// `flow`: `{title?, cyclic?, reminders?, newGameText?, setup?: step, children: [step]}`.
/// Step ids and checklist ids are unique across the whole flow (ticks are saved per id).
class FlowSpec extends BlockSpec {
  @override
  String get type => 'flow';

  const FlowSpec({
    this.title = 'Round',
    this.cyclic = true,
    this.reminders = const [],
    this.newGameText = 'Clears everything you tracked and starts over.',
    this.setup,
    this.steps = const [],
  });

  final String title;
  final bool cyclic;
  final List<String> reminders;
  final String newGameText;
  final StepSpec? setup;
  final List<StepSpec> steps;

  static FlowSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    final rowIds = <String>{};
    void checkRows(StepSpec step, String at) {
      for (var i = 0; i < step.checklist.length; i++) {
        final id = step.checklist[i].id;
        if (!rowIds.add(id)) {
          throw SpecFormatException('$at.checklist[$i].id', 'Checklist id "$id" is used twice in this flow');
        }
      }
    }

    StepSpec? setup;
    if (f.optObject('setup') case final s?) {
      setup = StepSpec.fromJson(s.json, s.where);
      checkRows(setup, s.where);
    }

    final children = f.objectList('children');
    if (children.isEmpty) f.fail('children', 'A flow needs at least one step');
    final stepIds = <String>{};
    final steps = <StepSpec>[];
    for (final c in children) {
      final t = c.text('type');
      if (t != 'step') throw SpecFormatException(c.where, 'A flow holds only steps, not "$t"');
      if (!c.has('id')) c.fail('id', 'Every step needs an id');
      final step = StepSpec.fromJson(c.json, c.where);
      if (!stepIds.add(step.id)) c.fail('id', 'Duplicate step id "${step.id}"');
      checkRows(step, c.where);
      steps.add(step);
    }
    return FlowSpec(
      title: f.optText('title') ?? 'Round',
      cyclic: f.optBool('cyclic') ?? true,
      reminders: f.optTextList('reminders') ?? const [],
      newGameText: f.optText('newGameText') ?? 'Clears everything you tracked and starts over.',
      setup: setup,
      steps: steps,
    );
  }
}

// ----------------------------------------------------------------------------- text

/// `text`: `{title?, paragraphs?: [String], bullets?: [String]}`.
class TextSpec extends BlockSpec {
  @override
  String get type => 'text';

  const TextSpec({this.title, this.paragraphs = const [], this.bullets = const []});

  final String? title;
  final List<String> paragraphs;
  final List<String> bullets;

  static TextSpec fromJson(Map<String, dynamic> j, String where) {
    final f = Fields(j, where);
    return TextSpec(
      title: f.optText('title'),
      paragraphs: f.optTextList('paragraphs') ?? const [],
      bullets: f.optTextList('bullets') ?? const [],
    );
  }
}

// -------------------------------------------------------------------------- catalog

/// Block type → parser: the one list of block types the app can draw. A module naming any
/// other type needs a newer Table Helper. A step's checklist is a setting of `step`, not a
/// block.
final Map<String, BlockSpec Function(Map<String, dynamic> j, String where)> blockParsers = {
  'gallery': GallerySpec.fromJson,
  'board': BoardSpec.fromJson,
  'zone': ZoneBlockSpec.fromJson,
  'cardList': CardListSpec.fromJson,
  'flow': FlowSpec.fromJson,
  'step': StepSpec.fromJson,
  'text': TextSpec.fromJson,
};

/// The fixed catalog of block types, in declaration order.
final Set<String> kBlockTypes = blockParsers.keys.toSet();
