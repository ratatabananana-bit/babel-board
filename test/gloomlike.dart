import 'package:vale_helper/modules/loaded_module.dart';

import 'helpers.dart';

/// A Gloomhaven-shaped module built on the mini fixture: 600 ability cards in 17 classes,
/// 37 monster types with 296 ability cards, six zones, a Cards hub (drill-down galleries and
/// an "In play" list linked by `inZone`), a five-lane board, and two flows (Scenario with a
/// cleanup that moves cards back to the pool; Round, cyclic). Text-only cards, no pictures.
Future<LoadedModule> loadGloomlike() => loadMini(
  edit: (m) {
    const classes = 17, monsters = 37;
    m['minAppVersion'] = '3.2.0';
    m['collections'] = {
      'abilities': {
        'items': [
          for (var i = 0; i < 600; i++)
            {
              'id': 'a$i',
              'name': 'Ability $i',
              'class': 'class${i % classes}',
              'level': 1 + i % 9,
              'initiative': 1 + i % 99,
              'effects': [
                {'type': 'top', 'text': 'Attack ${1 + i % 5}'},
                {'type': 'bottom', 'text': 'Move ${1 + i % 4}'},
              ],
            },
        ],
        'sheet': {
          'chips': [
            {'text': 'Level {level}'},
            {'text': 'Initiative {initiative}'},
          ],
          'effects': {
            'path': 'effects',
            'typeLabels': {'top': 'Top', 'bottom': 'Bottom'},
          },
          'zones': ['pool', 'hand', 'discard', 'lost', 'active'],
        },
      },
      'classes': {
        'items': [
          for (var k = 0; k < classes; k++) {'id': 'class$k', 'name': 'Class $k'},
        ],
      },
      'monsters': {
        'items': [
          for (var k = 0; k < monsters; k++) {'id': 'm$k', 'name': 'Monster $k'},
        ],
        'sheet': {
          'zones': ['inplay'],
        },
      },
      'monsterCards': {
        'items': [
          for (var i = 0; i < 296; i++)
            {
              'id': 'mc$i',
              'name': 'Monster card $i',
              'monster': 'm${i % monsters}',
              'initiative': 1 + i % 99,
              'effects': [
                {'type': 'top', 'text': 'Attack +${i % 3}'},
              ],
            },
        ],
        'sheet': {
          'effects': {
            'path': 'effects',
            'typeLabels': {'top': 'Action'},
          },
        },
      },
    };
    m['zones'] = [
      {'id': 'pool', 'label': 'Owned', 'icon': 'cards', 'accent': 'amber'},
      {'id': 'hand', 'label': 'Hand', 'icon': 'hand', 'accent': 'mint'},
      {'id': 'discard', 'label': 'Discarded', 'icon': 'table', 'accent': 'violet'},
      {'id': 'lost', 'label': 'Lost', 'icon': 'star', 'accent': 'amber'},
      {'id': 'active', 'label': 'Active', 'icon': 'flag', 'accent': 'mint'},
      {'id': 'inplay', 'label': 'In play', 'icon': 'run', 'accent': 'violet'},
    ];
    Map<String, Object> lane(String zone) => {
      'type': 'zone',
      'zone': zone,
      'list': {'type': 'cardList', 'collection': 'abilities', 'style': 'mini', 'columns': 2},
    };
    m['tabs'] = [
      {
        'label': 'Cards',
        'icon': 'cards',
        'block': {
          'type': 'hub',
          'title': 'Cards',
          'children': [
            {
              'type': 'entry',
              'label': 'Abilities',
              'summary': '600 ability cards',
              'block': {
                'type': 'gallery',
                'collection': 'abilities',
                'noun': 'cards',
                'search': ['name', 'initiative'],
                'searchKeyboard': 'number',
                'tileSubtitle': '{initiative}',
                'groups': {'path': 'class', 'by': 'classes', 'noun': 'classes'},
                'sections': {
                  'path': 'level',
                  'label': 'LEVEL {value}',
                  'rail': true,
                  'railRange': [1, 9],
                },
              },
            },
            {
              'type': 'entry',
              'label': 'Monsters',
              'summary': '37 monster types',
              'block': {
                'type': 'gallery',
                'collection': 'monsterCards',
                'noun': 'cards',
                'groups': {'path': 'monster', 'by': 'monsters', 'noun': 'monsters'},
              },
            },
            {
              'type': 'entry',
              'label': 'In play',
              'summary': 'Cards of the monsters in this room',
              'block': {
                'type': 'cardList',
                'collection': 'monsterCards',
                'style': 'rows',
                'filter': {
                  'where': [
                    {'path': 'monster', 'inZone': 'inplay'},
                  ],
                },
              },
            },
          ],
        },
      },
      {
        'label': 'My hand',
        'icon': 'hand',
        'badge': 'zoneCount',
        'block': {
          'type': 'board',
          'title': 'My cards',
          'children': [lane('pool'), lane('hand'), lane('discard'), lane('lost'), lane('active')],
        },
      },
      {
        'label': 'Scenario',
        'icon': 'flag',
        'block': {
          'type': 'flow',
          'id': 'scenario',
          'title': 'Scenario',
          'cyclic': false,
          'children': [
            {'type': 'step', 'id': 'sc.setup', 'title': 'Setup', 'summary': 'Lay out the room.'},
            {'type': 'step', 'id': 'sc.play', 'title': 'Play', 'summary': 'Rounds until the goal.'},
            {
              'type': 'step',
              'id': 'sc.cleanup',
              'title': 'Cleanup',
              'summary': 'Pack up.',
              'checklist': [
                {
                  'id': 'sc.return',
                  'text': 'Return your cards to the pool',
                  'action': {
                    'type': 'moveZone',
                    'from': ['hand', 'discard', 'lost', 'active'],
                    'to': 'pool',
                  },
                },
                {
                  'id': 'sc.room',
                  'text': 'Clear the room',
                  'action': {
                    'type': 'clearZones',
                    'zones': ['inplay'],
                  },
                },
              ],
            },
          ],
        },
      },
      {
        'label': 'Round',
        'icon': 'list',
        'block': {
          'type': 'flow',
          'id': 'round',
          'title': 'Round',
          'cyclic': true,
          'children': [
            {'type': 'step', 'id': 'r.pick', 'title': 'Pick cards'},
            {'type': 'step', 'id': 'r.reveal', 'title': 'Reveal'},
            {'type': 'step', 'id': 'r.act', 'title': 'Act'},
            {'type': 'step', 'id': 'r.end', 'title': 'End of round'},
          ],
        },
      },
    ];
  },
);
