import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/module_format/block_specs.dart';
import 'package:vale_helper/module_format/expansion.dart';
import 'package:vale_helper/module_format/spec_json.dart';
import 'package:vale_helper/module_format/validator.dart';

/// A small valid base game: one collection, one zone, a board and a two-step flow.
ModuleData base() => ModuleData(
  {
    'format': 1,
    'id': 'g',
    'name': 'G',
    'version': '2.1.0',
    'minAppVersion': '3.0.0',
    'collections': {
      'cards': {
        'items': 'data/cards.json',
        'sheet': {
          'chips': [
            {'text': 'Cost {cost}'},
          ],
          'zones': ['hand'],
        },
      },
    },
    'symbols': {'fire': 'images/fire.webp'},
    'zones': [
      {'id': 'hand', 'label': 'Hand', 'accent': 'mint'},
    ],
    'tabs': [
      {
        'id': 'mine',
        'label': 'Mine',
        'block': {
          'type': 'board',
          'children': [
            {'type': 'zone', 'zone': 'hand'},
          ],
        },
      },
      {
        'id': 'round',
        'label': 'Round',
        'block': {
          'type': 'flow',
          'reminders': ['A.'],
          'children': [
            {
              'type': 'step',
              'id': 'one',
              'title': 'One',
              'how': ['x'],
              'checklist': [
                {'id': 'one.a', 'text': 'a'},
              ],
            },
            {'type': 'step', 'id': 'two', 'title': 'Two'},
          ],
        },
      },
    ],
  },
  {
    'cards': [
      {'id': 'imp', 'name': 'Imp', 'image': 'images/imp.webp'},
    ],
  },
);

/// An expansion of [base] carrying [overlay] after its header.
ModuleData exp(Map<String, dynamic> overlay, [Map<String, List<Map<String, dynamic>>> items = const {}]) => ModuleData({
  'format': 1,
  'id': 'g-x',
  'name': 'G: X',
  'version': '1.0.0',
  'minAppVersion': '3.3.0',
  'expands': {'id': 'g', 'minVersion': '2.1.0'},
  ...overlay,
}, items);

Map<String, dynamic> tab(ModuleData d, String id) =>
    (d.manifest['tabs'] as List).cast<Map<String, dynamic>>().firstWhere((t) => t['id'] == id);

List<Object?> stepIds(ModuleData d) => [for (final s in tab(d, 'round')['block']['children'] as List) s['id']];

ModuleData merged(ModuleData e) {
  final r = mergeExpansion(base(), e);
  expect(r.issues.where((i) => i.fatal), isEmpty, reason: '${r.issues}');
  return r.data;
}

