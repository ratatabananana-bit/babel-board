import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/app_version.dart';
import 'package:vale_helper/module_format/block_specs.dart';
import 'package:vale_helper/module_format/manifest.dart';
import 'package:vale_helper/module_format/spec_json.dart';

/// [minimalManifest] after a JSON round trip, so tests can put any value anywhere.
Map<String, dynamic> looseManifest() => jsonDecode(jsonEncode(minimalManifest())) as Map<String, dynamic>;

Map<String, dynamic> minimalManifest() => {
  'format': 1,
  'id': 'mini',
  'name': 'Mini',
  'version': '1.0.0',
  'minAppVersion': '3.0.0',
  'collections': {
    'items': {'items': 'data/items.json'},
    'extras': {
      'items': [
        {'id': 'x', 'name': 'X'},
      ],
      'titleField': 'name',
    },
  },
  'zones': [
    {'id': 'table', 'label': 'Table', 'icon': 'table', 'accent': 'amber'},
    {'id': 'hand', 'label': 'Hand', 'icon': 'hand', 'accent': 'mint', 'hint': 'Taken'},
  ],
  'tabs': [
    {
      'label': 'My cards',
      'icon': 'hand',
      'badge': 'zoneCount',
      'block': {
        'type': 'board',
        'children': [
          {'type': 'zone', 'zone': 'table'},
        ],
      },
    },
  ],
};

