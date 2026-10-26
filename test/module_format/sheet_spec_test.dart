import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/module_format/sheet_spec.dart';
import 'package:vale_helper/module_format/spec_json.dart';

Matcher failsAt(String path, [Object? message]) => throwsA(
  isA<SpecFormatException>()
      .having((e) => e.path, 'path', path)
      .having((e) => e.message, 'message', message ?? anything),
);

void main() {
  test('an empty sheet has no chips, effects, sections, details, swipe or zones', () {
    final s = SheetSpec.fromJson({}, 'sheet');
    expect(s.chips, isEmpty);
    expect(s.effects, isNull);
    expect(s.sections, isEmpty);
    expect(s.secondary, isNull);
    expect(s.verifiedPath, isNull);
    expect(s.details, isNull);
    expect(s.detailSections, isEmpty);
    expect(s.swipe.isEmpty, isTrue);
    expect(s.swipe.sides, isEmpty);
    expect(s.zones, isEmpty);
    expect(SheetSpec.empty.chips, isEmpty);
  });

  test('parses every part of the mini module sheet', () {
    final s = SheetSpec.fromJson({
      'chips': [
        {'symbol': '{family}', 'text': '{familyLabel}'},
        {'text': 'Cost {cost}'},
        {'label': 'Sells', 'symbols': 'sellsFor'},
      ],
      'effects': {
        'path': 'fx',
        'typeLabels': {'instant': 'Instant'},
        'typeSymbols': {'instant': 'instant'},
        'typeHelp': {'instant': 'Triggers once.'},
      },
      'sections': [
        {'label': 'Ability', 'path': 'ability'},
        {'path': 'notes'},
      ],
      'secondary': '{set}',
      'verifiedPath': 'verified',
      'details': {
        'hint': 'Interactions',
        'sections': [
          {'label': 'Interactions', 'path': 'interactions'},
        ],
      },
      'swipe': {'left': 'a', 'right': 'b'},
      'zones': ['a', 'b'],
    }, 'sheet');
    expect(s.chips, hasLength(3));
    expect(s.chips[0].symbol, '{family}');
    expect(s.chips[0].text, '{familyLabel}');
    expect(s.chips[2].label, 'Sells');
    expect(s.chips[2].symbols, 'sellsFor');
    expect(s.effects!.path, 'fx');
    expect(s.effects!.typeLabels, {'instant': 'Instant'});
    expect(s.effects!.typeSymbols, {'instant': 'instant'});
    expect(s.effects!.typeHelp, {'instant': 'Triggers once.'});
    expect(s.sections[0].label, 'Ability');
    expect(s.sections[0].path, 'ability');
    expect(s.sections[1].label, '');
    expect(s.secondary, '{set}');
    expect(s.verifiedPath, 'verified');
    expect(s.details!.hint, 'Interactions');
    expect(s.detailSections.single.path, 'interactions');
    expect(s.swipe.left, 'a');
    expect(s.swipe.right, 'b');
    expect(s.swipe.sides, {'left': 'a', 'right': 'b'});
    expect(s.zones, ['a', 'b']);
  });

  test('effects default to the "effects" path and empty type maps', () {
    final e = EffectsSpec.fromJson({}, 'e');
    expect(e.path, 'effects');
    expect(e.typeLabels, isEmpty);
    expect(e.typeSymbols, isEmpty);
    expect(e.typeHelp, isEmpty);
  });

  test('a swipe with one side set lists only that side', () {
    final s = SwipeSpec.fromJson({'right': 'hand'}, 'sw');
    expect(s.isEmpty, isFalse);
    expect(s.sides, {'right': 'hand'});
  });

  test('firstChipText is the first chip text that resolves', () {
    final s = SheetSpec.fromJson({
      'chips': [
        {'symbol': '{family}'},
        {'text': '{missing}'},
        {'text': 'Cost {cost}'},
      ],
    }, 'sheet');
    expect(s.firstChipText({'cost': 3}), 'Cost 3');
    expect(
      SheetSpec.fromJson({
        'chips': [
          {'symbol': '{family}'},
        ],
      }, 'sheet').firstChipText({}),
      isNull,
    );
  });

  test('wrong shapes fail at their path', () {
    expect(
      () => SheetSpec.fromJson({
        'chips': ['Cost'],
      }, 'sheet'),
      failsAt('sheet.chips[0]', 'Should be an object'),
    );
    expect(
      () => SheetSpec.fromJson({
        'chips': [
          {'text': 3},
        ],
      }, 'sheet'),
      failsAt('sheet.chips[0].text', 'Should be text'),
    );
    expect(() => SheetSpec.fromJson({'effects': 'effects'}, 'sheet'), failsAt('sheet.effects'));
    expect(
      () => SheetSpec.fromJson({
        'effects': {'path': 1},
      }, 'sheet'),
      failsAt('sheet.effects.path'),
    );
    expect(
      () => SheetSpec.fromJson({
        'effects': {
          'typeLabels': {'instant': 1},
        },
      }, 'sheet'),
      failsAt('sheet.effects.typeLabels', 'Values should be text'),
    );
    expect(
      () => SheetSpec.fromJson({
        'sections': [
          {'label': 'Ability'},
        ],
      }, 'sheet'),
      failsAt('sheet.sections[0].path'),
    );
    expect(() => SheetSpec.fromJson({'secondary': 1}, 'sheet'), failsAt('sheet.secondary'));
    expect(() => SheetSpec.fromJson({'verifiedPath': 1}, 'sheet'), failsAt('sheet.verifiedPath'));
    expect(() => SheetSpec.fromJson({'details': []}, 'sheet'), failsAt('sheet.details'));
    expect(
      () => SheetSpec.fromJson({
        'details': {'hint': 1},
      }, 'sheet'),
      failsAt('sheet.details.hint'),
    );
    expect(
      () => SheetSpec.fromJson({
        'details': {
          'sections': [
            {'label': 'Interactions'},
          ],
        },
      }, 'sheet'),
      failsAt('sheet.details.sections[0].path'),
    );
    expect(
      () => SheetSpec.fromJson({
        'details': {
          'sections': [
            {'label': 3, 'path': 'story'},
          ],
        },
      }, 'sheet'),
      failsAt('sheet.details.sections[0].label'),
    );
    expect(
      () => SheetSpec.fromJson({
        'swipe': {'up': 'a'},
      }, 'sheet'),
      failsAt('sheet.swipe.up', 'Swipe directions are "left" and "right"'),
    );
    expect(
      () => SheetSpec.fromJson({
        'swipe': {'left': 1},
      }, 'sheet'),
      failsAt('sheet.swipe.left'),
    );
    expect(() => SheetSpec.fromJson({'zones': 'a'}, 'sheet'), failsAt('sheet.zones', 'Should be a list of text'));
    expect(
      () => SheetSpec.fromJson({
        'zones': ['a', 2],
      }, 'sheet'),
      failsAt('sheet.zones'),
    );
  });
  test('a section can ask for italic text (sheet.sections and details.sections)', () {
    final s = SheetSpec.fromJson({
      'sections': [
        {'label': 'Flavour', 'path': 'flavour', 'italic': true},
      ],
      'details': {
        'sections': [
          {'path': 'story', 'italic': true},
          {'path': 'rulings'},
        ],
      },
    }, 'sheet');
    expect(s.sections.single.italic, isTrue);
    expect(s.detailSections[0].italic, isTrue);
    expect(s.detailSections[1].italic, isFalse);
    expect(
      () => SheetSpec.fromJson({
        'sections': [
          {'path': 'x', 'italic': 'yes'},
        ],
      }, 'sheet'),
      failsAt('sheet.sections[0].italic'),
    );
  });
}
