import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/module_format/validator.dart';

import 'manifest_test.dart' show minimalManifest;

/// A manifest with every block type in use, so each rule has something to check.
Map<String, dynamic> fullManifest() => {
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

Matcher fatalAt(String path, [Object? message]) => contains(isA<ValidationIssue>()
    .having((i) => i.path, 'path', path)
    .having((i) => i.fatal, 'fatal', isTrue)
    .having((i) => i.message, 'message', message ?? anything));

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
    expect(check(fullManifest()..['format'] = 2), fatalAt('format', contains('needs a newer Table Helper')));
  });

  test('minAppVersion above the app needs a newer app', () {
    expect(check(fullManifest()..['minAppVersion'] = '3.1.0'),
        fatalAt('minAppVersion', contains('needs a newer Table Helper')));
    expect(check(fullManifest()..['minAppVersion'] = '3.1.0', app: '3.1.0'), isEmpty);
  });

  test('unknown block type', () {
    final m = fullManifest();
    (m['tabs'] as List)[3]['block'] = {'type': 'dice'};
    expect(check(m), fatalAt('tabs[3].block', "Unknown block 'dice' — this game needs a newer Table Helper"));
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
    final dup = [...items(), {'id': 'one', 'name': 'Again'}];
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

  test('zone accent must be amber, mint or violet', () {
    final m = fullManifest();
    (m['zones'] as List)[0]['accent'] = 'red';
    expect(check(m), fatalAt('zones[0].accent'));
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