void main() {
  test('app version and format constants', () {
    expect(kAppVersion, '3.3.5');
    expect(kModuleFormat, 1);
    expect(kBlockTypes, {'gallery', 'board', 'zone', 'cardList', 'flow', 'step', 'text', 'hub', 'entry'});
  });

  test('parses a minimal manifest with path and inline collections', () {
    final m = ModuleManifest.fromJson(minimalManifest());
    expect(m.format, 1);
    expect(m.id, 'mini');
    expect(m.name, 'Mini');
    expect(m.version, '1.0.0');
    expect(m.minAppVersion, '3.0.0');
    expect(m.icon, isNull);
    expect(m.collections['items']!.items, 'data/items.json');
    expect(m.collections['items']!.idField, 'id');
    expect(m.collections['items']!.imageField, 'image');
    expect(m.collections['items']!.imageShape, 'card');
    expect(m.collections['items']!.cardAspect, closeTo(0.716, 1e-9));
    expect(m.collections['extras']!.items, isA<List<Map<String, dynamic>>>());
    expect(m.collections['extras']!.titleField, 'name');
    expect(m.zones, hasLength(2));
    expect(m.zones[1].hint, 'Taken');
    expect(m.zones[0].accent, 'amber');
    expect(m.tabs, hasLength(1));
    expect(m.tabs[0].badge, 'zoneCount');
    expect(m.tabs[0].id, isNull);
    expect(m.tabs[0].block.type, 'board');
    final board = m.tabs[0].block as BoardSpec;
    expect(board.title, 'Board');
    expect(board.zones.single.zone, 'table');
    expect(board.zones.single.list, isNull);
  });

  test('a tab may carry an id, the handle an expansion merges into', () {
    final j = looseManifest();
    (j['tabs'] as List)[0]['id'] = 'mine';
    expect(ModuleManifest.fromJson(j).tabs[0].id, 'mine');
  });

  test('every tab block is parsed into its typed spec', () {
    final m = ModuleManifest.fromJson(
      minimalManifest()
        ..['tabs'] = [
          {
            'label': 'Cards',
            'block': {'type': 'gallery', 'collection': 'items', 'noun': 'items'},
          },
          {
            'label': 'Round',
            'block': {
              'type': 'flow',
              'children': [
                {'type': 'step', 'id': 'one', 'title': 'One'},
              ],
            },
          },
          {
            'label': 'Text',
            'block': {
              'type': 'text',
              'paragraphs': ['Hi'],
            },
          },
          {
            'label': 'Lane',
            'block': {'type': 'zone', 'zone': 'hand'},
          },
          {
            'label': 'List',
            'block': {'type': 'cardList', 'collection': 'items', 'style': 'rows'},
          },
        ],
    );
    expect(m.tabs.map((t) => t.block.type), ['gallery', 'flow', 'text', 'zone', 'cardList']);
    expect((m.tabs[0].block as GallerySpec).noun, 'items');
    expect((m.tabs[1].block as FlowSpec).steps.single.title, 'One');
    expect((m.tabs[2].block as TextSpec).paragraphs, ['Hi']);
    expect((m.tabs[3].block as ZoneBlockSpec).zone, 'hand');
    expect((m.tabs[4].block as CardListSpec).style, 'rows');
    expect(m.tabs[0].icon, 'grid');
  });

  test('a collection sheet is parsed once, into a SheetSpec', () {
    final j = minimalManifest();
    (j['collections'] as Map)['items'] = {
      'items': 'data/items.json',
      'sheet': {
        'chips': [
          {'text': 'Cost {cost}'},
        ],
        'zones': ['table'],
      },
    };
    final m = ModuleManifest.fromJson(j);
    expect(m.collections['items']!.sheet.chips.single.text, 'Cost {cost}');
    expect(m.collections['items']!.sheet.zones, ['table']);
    expect(m.collections['extras']!.sheet.chips, isEmpty);
  });

  test('wrong values throw a SpecFormatException at their path', () {
    Matcher at(String path) => throwsA(isA<SpecFormatException>().having((e) => e.path, 'path', path));
    expect(() => ModuleManifest.fromJson(minimalManifest()..['format'] = '1'), at('format'));
    expect(() => ModuleManifest.fromJson(minimalManifest()..['icon'] = 3), at('icon'));
    expect(() => ModuleManifest.fromJson(minimalManifest()..['zones'] = {}), at('zones'));
    expect(() => ModuleManifest.fromJson(minimalManifest()..['zones'] = ['table']), at('zones[0]'));
    expect(() => ModuleManifest.fromJson(minimalManifest()..['symbols'] = {'fire': 1}), at('symbols.fire'));
    final noLabel = minimalManifest();
    ((noLabel['zones'] as List)[1] as Map).remove('label');
    expect(() => ModuleManifest.fromJson(noLabel), at('zones[1].label'));
    final badTab = minimalManifest();
    ((badTab['tabs'] as List)[0] as Map)['block'] = {'type': 'dice'};
    expect(() => ModuleManifest.fromJson(badTab), at('tabs[0].block'));
    final noBlock = minimalManifest();
    ((noBlock['tabs'] as List)[0] as Map).remove('block');
    expect(() => ModuleManifest.fromJson(noBlock), at('tabs[0].block'));
    final badSheet = looseManifest();
    ((badSheet['collections'] as Map)['items'] as Map)['sheet'] = {'zones': 'table'};
    expect(() => ModuleManifest.fromJson(badSheet), at('collections.items.sheet.zones'));
    final badItems = looseManifest();
    ((badItems['collections'] as Map)['items'] as Map)['items'] = 3;
    expect(() => ModuleManifest.fromJson(badItems), at('collections.items.items'));
  });

  test('parse with report lists every broken element and keeps the rest', () {
    final j = looseManifest();
    (j['zones'] as List).add({'id': 'bad'});
    (j['tabs'] as List).add({
      'label': 'Bad',
      'block': {'type': 'gallery'},
    });
    ((j['collections'] as Map)['items'] as Map)['sheet'] = {'chips': 'x'};
    final reported = <String>[];
    final m = ModuleManifest.parse(j, report: (e) => reported.add(e.path));
    expect(reported, ['collections.items.sheet.chips', 'zones[2].label', 'tabs[1].block.collection']);
    expect(m.zones.map((z) => z.id), ['table', 'hand']);
    expect(m.tabs, hasLength(1));
    expect(m.collections['items']!.sheet.chips, isEmpty, reason: 'a broken sheet falls back to empty');
  });

  test('missing id throws a FormatException naming the field', () {
    final j = minimalManifest()..remove('id');
    expect(
      () => ModuleManifest.fromJson(j),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('id'))),
    );
  });
}