void main() {
  group('mergeExpansion', () {
    test('a new step lands after its anchor; after and before are removed', () {
      final m = merged(
        exp({
          'tabs': [
            {
              'id': 'round',
              'block': {
                'children': [
                  {'type': 'step', 'id': 'mid', 'after': 'one', 'title': 'Mid'},
                  {'type': 'step', 'id': 'zero', 'before': 'one', 'title': 'Zero'},
                ],
              },
            },
          ],
        }),
      );
      expect(stepIds(m), ['zero', 'one', 'mid', 'two']);
      expect(jsonEncode(m.manifest), isNot(contains('"after"')));
      expect(jsonEncode(m.manifest), isNot(contains('"before"')));
    });

    test('an existing step merges: lists append, a title replaces', () {
      final m = merged(
        exp({
          'tabs': [
            {
              'id': 'round',
              'block': {
                'children': [
                  {
                    'id': 'one',
                    'title': 'One, cursed',
                    'how': ['y'],
                    'checklist': [
                      {'id': 'one.b', 'text': 'b'},
                    ],
                  },
                ],
              },
            },
          ],
        }),
      );
      final one = (tab(m, 'round')['block']['children'] as List).first as Map;
      expect(one['title'], 'One, cursed');
      expect(one['type'], 'step');
      expect(one['how'], ['x', 'y']);
      expect([for (final r in one['checklist'] as List) r['id']], ['one.a', 'one.b']);
    });

    test('a lane is placed by its zone: before "hand"', () {
      final m = merged(
        exp({
          'zones': [
            {'id': 'summoner', 'label': 'Summoner', 'accent': 'mint'},
          ],
          'tabs': [
            {
              'id': 'mine',
              'block': {
                'children': [
                  {'type': 'zone', 'zone': 'summoner', 'before': 'hand'},
                ],
              },
            },
          ],
        }),
      );
      expect([for (final z in tab(m, 'mine')['block']['children'] as List) z['zone']], ['summoner', 'hand']);
      expect([for (final z in m.manifest['zones'] as List) z['id']], ['hand', 'summoner']);
    });

    test('a new tab is placed by id; tabs the base has merge', () {
      final m = merged(
        exp({
          'tabs': [
            {
              'id': 'extra',
              'after': 'mine',
              'label': 'Extra',
              'block': {'type': 'text', 'title': 'Extra'},
            },
          ],
        }),
      );
      expect([for (final t in m.manifest['tabs'] as List) t['id']], ['mine', 'extra', 'round']);
    });

    test('an anchor the list does not have is a fatal issue at the element path', () {
      final r = mergeExpansion(
        base(),
        exp({
          'tabs': [
            {
              'id': 'round',
              'block': {
                'children': [
                  {'type': 'step', 'id': 'mid', 'after': 'gone', 'title': 'Mid'},
                ],
              },
            },
          ],
        }),
      );
      final issue = r.issues.singleWhere((i) => i.fatal);
      expect(issue.path, 'tabs[0].block.children[0].after', reason: 'a path in the expansion\'s own module.json');
      expect(issue.message, 'No element "gone" to place this after');
    });

    test('after on an element the base already has is refused', () {
      final r = mergeExpansion(
        base(),
        exp({
          'tabs': [
            {
              'id': 'round',
              'block': {
                'children': [
                  {'id': 'two', 'after': 'one'},
                ],
              },
            },
          ],
        }),
      );
      expect(r.issues.singleWhere((i) => i.fatal).message, '"after" only places new elements; "two" is already there');
    });

    test('after in a list without keys is refused', () {
      final r = mergeExpansion(
        base(),
        exp({
          'collections': {
            'cards': {
              'sheet': {
                'chips': [
                  {'label': 'Curses', 'after': 'x'},
                ],
              },
            },
          },
        }),
      );
      expect(r.issues.singleWhere((i) => i.fatal).message, '"after" needs a list whose elements have ids');
    });

    test('text lists append without duplicates; number lists replace', () {
      final b = base();
      ((b.manifest['tabs'] as List)[1]['block'] as Map)['railRange'] = [0, 12];
      final r = mergeExpansion(
        b,
        exp({
          'tabs': [
            {
              'id': 'round',
              'block': {
                'reminders': ['A.', 'B.'],
                'railRange': [0, 14],
              },
            },
          ],
          'collections': {
            'cards': {
              'sheet': {
                'zones': ['hand', 'soothed'],
              },
            },
          },
        }),
      );
      final round = tab(r.data, 'round')['block'] as Map;
      expect(round['reminders'], ['A.', 'B.']);
      expect(round['railRange'], [0, 14]);
      expect(r.data.manifest['collections']['cards']['sheet']['zones'], ['hand', 'soothed']);
    });

    test('a block of another type replaces the base block', () {
      final m = merged(
        exp({
          'tabs': [
            {
              'id': 'mine',
              'block': {'type': 'text', 'title': 'Gone'},
            },
          ],
        }),
      );
      expect(tab(m, 'mine')['block'], {'type': 'text', 'title': 'Gone'});
    });

    test('items join by id; an equal id replaces the base item with a warning', () {
      final r = mergeExpansion(
        base(),
        exp(
          {
            'collections': {
              'cards': {'items': 'data/cards.json'},
            },
          },
          {
            'cards': [
              {'id': 'imp', 'name': 'Imp (errata)'},
              {'id': 'ares', 'name': 'Ares'},
            ],
          },
        ),
      );
      expect([for (final i in r.data.items['cards']!) i['name']], ['Imp (errata)', 'Ares']);
      final warn = r.issues.single;
      expect(warn.fatal, isFalse);
      expect(warn.path, 'collections.cards');
      expect(warn.message, 'item "imp" replaces the base game\'s item');
      expect(r.data.manifest['collections']['cards']['items'], 'data/cards.json', reason: 'base path kept');
    });

    test('a new collection is added with its items', () {
      final r = mergeExpansion(
        base(),
        exp(
          {
            'collections': {
              'summoners': {'items': 'data/summoners.json', 'backImageField': 'back'},
            },
          },
          {
            'summoners': [
              {'id': 'iwo', 'name': 'Iwo', 'image': 'images/iwo.webp', 'back': 'images/iwo_back.webp'},
            ],
          },
        ),
      );
      expect(r.data.items['summoners']!.single['back'], '@g-x/images/iwo_back.webp');
      expect(r.data.manifest['collections']['summoners']['backImageField'], 'back');
    });

    test('expansion refs are rewritten; https links and empty refs are not', () {
      final r = mergeExpansion(
        base(),
        exp(
          {
            'symbols': {'curse': 'images/curse.webp', 'web': 'https://x.test/w.png'},
            'collections': {
              'cards': {'items': 'data/cards.json'},
            },
            'tabs': [
              {
                'id': 'more',
                'label': 'More',
                'block': {
                  'type': 'hub',
                  'children': [
                    {
                      'type': 'entry',
                      'label': 'E',
                      'image': 'images/e.webp',
                      'block': {'type': 'text'},
                    },
                  ],
                },
              },
            ],
          },
          {
            'cards': [
              {'id': 'ares', 'image': 'images/ares.webp'},
              {'id': 'void', 'image': ''},
            ],
          },
        ),
      );
      final m = r.data.manifest;
      expect(m['symbols'], {
        'fire': 'images/fire.webp',
        'curse': '@g-x/images/curse.webp',
        'web': 'https://x.test/w.png',
      });
      expect([for (final i in r.data.items['cards']!) i['image']], ['images/imp.webp', '@g-x/images/ares.webp', '']);
      expect(tab(r.data, 'more')['block']['children'][0]['image'], '@g-x/images/e.webp');
    });

    test('the header never overlays the base', () {
      final m = merged(exp({'icon': 'images/x.webp', 'source': 'Elsewhere'}));
      expect(m.manifest['name'], 'G');
      expect(m.manifest['version'], '2.1.0');
      expect(m.manifest['minAppVersion'], '3.0.0');
      expect(m.manifest.containsKey('expands'), isFalse);
      expect(m.manifest.containsKey('icon'), isFalse);
      expect(m.manifest.containsKey('source'), isFalse);
    });

    test('a minVersion above the base version is fatal', () {
      final e = exp({});
      e.manifest['expands'] = {'id': 'g', 'minVersion': '2.2.0'};
      final issue = mergeExpansion(base(), e).issues.single;
      expect(issue.path, 'expands.minVersion');
      expect(issue.message, 'Needs G 2.2.0 or newer, 2.1.0 is installed');
    });

    test('inputs are not mutated', () {
      final b = base();
      final e = exp(
        {
          'tabs': [
            {
              'id': 'round',
              'block': {
                'children': [
                  {'type': 'step', 'id': 'mid', 'after': 'one'},
                ],
              },
            },
          ],
        },
        {
          'cards': [
            {'id': 'ares', 'image': 'images/ares.webp'},
          ],
        },
      );
      final before = jsonEncode([b.manifest, b.items, e.manifest, e.items]);
      mergeExpansion(b, e);
      expect(jsonEncode([b.manifest, b.items, e.manifest, e.items]), before);
    });
  });

  group('stackExpansions', () {
    ModuleData named(String id, Map<String, dynamic> overlay) {
      final e = exp(overlay);
      e.manifest['id'] = id;
      return e;
    }

    test('keeps the expansions that merge and rejects one that fails checkModule', () {
      final good = named('g-good', {
        'zones': [
          {'id': 'soothed', 'label': 'Soothed', 'accent': 'violet'},
        ],
      });
      final bad = named('g-bad', {
        'tabs': [
          {
            'id': 'mine',
            'block': {
              'children': [
                {'type': 'zone', 'zone': 'nowhere'},
              ],
            },
          },
        ],
      });
      final r = stackExpansions(base(), [bad, good]);
      expect(r.merged, ['g-good']);
      expect(r.rejected.keys, ['g-bad']);
      expect(r.rejected['g-bad']!.first.message, 'Unknown zone "nowhere"');
      expect(r.manifest.zones.map((z) => z.id), ['hand', 'soothed']);
    });

    test('an expansion for another game is rejected', () {
      final other = exp({});
      other.manifest['expands'] = {'id': 'h'};
      final r = stackExpansions(base(), [other]);
      expect(r.merged, isEmpty);
      expect(r.rejected['g-x']!.single.message, 'This is an expansion for "h", not for "g"');
    });

    test('expansions apply in id order, each on top of the last', () {
      final a = named('g-a', {
        'tabs': [
          {
            'id': 'round',
            'block': {
              'children': [
                {'type': 'step', 'id': 'a', 'after': 'one'},
              ],
            },
          },
        ],
      });
      final b = named('g-b', {
        'tabs': [
          {
            'id': 'round',
            'block': {
              'children': [
                {'type': 'step', 'id': 'b', 'after': 'a'},
              ],
            },
          },
        ],
      });
      final r = stackExpansions(base(), [b, a]);
      expect(r.merged, ['g-a', 'g-b']);
      expect((r.manifest.tabs[1].block as FlowSpec).steps.map((s) => s.id), ['one', 'a', 'b', 'two']);
    });
  });

  group('checkExpansion', () {
    test('a well-formed expansion has no issues', () {
      expect(checkExpansion(exp({})), isEmpty);
    });

    test('expands must name another module', () {
      final e = exp({});
      e.manifest['expands'] = {'id': 'g-x'};
      expect(checkExpansion(e).single.message, 'An expansion cannot expand itself');
      e.manifest['expands'] = 'g';
      expect(
        () => ExpansionRef.of(e.manifest),
        throwsA(isA<SpecFormatException>().having((x) => x.path, 'path', 'expands')),
      );
      expect(checkExpansion(e).single.path, 'expands');
    });

    test('item ids are text and unique within each collection; refs stay inside', () {
      final issues = checkExpansion(
        exp(
          {
            'collections': {
              'cards': {'items': 'data/cards.json'},
            },
          },
          {
            'cards': [
              {'id': 'ares', 'image': '../x.webp'},
              {'id': 'ares'},
              {'name': 'no id'},
            ],
          },
        ),
      );
      expect(
        [for (final i in issues) i.path],
        ['collections.cards[0].image', 'collections.cards[1].id', 'collections.cards[2].id'],
      );
    });

    test('expands.id must be a module id, so it can never name a path', () {
      final e = exp({});
      e.manifest['expands'] = {'id': '../../somewhere'};
      final issue = checkExpansion(e).single;
      expect(issue.path, 'expands.id');
      expect(issue.message, 'Should be a module id (lowercase letters, digits, "-", "_" and "."): "../../somewhere"');
    });

    test('hub entry pictures are checked like other pictures', () {
      final issues = checkExpansion(
        exp({
          'tabs': [
            {
              'id': 'more',
              'label': 'More',
              'block': {
                'type': 'hub',
                'children': [
                  {
                    'type': 'entry',
                    'label': 'E',
                    'image': '../e.webp',
                    'block': {'type': 'text'},
                  },
                ],
              },
            },
          ],
        }),
      );
      expect(issues.single.path, 'tabs[0].block.children[0].image');
    });

    test('a picture field that is not text is an issue, never a crash', () {
      final e = exp(
        {
          'collections': {
            'cards': {'items': 'data/cards.json', 'backImageField': 3},
          },
        },
        {
          'cards': [
            {'id': 'ares'},
          ],
        },
      );
      expect(checkExpansion(e).single.path, 'collections.cards.backImageField');
      expect(() => mergeExpansion(base(), e), returnsNormally);
    });

    test('a newer minAppVersion is refused like any module', () {
      final e = exp({});
      e.manifest['minAppVersion'] = '99.0.0';
      expect(checkExpansion(e).single.message, startsWith(kNeedsNewerApp));
    });
  });

  test('layerRef and splitLayerRef', () {
    expect(layerRef('g-x', 'images/a.webp'), '@g-x/images/a.webp');
    expect(layerRef('g-x', 'https://x.test/a.png'), 'https://x.test/a.png');
    expect(layerRef('g-x', ''), '');
    expect(splitLayerRef('@g-x/images/a.webp'), (layer: 'g-x', path: 'images/a.webp'));
    expect(splitLayerRef('images/a.webp'), isNull);
    expect(splitLayerRef('@no-slash'), isNull);
  });
}
