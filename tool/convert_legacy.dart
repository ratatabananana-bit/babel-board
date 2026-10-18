// One-off converter: turned the bundled Vale of Eternity and Magical Athlete assets into
// data-only modules under modules/. Kept for the record: its inputs (assets/cards*,
// assets/rules_en.json, assets/symbols/, assets/games/) were removed when the app began
// shipping empty; restore them from git (commit 46b7075) to run it again:
//   dart run tool/convert_legacy.dart
import 'dart:convert';
import 'dart:io';

const _enc = JsonEncoder.withIndent('  ');

void main() {
  convertVale();
  convertMagicalAthlete();
  stdout.writeln('Wrote modules/vale-of-eternity and modules/magical-athlete');
}

Map<String, dynamic> _readJson(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void _writeJson(String path, Object json) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync('${_enc.convert(json)}\n');
}

void _copy(String from, String to) {
  File(to).createSync(recursive: true);
  File(from).copySync(to);
}

/// Today's `rules_en.json` phase → a `step` block. Legacy string actions become typed ones.
Map<String, dynamic> _step(Map<String, dynamic> phase, Map<String, Map<String, dynamic>> actions) {
  Map<String, dynamic> row(Map<String, dynamic> r) {
    final out = <String, dynamic>{'id': r['id'], 'text': r['text']};
    if (r['sub'] != null) out['sub'] = r['sub'];
    if (r['action'] != null) {
      out['action'] = actions[r['action']] ?? (throw StateError('Unknown legacy action ${r['action']}'));
    }
    if (r['actionLabel'] != null) out['actionLabel'] = r['actionLabel'];
    return out;
  }

  return {
    'type': 'step',
    'id': phase['id'],
    'title': phase['title'],
    if (phase['short'] != null) 'short': phase['short'],
    if (phase['tag'] != null) 'tag': phase['tag'],
    'summary': phase['summary'],
    'listTitle': phase['listTitle'] ?? 'Checklist',
    if (phase['nextLabel'] != null) 'nextLabel': phase['nextLabel'],
    if (phase['emptyText'] != null) 'emptyText': phase['emptyText'],
    'how': phase['steps'],
    'checklist': [for (final r in (phase['checklist'] as List)) row((r as Map).cast<String, dynamic>())],
  };
}

Map<String, dynamic> _flow(
  Map<String, dynamic> rules, {
  required String newGameText,
  required Map<String, Map<String, dynamic>> actions,
}) {
  final setup = _step((rules['setup'] as Map).cast<String, dynamic>(), actions)..remove('type');
  return {
    'type': 'flow',
    'title': rules['title'],
    'cyclic': rules['cyclic'] ?? true,
    'reminders': rules['reminders'],
    'newGameText': newGameText,
    'setup': setup,
    'children': [for (final p in (rules['phases'] as List)) _step((p as Map).cast<String, dynamic>(), actions)],
  };
}

