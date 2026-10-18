import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/module_format/validator.dart';

import 'manifest_test.dart' show minimalManifest;

/// A manifest with every block type in use, so each rule has something to check.
Map<String, dynamic> fullManifest() => fixture();

Map<String, dynamic> fixture() => {
  'format': 1,
  'id': 'mini',
  'name': 'Mini',
  'version': '1.0.0',
  'minAppVersion': '3.0.0',
  'icon': 'images/icon.webp',
  'collections': {
    'items': {'items': 'data/items.json'},
  },
  'symbols': {'fire': 'images/fire.webp'},
  'zones': [
    {'id': 'a', 'label': 'A', 'icon': 'table', 'accent': 'amber'},
    {'id': 'b', 'label': 'B', 'icon': 'hand', 'accent': 'mint'},
  ],
  'tabs': [
    {
      'label': 'Gallery',
      'icon': 'cards',
      'block': {'type': 'gallery', 'collection': 'items'},
    },
    {
      'label': 'Board',
      'icon': 'hand',
      'block': {
        'type': 'board',
        'children': [
          {
            'type': 'zone',
            'zone': 'a',
            'list': {'type': 'cardList', 'collection': 'items', 'style': 'mini'},
          },
          {'type': 'zone', 'zone': 'b'},
        ],
      },
    },
    {
      'label': 'Flow',
      'icon': 'flag',
      'block': {
        'type': 'flow',
        'title': 'Round',
        'children': [
          {
            'type': 'step',
            'id': 's1',
            'title': 'One',
            'summary': 'First.',
            'checklist': [
              {'id': 's1.a', 'text': 'Do a'},
              {
                'id': 's1.clear',
                'text': 'Clear A',
                'action': {'type': 'clearZone', 'zone': 'a'},
              },
            ],
          },
          {
            'type': 'step',
            'id': 's2',
            'title': 'Two',
            'summary': 'Second.',
            'checklist': [
              {
                'id': 's2.new',
                'text': 'New game',
                'action': {'type': 'newGame'},
              },
            ],
          },
        ],
      },
    },
    {
      'label': 'Text',
      'icon': 'book',
      'block': {
        'type': 'text',
        'paragraphs': ['Hello'],
      },
    },
  ],
};

List<Map<String, dynamic>> items() => [
  {'id': 'one', 'name': 'One', 'image': 'images/one.webp'},
  {'id': 'two', 'name': 'Two', 'image': 'https://example.com/two.png'},
  {'id': 'three', 'name': 'Three'},
];

List<ValidationIssue> check(Map<String, dynamic> m, {List<Map<String, dynamic>>? list, String app = '3.0.0'}) =>
    validateModule(m, collections: {'items': list ?? items()}, appVersion: app);

Matcher fatalAt(String path, [Object? message]) => contains(
  isA<ValidationIssue>()
      .having((i) => i.path, 'path', path)
      .having((i) => i.fatal, 'fatal', isTrue)
      .having((i) => i.message, 'message', message ?? anything),
);

