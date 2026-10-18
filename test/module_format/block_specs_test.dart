import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/module_format/block_specs.dart';
import 'package:vale_helper/module_format/spec_json.dart';

/// Matches a [SpecFormatException] at [path] (and, optionally, its message).
Matcher failsAt(String path, [Object? message]) => throwsA(
  isA<SpecFormatException>()
      .having((e) => e.path, 'path', path)
      .having((e) => e.message, 'message', message ?? anything),
);

Map<String, dynamic> step(String id, [Map<String, dynamic> more = const {}]) => {
  'type': 'step',
  'id': id,
  'title': id,
  ...more,
};

void main() {
  group('gallery', () {
    test('defaults', () {
      final g = GallerySpec.fromJson({'type': 'gallery', 'collection': 'cards'}, 'b');
      expect(g.collection, 'cards');
      expect(g.search, ['name']);
      expect(g.tileName, isTrue);
      expect(g.filters, isEmpty);
      expect(g.sections, isNull);
      expect(g.noun, 'cards');
      expect(g.searchHint, 'Search cards');
    });

    test('searchHint follows the noun unless given', () {
      expect(GallerySpec.fromJson({'collection': 'c', 'noun': 'racers'}, 'b').searchHint, 'Search racers');
      expect(GallerySpec.fromJson({'collection': 'c', 'searchHint': 'Find'}, 'b').searchHint, 'Find');
    });

    test('filters, options and sections', () {
      final g = GallerySpec.fromJson({
        'collection': 'c',
        'search': ['name', 'effects.text'],
        'tileName': false,
        'filters': [
          {
            'path': 'family',
            'label': 'Family',
            'allLabel': 'All families',
            'options': [
              {'value': 'fire', 'label': 'Fire', 'symbol': 'fire'},
              {'value': 3},
            ],
          },
        ],
        'sections': {
          'path': 'cost',
          'label': 'COST {value}',
          'onlyWhenFiltered': true,
          'rail': true,
          'railRange': [0, 12],
        },
      }, 'b');
      expect(g.search, ['name', 'effects.text']);
      expect(g.tileName, isFalse);
      final f = g.filters.single;
      expect(f.path, 'family');
      expect(f.label, 'Family');
      expect(f.allLabel, 'All families');
      expect(f.options[0].symbol, 'fire');
      expect(f.options[1].value, 3);
      expect(f.options[1].label, '3');
      final s = g.sections!;
      expect(s.label, 'COST {value}');
      expect(s.onlyWhenFiltered, isTrue);
      expect(s.rail, isTrue);
      expect(s.railRange, [0, 12]);
      final bare = FilterSpec.fromJson({'path': 'x'}, 'f');
      expect(bare.label, '');
      expect(bare.allLabel, 'All');
      final plain = SectionsSpec.fromJson({'path': 'cost'}, 's');
      expect(plain.label, '{value}');
      expect(plain.rail, isFalse);
      expect(plain.railRange, isNull);
    });

    test('wrong shapes fail at their path', () {
      expect(() => GallerySpec.fromJson({}, 'b'), failsAt('b.collection', 'Missing "collection"'));
      expect(() => GallerySpec.fromJson({'collection': 1}, 'b'), failsAt('b.collection'));
      expect(() => GallerySpec.fromJson({'collection': 'c', 'search': 'name'}, 'b'), failsAt('b.search'));
      expect(() => GallerySpec.fromJson({'collection': 'c', 'tileName': 'yes'}, 'b'), failsAt('b.tileName'));
      expect(() => GallerySpec.fromJson({'collection': 'c', 'filters': {}}, 'b'), failsAt('b.filters'));
      expect(
        () => GallerySpec.fromJson({
          'collection': 'c',
          'filters': [
            {'label': 'x'},
          ],
        }, 'b'),
        failsAt('b.filters[0].path'),
      );
      expect(
        () => GallerySpec.fromJson({
          'collection': 'c',
          'filters': [
            {
              'path': 'x',
              'options': ['fire'],
            },
          ],
        }, 'b'),
        failsAt('b.filters[0].options[0]'),
      );
      expect(() => GallerySpec.fromJson({'collection': 'c', 'sections': []}, 'b'), failsAt('b.sections'));
      expect(() => GallerySpec.fromJson({'collection': 'c', 'sections': {}}, 'b'), failsAt('b.sections.path'));
      for (final range in [
        1,
        [0],
        ['0', '12'],
        [0, 1, 2],
      ]) {
        expect(
          () => SectionsSpec.fromJson({'path': 'cost', 'railRange': range}, 's'),
          failsAt('s.railRange', 'Should be two whole numbers, e.g. [0, 12]'),
          reason: '$range',
        );
      }
    });
  });

  group('cardList and zone', () {
    test('defaults and fields', () {
      final c = CardListSpec.fromJson({'collection': 'cards'}, 'l');
      expect(c.style, 'mini');
      expect(c.columns, 2);
      expect(c.filter, isNull);
      expect(c.removable, isFalse);
      expect(c.emptyText, isNull);
      expect(c.title, isNull);
      final full = CardListSpec.fromJson({
        'collection': 'cards',
        'style': 'rows',
        'columns': 3,
        'removable': true,
        'emptyText': 'Empty',
        'title': 'Hand',
        'filter': {
          'zone': 'hand',
          'where': [
            {'path': 'cost', 'equals': 3},
          ],
        },
      }, 'l');
      expect(full.style, 'rows');
      expect(full.columns, 3);
      expect(full.removable, isTrue);
      expect(full.emptyText, 'Empty');
      expect(full.title, 'Hand');
      expect(full.filter!.zone, 'hand');
      expect(full.filter!.where.single.equals, 3);
    });

    test('wrong shapes fail at their path', () {
      expect(() => CardListSpec.fromJson({}, 'l'), failsAt('l.collection'));
      expect(() => CardListSpec.fromJson({'collection': 'c', 'style': 'grid'}, 'l'), failsAt('l.style'));
      expect(() => CardListSpec.fromJson({'collection': 'c', 'columns': 2.5}, 'l'), failsAt('l.columns'));
      expect(() => CardListSpec.fromJson({'collection': 'c', 'removable': 1}, 'l'), failsAt('l.removable'));
      expect(
        () => CardListSpec.fromJson({
          'collection': 'c',
          'filter': {
            'where': [
              {'has': 'x'},
            ],
          },
        }, 'l'),
        failsAt('l.filter.where[0].path'),
      );
    });

    test('a zone names its zone and may carry a cardList', () {
      final bare = ZoneBlockSpec.fromJson({'type': 'zone', 'zone': 'a'}, 'z');
      expect(bare.zone, 'a');
      expect(bare.list, isNull);
      final listed = ZoneBlockSpec.fromJson({
        'zone': 'a',
        'list': {'type': 'cardList', 'collection': 'c', 'style': 'thumbs'},
      }, 'z');
      expect(listed.list!.style, 'thumbs');
      expect(() => ZoneBlockSpec.fromJson({}, 'z'), failsAt('z.zone'));
      expect(() => ZoneBlockSpec.fromJson({'zone': 'a', 'list': 'cards'}, 'z'), failsAt('z.list'));
      expect(
        () => ZoneBlockSpec.fromJson({
          'zone': 'a',
          'list': {'collection': 'c'},
        }, 'z'),
        failsAt('z.list.type'),
      );
      expect(
        () => ZoneBlockSpec.fromJson({
          'zone': 'a',
          'list': {'type': 'gallery', 'collection': 'c'},
        }, 'z'),
        failsAt('z.list.type'),
      );
      expect(
        () => ZoneBlockSpec.fromJson({
          'zone': 'a',
          'list': {'type': 'cardList'},
        }, 'z'),
        failsAt('z.list.collection'),
      );
    });
  });

  group('board', () {
    test('defaults and zones', () {
      final b = BoardSpec.fromJson({'type': 'board'}, 'b');
      expect(b.title, 'Board');
      expect(b.countLabel, '{count} tracked');
      expect(b.zones, isEmpty);
      final full = BoardSpec.fromJson({
        'title': 'My cards',
        'countLabel': '{count} cards',
        'children': [
          {'type': 'zone', 'zone': 'a'},
          {
            'type': 'zone',
            'zone': 'b',
            'list': {'type': 'cardList', 'collection': 'c'},
          },
        ],
      }, 'b');
      expect(full.title, 'My cards');
      expect(full.zones.map((z) => z.zone), ['a', 'b']);
      expect(full.zones[1].list!.collection, 'c');
    });

    test('children must be zones', () {
      expect(
        () => BoardSpec.fromJson({
          'children': [
            {'type': 'zone', 'zone': 'a'},
            {'type': 'text'},
          ],
        }, 'b'),
        failsAt('b.children[1]', 'A board holds only zones, not "text"'),
      );
      expect(
        () => BoardSpec.fromJson({
          'children': [
            {'zone': 'a'},
          ],
        }, 'b'),
        failsAt('b.children[0].type'),
      );
      expect(() => BoardSpec.fromJson({'children': 'zones'}, 'b'), failsAt('b.children'));
      expect(() => BoardSpec.fromJson({'title': 3}, 'b'), failsAt('b.title'));
    });
  });

  group('flow and step', () {
    test('step defaults', () {
      final s = StepSpec.fromJson({}, 's');
      expect(s.id, 'step');
      expect(s.title, '');
      expect(s.summary, '');
      expect(s.listTitle, 'Checklist');
      expect(s.how, isEmpty);
      expect(s.checklist, isEmpty);
      expect(s.cardChecklist, isNull);
      expect(s.short, isNull);
      expect(s.tag, isNull);
      expect(s.nextLabel, isNull);
      expect(s.emptyText, isNull);
    });

    test('step fields, checklist rows and actions', () {
      final s = StepSpec.fromJson({
        'id': 'one',
        'title': 'One',
        'short': '1',
        'tag': 'Wild',
        'summary': 'First.',
        'listTitle': 'Do',
        'nextLabel': 'Go',
        'emptyText': 'Nothing',
        'how': ['a', 'b'],
        'checklist': [
          {'id': 'one.a', 'text': 'Tick', 'sub': 'detail'},
          {
            'id': 'one.b',
            'text': 'Clear',
            'action': {'type': 'clearZone', 'zone': 'a'},
            'actionLabel': 'Clear',
          },
          {
            'id': 'one.c',
            'text': 'New',
            'action': {'type': 'newGame'},
          },
        ],
      }, 's');
      expect(s.id, 'one');
      expect(s.short, '1');
      expect(s.tag, 'Wild');
      expect(s.listTitle, 'Do');
      expect(s.nextLabel, 'Go');
      expect(s.emptyText, 'Nothing');
      expect(s.how, ['a', 'b']);
      expect(s.checklist[0].sub, 'detail');
      expect(s.checklist[0].action, isNull);
      expect(s.checklist[1].action!.type, 'clearZone');
      expect(s.checklist[1].action!.zone, 'a');
      expect(s.checklist[1].actionLabel, 'Clear');
      expect(s.checklist[2].action!.type, 'newGame');
      expect(s.checklist[2].action!.zone, isNull);
    });

    test('cardChecklist', () {
      final s = StepSpec.fromJson({
        'cardChecklist': {
          'collection': 'c',
          'filter': {
            'zone': 'b',
            'where': [
              {'path': 'effects.type', 'has': 'active'},
            ],
          },
          'sub': '{text}',
        },
      }, 's');
      final cc = s.cardChecklist!;
      expect(cc.collection, 'c');
      expect(cc.filter.zone, 'b');
      expect(cc.filter.where.single.has, 'active');
      expect(cc.sub, '{text}');
      final bare = StepSpec.fromJson({
        'cardChecklist': {'collection': 'c'},
      }, 's').cardChecklist!;
      expect(bare.filter.zone, isNull);
      expect(bare.filter.where, isEmpty);
      expect(() => StepSpec.fromJson({'cardChecklist': {}}, 's'), failsAt('s.cardChecklist.collection'));
      expect(
        () => StepSpec.fromJson({
          'cardChecklist': {'collection': 'c', 'filter': []},
        }, 's'),
        failsAt('s.cardChecklist.filter'),
      );
    });

    test('step and row shapes fail at their path', () {
      expect(
        () => StepSpec.fromJson({
          'how': [1],
        }, 's'),
        failsAt('s.how'),
      );
      expect(() => StepSpec.fromJson({'title': 1}, 's'), failsAt('s.title'));
      expect(() => StepSpec.fromJson({'checklist': {}}, 's'), failsAt('s.checklist'));
      expect(
        () => StepSpec.fromJson({
          'checklist': [
            {'text': 'x'},
          ],
        }, 's'),
        failsAt('s.checklist[0].id', 'Every checklist row needs a text "id"'),
      );
      expect(
        () => StepSpec.fromJson({
          'checklist': [
            {'id': '', 'text': 'x'},
          ],
        }, 's'),
        failsAt('s.checklist[0].id'),
      );
      expect(
        () => StepSpec.fromJson({
          'checklist': [
            {'id': 'a', 'text': 5},
          ],
        }, 's'),
        failsAt('s.checklist[0].text'),
      );
      expect(
        () => StepSpec.fromJson({
          'checklist': [
            {'id': 'a'},
          ],
        }, 's'),
        failsAt('s.checklist[0].text'),
      );
      expect(
        () => StepSpec.fromJson({
          'checklist': [
            {'id': 'a', 'text': 'x', 'action': 'newGame'},
          ],
        }, 's'),
        failsAt('s.checklist[0].action'),
      );
      expect(
        () => StepSpec.fromJson({
          'checklist': [
            {
              'id': 'a',
              'text': 'x',
              'action': {'type': 'explode'},
            },
          ],
        }, 's'),
        failsAt('s.checklist[0].action.type', contains('clearZone, newGame')),
      );
      expect(
        () => StepSpec.fromJson({
          'checklist': [
            {
              'id': 'a',
              'text': 'x',
              'action': {'type': 'clearZone'},
            },
          ],
        }, 's'),
        failsAt('s.checklist[0].action.zone'),
      );
    });

    test('flow defaults, setup and steps', () {
      final f = FlowSpec.fromJson({
        'type': 'flow',
        'children': [step('a')],
      }, 'f');
      expect(f.title, 'Round');
      expect(f.cyclic, isTrue);
      expect(f.reminders, isEmpty);
      expect(f.newGameText, 'Clears everything you tracked and starts over.');
      expect(f.setup, isNull);
      expect(f.steps.single.id, 'a');
      final full = FlowSpec.fromJson({
        'title': 'Race',
        'cyclic': false,
        'reminders': ['One', 'Two'],
        'newGameText': 'Over.',
        'setup': {
          'title': 'Setup',
          'checklist': [
            {'id': 'setup.a', 'text': 'x'},
          ],
        },
        'children': [
          step('a', {
            'checklist': [
              {'id': 'a.1', 'text': 'x'},
            ],
          }),
          step('b'),
        ],
      }, 'f');
      expect(full.title, 'Race');
      expect(full.cyclic, isFalse);
      expect(full.reminders, ['One', 'Two']);
      expect(full.newGameText, 'Over.');
      expect(full.setup!.id, 'step');
      expect(full.setup!.title, 'Setup');
      expect(full.steps.map((s) => s.id), ['a', 'b']);
    });

    test('a flow needs steps, only steps, each with a unique id', () {
      expect(() => FlowSpec.fromJson({}, 'f'), failsAt('f.children', 'A flow needs at least one step'));
      expect(() => FlowSpec.fromJson({'children': []}, 'f'), failsAt('f.children'));
      expect(
        () => FlowSpec.fromJson({
          'children': [
            step('a'),
            {'type': 'text'},
          ],
        }, 'f'),
        failsAt('f.children[1]', 'A flow holds only steps, not "text"'),
      );
      expect(
        () => FlowSpec.fromJson({
          'children': [
            {'type': 'step', 'title': 'No id'},
          ],
        }, 'f'),
        failsAt('f.children[0].id', 'Every step needs an id'),
      );
      expect(
        () => FlowSpec.fromJson({
          'children': [step('a'), step('a')],
        }, 'f'),
        failsAt('f.children[1].id', 'Duplicate step id "a"'),
      );
    });

    test('checklist ids are unique within a step', () {
      expect(
        () => StepSpec.fromJson({
          'checklist': [
            {'id': 'x', 'text': 'x'},
            {'id': 'x', 'text': 'again'},
          ],
        }, 's'),
        failsAt('s.checklist[1].id', 'Checklist id "x" is used twice'),
      );
    });

    test('checklist ids are unique across setup and every step', () {
      expect(
        () => FlowSpec.fromJson({
          'children': [
            step('a', {
              'checklist': [
                {'id': 'x', 'text': 'x'},
              ],
            }),
            step('b', {
              'checklist': [
                {'id': 'y', 'text': 'y'},
                {'id': 'x', 'text': 'x again'},
              ],
            }),
          ],
        }, 'f'),
        failsAt('f.children[1].checklist[1].id', 'Checklist id "x" is used twice in this flow'),
      );
      expect(
        () => FlowSpec.fromJson({
          'setup': {
            'checklist': [
              {'id': 'x', 'text': 'x'},
            ],
          },
          'children': [
            step('a', {
              'checklist': [
                {'id': 'x', 'text': 'x'},
              ],
            }),
          ],
        }, 'f'),
        failsAt('f.children[0].checklist[0].id'),
      );
      expect(
        () => FlowSpec.fromJson({
          'cyclic': 'yes',
          'children': [step('a')],
        }, 'f'),
        failsAt('f.cyclic'),
      );
      expect(
        () => FlowSpec.fromJson({
          'reminders': 'x',
          'children': [step('a')],
        }, 'f'),
        failsAt('f.reminders'),
      );
      expect(
        () => FlowSpec.fromJson({
          'setup': [],
          'children': [step('a')],
        }, 'f'),
        failsAt('f.setup'),
      );
    });
  });

  group('text', () {
    test('defaults and lists', () {
      final t = TextSpec.fromJson({'type': 'text'}, 't');
      expect(t.title, isNull);
      expect(t.paragraphs, isEmpty);
      expect(t.bullets, isEmpty);
      final full = TextSpec.fromJson({
        'title': 'About',
        'paragraphs': ['p'],
        'bullets': ['b'],
      }, 't');
      expect(full.title, 'About');
      expect(full.paragraphs, ['p']);
      expect(full.bullets, ['b']);
      expect(() => TextSpec.fromJson({'bullets': 'one line'}, 't'), failsAt('t.bullets', 'Should be a list of text'));
      expect(
        () => TextSpec.fromJson({
          'paragraphs': [1],
        }, 't'),
        failsAt('t.paragraphs'),
      );
      expect(() => TextSpec.fromJson({'title': []}, 't'), failsAt('t.title', 'Should be text'));
    });
  });

  test('SpecFormatException reads as path: message', () {
    final e = SpecFormatException('tabs[0].block.collection', 'Missing "collection"');
    expect(e, isA<FormatException>());
    expect('$e', 'tabs[0].block.collection: Missing "collection"');
    expect(specPath('', 'format'), 'format');
    expect(specPath('zones[0]', 'id'), 'zones[0].id');
  });
}