void convertVale() {
  const out = 'modules/vale-of-eternity';
  const families = ['fire', 'water', 'earth', 'wind', 'dragon'];
  const familyLabels = {'fire': 'Fire', 'water': 'Water', 'earth': 'Earth', 'wind': 'Wind', 'dragon': 'Dragon'};
  const sellsFor = {
    'fire': ['stone_red', 'stone_red', 'stone_red'],
    'water': ['stone_blue'],
    'earth': ['stone_red', 'stone_red', 'stone_red', 'stone_red'],
    'wind': ['stone_red', 'stone_blue'],
    'dragon': ['stone_purple'],
  };

  final raw = _readJson('assets/cards.json');
  final cards = [for (final c in (raw['cards'] as List)) (c as Map).cast<String, dynamic>()];
  cards.sort((a, b) {
    final f = families.indexOf(a['family'] as String).compareTo(families.indexOf(b['family'] as String));
    if (f != 0) return f;
    final c = (a['cost'] as int).compareTo(b['cost'] as int);
    return c != 0 ? c : (a['name'] as String).compareTo(b['name'] as String);
  });
  final items = <Map<String, dynamic>>[];
  for (final c in cards) {
    final id = c['id'] as String;
    final family = (c['family'] as String).toLowerCase();
    final image = c['image'] as String?;
    String? ref;
    if (image != null && File(image).existsSync()) {
      ref = 'images/cards/$id.webp';
      _copy(image, '$out/$ref');
    }
    items.add({
      'id': id,
      'name': c['name'],
      if (c['nameZh'] != null) 'nameZh': c['nameZh'],
      'family': family,
      'familyLabel': familyLabels[family],
      'cost': c['cost'],
      'sellsFor': sellsFor[family],
      'effects': c['effects'],
      'verified': c['verified'] ?? false,
      'image': ?ref,
    });
  }
  _writeJson('$out/data/cards.json', {'items': items});

  final symbols = <String, String>{};
  for (final f in families) {
    symbols[f] = 'images/symbols/$f.webp';
    _copy('assets/symbols/$f.webp', '$out/images/symbols/$f.webp');
  }
  for (final s in ['red', 'blue', 'purple']) {
    symbols['stone_$s'] = 'images/symbols/stone_$s.webp';
    _copy('assets/symbols/stone_$s.webp', '$out/images/symbols/stone_$s.webp');
  }
  for (final e in ['instant', 'permanent', 'active']) {
    symbols['effect_$e'] = 'images/symbols/$e.webp';
    _copy('assets/symbols/$e.webp', '$out/images/symbols/$e.webp');
  }
  _copy('assets/symbols/dragon.webp', '$out/images/icon.webp');

  final rules = _readJson('assets/rules_en.json');
  final flow = _flow(
    rules,
    newGameText: 'Clears all your tracked cards and goes back to Hunting.',
    actions: {
      'newGame': {'type': 'newGame'},
      'clearTable': {'type': 'clearZone', 'zone': 'table'},
    },
  );
  // Resolution: the Field cards with Active effects are the checklist.
  for (final s in (flow['children'] as List)) {
    if (s['id'] == 'resolution') {
      s['cardChecklist'] = {
        'collection': 'cards',
        'filter': {
          'zone': 'field',
          'where': [
            {'path': 'effects.type', 'has': 'active'},
          ],
        },
        'sub': '{effects[type=active].text}',
      };
    }
  }

  _writeJson('$out/module.json', {
    'format': 1,
    'id': 'vale-of-eternity',
    'name': 'Vale of Eternity',
    'version': '1.0.0',
    'minAppVersion': '3.0.0',
    'icon': 'images/icon.webp',
    'players': '2-4',
    'source': 'Official rulebook (Renegade Game Studios) + valeofeternity.wiki.gg',
    'collections': {
      'cards': {
        'items': 'data/cards.json',
        'titleField': 'name',
        'imageShape': 'card',
        'cardAspect': 300 / 419,
        'sheet': {
          'chips': [
            {'symbol': '{family}', 'text': '{familyLabel}'},
            {'text': 'Cost {cost}'},
            {'label': 'Sells', 'symbols': 'sellsFor'},
          ],
          'effects': {
            'path': 'effects',
            'typeLabels': {'instant': 'Instant', 'permanent': 'Permanent', 'active': 'Active', 'none': 'None'},
            'typeSymbols': {'instant': 'effect_instant', 'permanent': 'effect_permanent', 'active': 'effect_active'},
            'typeHelp': {
              'instant': 'Triggers once, when the card is summoned.',
              'permanent': 'Always active while the card is in your area.',
              'active': 'Use once per round, during the Resolution Phase.',
              'none': 'No effect.',
            },
          },
          'verifiedPath': 'verified',
          'zones': ['table', 'hand', 'field'],
        },
      },
    },
    'symbols': symbols,
    'zones': [
      {'id': 'table', 'label': 'Table', 'icon': 'table', 'accent': 'amber', 'hint': 'Revealed this round'},
      {'id': 'hand', 'label': 'Hand', 'icon': 'hand', 'accent': 'mint', 'hint': 'Taken, not summoned'},
      {'id': 'field', 'label': 'Field', 'icon': 'grid', 'accent': 'violet', 'hint': 'Summoned'},
    ],
    'tabs': [
      {
        'label': 'Cards',
        'icon': 'cards',
        'block': {
          'type': 'gallery',
          'collection': 'cards',
          'search': ['name', 'effects.text'],
          'tileName': true,
          'noun': 'cards',
          'searchHint': 'Search cards',
          'filters': [
            {
              'path': 'family',
              'label': 'Family',
              'position': 'bottom',
              'allLabel': 'All families',
              'options': [
                for (final f in families) {'value': f, 'label': familyLabels[f], 'symbol': f},
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
        },
      },
      {
        'label': 'My cards',
        'icon': 'hand',
        'badge': 'zoneCount',
        'block': {
          'type': 'board',
          'title': 'My cards',
          'countLabel': '{count} tracked',
          'children': [
            for (final z in ['table', 'hand', 'field'])
              {
                'type': 'zone',
                'zone': z,
                'list': {'type': 'cardList', 'collection': 'cards', 'style': 'mini', 'columns': 2},
              },
          ],
        },
      },
      {'label': 'Round', 'icon': 'flag', 'block': flow},
    ],
  });
}

void convertMagicalAthlete() {
  const out = 'modules/magical-athlete';
  final raw = _readJson('assets/games/magical_athlete/racers.json');
  final racers = [for (final r in (raw['racers'] as List)) (r as Map).cast<String, dynamic>()];
  racers.sort((a, b) {
    if (a['number'] != null && b['number'] != null) return (a['number'] as int).compareTo(b['number'] as int);
    return (a['name'] as String).compareTo(b['name'] as String);
  });
  final items = <Map<String, dynamic>>[];
  for (final r in racers) {
    final id = r['id'] as String;
    final image = r['image'] as String?;
    String? ref;
    if (image != null && File(image).existsSync()) {
      ref = 'images/racers/$id.webp';
      _copy(image, '$out/$ref');
    }
    items.add({
      'id': id,
      'name': r['name'],
      if (r['nameZh'] != null) 'nameZh': r['nameZh'],
      if (r['nameZh'] != null) 'nameZhNote': '${r['nameZh']}  (fan translation)',
      if (r['number'] != null) 'number': r['number'],
      if (r['powerName'] != null) 'powerName': r['powerName'],
      'abilities': r['abilities'],
      if (r['notes'] != null) 'notes': r['notes'],
      'verified': r['verified'] ?? false,
      'image': ?ref,
    });
  }
  _writeJson('$out/data/racers.json', {'items': items});
  _copy('assets/games/magical_athlete/racers/hare.webp', '$out/images/icon.webp');

  final rules = _readJson('assets/games/magical_athlete/rules_en.json');
  final flow = _flow(
    rules,
    newGameText: "Clears this race's lineup and goes back to the start.",
    actions: {
      'newGame': {'type': 'newGame'},
      'clearRace': {'type': 'clearZone', 'zone': 'race'},
    },
  );

  _writeJson('$out/module.json', {
    'format': 1,
    'id': 'magical-athlete',
    'name': 'Magical Athlete',
    'version': '1.0.0',
    'minAppVersion': '3.0.0',
    'icon': 'images/icon.webp',
    'players': '2-6',
    'source': 'Magical Athlete rulebook (2025 CMYK edition) + publisher rules updates on BoardGameGeek',
    'collections': {
      'racers': {
        'items': 'data/racers.json',
        'titleField': 'name',
        'subtitleField': 'powerName',
        'imageShape': 'square',
        'cardAspect': 0.716,
        'sheet': {
          'secondary': '{nameZhNote}',
          'sections': [
            {'label': 'Ability', 'path': 'abilities'},
            {'label': 'Rulebook notes', 'path': 'notes'},
          ],
          'verifiedPath': 'verified',
          'zones': ['race'],
        },
      },
    },
    'zones': [
      {
        'id': 'race',
        'label': 'This race',
        'phrase': 'this race',
        'icon': 'race',
        'accent': 'mint',
        'band': 'In race',
        'hint': 'Racers on the track',
      },
    ],
    'tabs': [
      {
        'label': 'Racers',
        'icon': 'cards',
        'block': {
          'type': 'gallery',
          'collection': 'racers',
          'search': ['name', 'nameZh', 'abilities'],
          'tileName': false,
          'noun': 'racers',
        },
      },
      {
        'label': 'This race',
        'icon': 'race',
        'badge': 'zoneCount',
        'block': {
          'type': 'board',
          'title': 'This race',
          'countLabel': '{count} racers',
          'children': [
            {
              'type': 'zone',
              'zone': 'race',
              'list': {
                'type': 'cardList',
                'collection': 'racers',
                'style': 'rows',
                'removable': true,
                'emptyText':
                    'No racers yet.\nIn Racers, tap a racer and choose "Add to this race" for every racer on the track.',
              },
            },
          ],
        },
      },
      {'label': 'Game', 'icon': 'flag', 'block': flow},
    ],
  });
}