void main() {
  test('compareVersions', () {
    expect(compareVersions('3.0.0', '3.0'), 0);
    expect(compareVersions('3.1.0', '3.0.9'), greaterThan(0));
    expect(compareVersions('2.9.9', '3.0.0'), lessThan(0));
  });

  test('the minimal and full fixtures are valid', () {
    expect(validateModule(minimalManifest(), collections: {'items': items()}), isEmpty);
    expect(check(fullManifest()), isEmpty);
  });

  test('missing required field is fatal', () {
    expect(check(fullManifest()..remove('name')), fatalAt('name'));
  });

  test('too-new format needs a newer app', () {
    expect(check(fullManifest()..['format'] = 2), fatalAt('format', contains('needs a newer Babel Board')));
  });

  test('minAppVersion above the app needs a newer app', () {
    expect(
      check(fullManifest()..['minAppVersion'] = '3.1.0'),
      fatalAt('minAppVersion', contains('needs a newer Babel Board')),
    );
    expect(check(fullManifest()..['minAppVersion'] = '3.1.0', app: '3.1.0'), isEmpty);
  });

  test('unknown block type', () {
    final m = fullManifest();
    (m['tabs'] as List)[3]['block'] = {'type': 'dice'};
    expect(check(m), fatalAt('tabs[3].block', "Unknown block 'dice' — this game needs a newer Babel Board"));
  });

  test('gallery needs a collection that exists', () {
    final m = fullManifest();
    (m['tabs'] as List)[0]['block'] = {'type': 'gallery'};
    expect(check(m), fatalAt('tabs[0].block.collection'));
    (m['tabs'] as List)[0]['block'] = {'type': 'gallery', 'collection': 'nope'};
    expect(check(m), fatalAt('tabs[0].block.collection'));
  });

  test('board children must all be zones', () {
    final m = fullManifest();
    ((m['tabs'] as List)[1]['block']['children'] as List)[1] = {'type': 'text'};
    expect(check(m), fatalAt('tabs[1].block.children[1]'));
  });

  test('zone must name a declared zone', () {
    final m = fullManifest();
    ((m['tabs'] as List)[1]['block']['children'] as List)[1] = {'type': 'zone', 'zone': 'zzz'};
    expect(check(m), fatalAt('tabs[1].block.children[1].zone'));
  });

  test('cardList needs a collection', () {
    final m = fullManifest();
    ((m['tabs'] as List)[1]['block']['children'] as List)[0]['list'] = {'type': 'cardList'};
    expect(check(m), fatalAt('tabs[1].block.children[0].list.collection'));
  });

  test('flow needs at least one step and only steps', () {
    final m = fullManifest();
    (m['tabs'] as List)[2]['block']['children'] = [];
    expect(check(m), fatalAt('tabs[2].block.children'));
    (m['tabs'] as List)[2]['block']['children'] = [
      {'type': 'text'},
    ];
    expect(check(m), fatalAt('tabs[2].block.children[0]'));
  });

  test('step ids are unique within a flow', () {
    final m = fullManifest();
    ((m['tabs'] as List)[2]['block']['children'] as List)[1]['id'] = 's1';
    expect(check(m), fatalAt('tabs[2].block.children[1].id'));
  });

  test('checklist actions are clearZone (of a real zone) or newGame', () {
    final m = fullManifest();
    final list = (m['tabs'] as List)[2]['block']['children'][0]['checklist'] as List;
    list[1]['action'] = {'type': 'explode'};
    expect(check(m), fatalAt('tabs[2].block.children[0].checklist[1].action.type'));
    list[1]['action'] = {'type': 'clearZone', 'zone': 'nope'};
    expect(check(m), fatalAt('tabs[2].block.children[0].checklist[1].action.zone'));
  });

  test('item ids are unique per collection', () {
    final dup = [
      ...items(),
      {'id': 'one', 'name': 'Again'},
    ];
    expect(check(fullManifest(), list: dup), fatalAt('collections.items[3].id'));
  });

  test('image refs are https or safe relative paths', () {
    expect(check(fullManifest()..['icon'] = '../x.webp'), fatalAt('icon'));
    expect(check(fullManifest()..['icon'] = '/x.webp'), fatalAt('icon'));
    expect(check(fullManifest()..['icon'] = r'\x.webp'), fatalAt('icon'));
    expect(check(fullManifest()..['icon'] = 'C:/x.webp'), fatalAt('icon'));
    expect(check(fullManifest()..['icon'] = 'http://example.com/x.webp'), fatalAt('icon'));
    expect(check(fullManifest()..['symbols'] = {'fire': 'a/../b.webp'}), fatalAt('symbols.fire'));
    final bad = items()..[0]['image'] = '../../etc/passwd';
    expect(check(fullManifest(), list: bad), fatalAt('collections.items[0].image'));
  });

  test('collection ids are plain names (letters, digits, - and _)', () {
    final m = fullManifest();
    m['collections'] = {
      'items': (m['collections'] as Map)['items'],
      '../x': {'items': <Object>[]},
    };
    expect(check(m), fatalAt('collections.../x'));
  });

  test('zone accent must be amber, mint or violet', () {
    final m = fullManifest();
    (m['zones'] as List)[0]['accent'] = 'red';
    expect(check(m), fatalAt('zones[0].accent'));
  });

  group('review: block settings the app reads are type-checked', () {
    // A JSON round trip gives untyped maps, so tests can put any value anywhere.
    Map<String, dynamic> fullManifest() => jsonDecode(jsonEncode(fixture())) as Map<String, dynamic>;
    Map<String, dynamic> block(Map<String, dynamic> m, int tab) =>
        (m['tabs'] as List)[tab]['block'] as Map<String, dynamic>;
    Map<String, dynamic> step0(Map<String, dynamic> m) => (block(m, 2)['children'] as List)[0] as Map<String, dynamic>;

    test('checklist rows need an id and text', () {
      final m = fullManifest();
      ((step0(m)['checklist'] as List)[0] as Map).remove('id');
      expect(check(m), fatalAt('tabs[2].block.children[0].checklist[0].id'));
      final m2 = fullManifest();
      ((step0(m2)['checklist'] as List)[0] as Map)['text'] = 5;
      expect(check(m2), fatalAt('tabs[2].block.children[0].checklist[0].text'));
    });

    test('checklist ids are unique across the whole flow', () {
      final m = fullManifest();
      ((block(m, 2)['children'] as List)[1]['checklist'] as List)[0]['id'] = 's1.a';
      expect(check(m), fatalAt('tabs[2].block.children[1].checklist[0].id'));
    });

    test('text lists must be lists of text', () {
      final m = fullManifest();
      block(m, 3)['bullets'] = 'one line';
      expect(check(m), fatalAt('tabs[3].block.bullets'));
      final m2 = fullManifest();
      step0(m2)['how'] = [1, 2];
      expect(check(m2), fatalAt('tabs[2].block.children[0].how'));
    });

    test('gallery filters need a path and object options', () {
      final m = fullManifest();
      block(m, 0)['filters'] = [
        {'label': 'Family', 'options': []},
      ];
      expect(check(m), fatalAt('tabs[0].block.filters[0].path'));
      final m2 = fullManifest();
      block(m2, 0)['filters'] = [
        {
          'path': 'family',
          'options': ['fire'],
        },
      ];
      expect(check(m2), fatalAt('tabs[0].block.filters[0].options[0]'));
      final m3 = fullManifest();
      block(m3, 0)['sections'] = {'label': 'x'};
      expect(check(m3), fatalAt('tabs[0].block.sections.path'));
    });

    test('card list style is one of mini, rows, thumbs', () {
      final m = fullManifest();
      ((block(m, 1)['children'] as List)[0]['list'] as Map)['style'] = 'grid';
      expect(check(m), fatalAt('tabs[1].block.children[0].list.style'));
    });

    test('sheet zones name declared zones', () {
      final m = fullManifest();
      (m['collections'] as Map)['items'] = {
        'items': 'data/items.json',
        'sheet': {
          'zones': ['a', 'nope'],
        },
      };
      expect(check(m), fatalAt('collections.items.sheet.zones[1]'));
      final m2 = fullManifest();
      (m2['collections'] as Map)['items'] = {
        'items': 'data/items.json',
        'sheet': {
          'chips': ['Cost'],
        },
      };
      expect(check(m2), fatalAt('collections.items.sheet.chips[0]'));
    });

    test('drag-up details: each section needs a path; labels are text', () {
      final m = fullManifest();
      (m['collections'] as Map)['items'] = {
        'items': 'data/items.json',
        'sheet': {
          'details': {
            'sections': [
              {'label': 'Interactions'},
            ],
          },
        },
      };
      expect(check(m), fatalAt('collections.items.sheet.details.sections[0].path'));
      final m2 = fullManifest();
      (m2['collections'] as Map)['items'] = {
        'items': 'data/items.json',
        'sheet': {
          'details': {
            'sections': [
              {'label': 3, 'path': 'story'},
            ],
          },
        },
      };
      expect(check(m2), fatalAt('collections.items.sheet.details.sections[0].label'));
    });

    test('sheet swipe: left and right name declared zones', () {
      final m = fullManifest();
      (m['collections'] as Map)['items'] = {
        'items': 'data/items.json',
        'sheet': {
          'swipe': {'left': 'a', 'right': 'nope'},
        },
      };
      expect(check(m), fatalAt('collections.items.sheet.swipe.right'));
      final m2 = fullManifest();
      (m2['collections'] as Map)['items'] = {
        'items': 'data/items.json',
        'sheet': {
          'swipe': {'up': 'a'},
        },
      };
      expect(check(m2), fatalAt('collections.items.sheet.swipe.up'));
    });

    test('only one flow per module', () {
      final m = fullManifest();
      (m['tabs'] as List).add({'label': 'Again', 'icon': 'flag', 'block': block(fullManifest(), 2)});
      expect(check(m), fatalAt('tabs[4].block'));
    });

    test('filter rules need a path', () {
      final m = fullManifest();
      ((block(m, 1)['children'] as List)[0]['list'] as Map)['filter'] = {
        'where': [
          {'has': 'x'},
        ],
      };
      expect(check(m), fatalAt('tabs[1].block.children[0].list.filter.where[0].path'));
    });
  });

  test('unverified items are reported once, not fatal', () {
    final list = items()
      ..[0]['verified'] = false
      ..[1]['verified'] = false;
    final issues = check(fullManifest(), list: list);
    expect(issues, hasLength(1));
    expect(issues.single.fatal, isFalse);
    expect(issues.single.path, 'collections.items');
    expect(issues.single.message, contains('2'));
  });
}
