import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/module_format/filter.dart';

void main() {
  final imp = {
    'id': 'imp',
    'effects': [
      {'type': 'instant', 'text': 'A'},
      {'type': 'active', 'text': 'Recover.'},
    ],
  };
  final hestia = {
    'id': 'hestia',
    'effects': [
      {'type': 'permanent', 'text': 'Keep two more stones.'},
    ],
  };

  test('zone + has rule matches items in that zone with the value', () {
    final f = ItemFilter.fromJson({
      'zone': 'field',
      'where': [
        {'path': 'effects.type', 'has': 'active'},
      ],
    });
    expect(f.zone, 'field');
    expect(f.matches(imp, 'field'), isTrue);
    expect(f.matches(imp, 'hand'), isFalse);
    expect(f.matches(imp, null), isFalse);
    expect(f.matches(hestia, 'field'), isFalse);
  });

  test('equals needs exactly one value equal to it', () {
    expect(FieldRule(path: 'effects.type', equals: 'permanent').matches(hestia), isTrue);
    expect(FieldRule(path: 'effects.type', equals: 'active').matches(imp), isFalse);
    expect(FieldRule(path: 'effects.type', has: 'active').matches(imp), isTrue);
  });

  test('filter without zone matches any zone, including untracked', () {
    final f = ItemFilter.fromJson({
      'where': [
        {'path': 'id', 'equals': 'imp'},
      ],
    });
    expect(f.matches(imp, null), isTrue);
    expect(f.matches(hestia, 'field'), isFalse);
  });

  test('inZone keeps items whose field names an item currently in that zone, lists included', () {
    final f = ItemFilter.fromJson({
      'where': [
        {'path': 'monster', 'inZone': 'inplay'},
      ],
    });
    String? zoneOf(String id) => id == 'archer' ? 'inplay' : null;
    expect(f.matches({'monster': 'archer'}, null, zoneOf: zoneOf), isTrue);
    expect(
      f.matches({
        'monster': ['guard', 'archer'],
      }, null, zoneOf: zoneOf),
      isTrue,
    );
    expect(f.matches({'monster': 'guard'}, null, zoneOf: zoneOf), isFalse);
    expect(f.matches({'monster': 'archer'}, null), isFalse, reason: 'no zone lookup, nothing is in play');
    // A rule with only a path was always accepted (it matches everything); it still is.
    expect(FieldRule.fromJson({'path': 'x'}).matches({'x': 1}), isTrue);
  });
}
