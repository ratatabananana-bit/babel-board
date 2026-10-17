import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/app_version.dart';
import 'package:vale_helper/module_format/block_types.dart';
import 'package:vale_helper/module_format/manifest.dart';

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
    expect(kAppVersion, '3.0.0');
    expect(kModuleFormat, 1);
    expect(kBlockTypes, {'gallery', 'board', 'zone', 'cardList', 'flow', 'step', 'text'});
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
    expect(m.tabs[0].block.type, 'board');
    expect(m.tabs[0].block.children[0].type, 'zone');
    expect(m.tabs[0].block.children[0].settings['zone'], 'table');
    expect(m.tabs[0].block.settings.containsKey('children'), isFalse);
    expect(m.tabs[0].block.settings.containsKey('type'), isFalse);
  });

  test('missing id throws a FormatException naming the field', () {
    final j = minimalManifest()..remove('id');
    expect(
      () => ModuleManifest.fromJson(j),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('id'))),
    );
  });
}
