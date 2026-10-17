import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/module_format/path_expr.dart';

void main() {
  final item = {
    'name': 'Imp',
    'cost': 2,
    'effects': [
      {'type': 'instant', 'text': 'A'},
      {'type': 'active', 'text': 'B'},
    ],
    'nested': {
      'deep': {'v': 'ok'},
    },
    'tags': ['x', 'y'],
  };

  test('walks maps and flattens lists', () {
    expect(resolvePath(item, 'effects.type'), ['instant', 'active']);
    expect(resolvePath(item, 'nested.deep.v'), ['ok']);
    expect(resolvePath(item, 'tags'), ['x', 'y']);
    expect(resolvePath(item, 'cost'), [2]);
  });

  test('filters list elements with [k=v]', () {
    expect(resolvePath(item, 'effects[type=active].text'), ['B']);
    expect(resolvePath(item, 'effects[type=none].text'), isEmpty);
  });

  test('missing paths resolve to an empty list', () {
    expect(resolvePath(item, 'missing.x'), isEmpty);
    expect(resolvePath(null, 'a'), isEmpty);
  });

  test('fillTemplate replaces {path} with joined values', () {
    expect(fillTemplate('Cost {cost}', {'cost': 2}), 'Cost 2');
    expect(fillTemplate('{effects.type}', item), 'instant, active');
    expect(fillTemplate('{effects[type=active].text}!', item), 'B!');
    expect(fillTemplate('[{missing}]', item), '[]');
  });
}
