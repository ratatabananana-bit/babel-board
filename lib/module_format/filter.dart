/// Filters pick items for a card list or checklist: by zone and by field rules.
library;

import 'path_expr.dart';
import 'spec_json.dart';

/// Looks up the zone an item id is tracked in (null: not tracked).
typedef ZoneLookup = String? Function(String id);

class FieldRule {
  FieldRule({required this.path, this.has, this.equals, this.inZone});

  final String path;

  /// Any resolved value equals this.
  final Object? has;

  /// Exactly one value resolves and it equals this.
  final Object? equals;

  /// Any resolved value is the id of an item currently tracked in this zone (e.g. a monster
  /// card whose `monster` names a monster type put "in play").
  final String? inZone;

  bool matches(Map<String, dynamic> item, {ZoneLookup? zoneOf}) {
    final values = resolvePath(item, path);
    if (has != null && !values.any((v) => v == has)) return false;
    if (equals != null && !(values.length == 1 && values.single == equals)) return false;
    if (inZone != null && !values.any((v) => zoneOf?.call('$v') == inZone)) return false;
    return true;
  }

  static FieldRule fromJson(Map<String, dynamic> j, [String where = 'rule']) {
    final f = Fields(j, where);
    final rule = FieldRule(path: f.text('path'), has: j['has'], equals: j['equals'], inZone: f.optText('inZone'));
    if (rule.has == null && rule.equals == null && rule.inZone == null) {
      f.fail('path', 'A rule needs "has", "equals" or "inZone"');
    }
    return rule;
  }
}

class ItemFilter {
  ItemFilter({this.zone, this.where = const []});

  /// When set, only items currently in this zone match.
  final String? zone;
  final List<FieldRule> where;

  bool matches(Map<String, dynamic> item, String? itemZone, {ZoneLookup? zoneOf}) {
    if (zone != null && itemZone != zone) return false;
    return where.every((r) => r.matches(item, zoneOf: zoneOf));
  }

  static ItemFilter fromJson(Map<String, dynamic> j, [String where = 'filter']) {
    final f = Fields(j, where);
    return ItemFilter(
      zone: f.optText('zone'),
      where: [for (final r in f.objectList('where')) FieldRule.fromJson(r.json, r.where)],
    );
  }
}
