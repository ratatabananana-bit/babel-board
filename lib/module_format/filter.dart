/// Filters pick items for a card list or checklist: by zone and by field rules.
library;

import 'path_expr.dart';

class FieldRule {
  FieldRule({required this.path, this.has, this.equals});

  final String path;

  /// Any resolved value equals this.
  final Object? has;

  /// Exactly one value resolves and it equals this.
  final Object? equals;

  bool matches(Map<String, dynamic> item) {
    final values = resolvePath(item, path);
    if (has != null && !values.any((v) => v == has)) return false;
    if (equals != null && !(values.length == 1 && values.single == equals)) return false;
    return true;
  }

  static FieldRule fromJson(Map<String, dynamic> j) =>
      FieldRule(path: j['path'] as String, has: j['has'], equals: j['equals']);
}

class ItemFilter {
  ItemFilter({this.zone, this.where = const []});

  /// When set, only items currently in this zone match.
  final String? zone;
  final List<FieldRule> where;

  bool matches(Map<String, dynamic> item, String? itemZone) {
    if (zone != null && itemZone != zone) return false;
    return where.every((r) => r.matches(item));
  }

  static ItemFilter fromJson(Map<String, dynamic> j) => ItemFilter(
    zone: j['zone'] as String?,
    where: [for (final r in (j['where'] as List? ?? const [])) FieldRule.fromJson((r as Map).cast<String, dynamic>())],
  );
}
