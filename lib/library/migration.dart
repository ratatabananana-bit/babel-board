import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_state.dart';
import '../modules/module_state.dart';

/// Old game ids (from the app with built-in games) → module ids.
const _legacyIds = {'vale': 'vale-of-eternity', 'ma': 'magical-athlete'};

/// Runs at every startup. Moves the pre-multi-game Vale keys under `vale.` (as before),
/// then maps the remembered last game to its module id. Legacy `vale.*` / `ma.*` state is
/// kept until the matching module is installed (see [adoptLegacyState]).
Future<void> migrateLegacyPrefs(SharedPreferences p) async {
  const oldestKeys = ['tracker.zones', 'phase.index', 'phase.checked'];
  var moved = false;
  for (final k in oldestKeys) {
    if (!p.containsKey(k)) continue;
    final target = 'vale.$k';
    if (!p.containsKey(target)) await _copy(p, k, target);
    await p.remove(k);
    moved = true;
  }
  if (moved && !p.containsKey(AppState.lastGameKey)) {
    await p.setString(AppState.lastGameKey, 'vale');
  }
  final last = p.getString(AppState.lastGameKey);
  final mapped = _legacyIds[last];
  if (mapped != null) await p.setString(AppState.lastGameKey, mapped);
}

/// Called after a module is installed. For the two converted games, moves their legacy
/// saved state into the module's own keys, unless the module already has state, then
/// drops the legacy keys. Safe to call any number of times.
Future<void> adoptLegacyState(SharedPreferences p, String moduleId) async {
  final legacy = _legacyIds.entries.where((e) => e.value == moduleId).firstOrNull?.key;
  if (legacy == null) return;
  final prefix = 'mod.$moduleId.';
  final zonesKey = ZoneState.keyFor(moduleId);
  final hasModuleState = p.getKeys().any((k) => k.startsWith(prefix));

  if (!hasModuleState) {
    if (legacy == 'vale') {
      final raw = p.getString('vale.tracker.zones');
      if (raw != null) await p.setString(zonesKey, raw);
    } else {
      final lineup = p.getStringList('ma.lineup');
      if (lineup != null) await p.setString(zonesKey, jsonEncode({for (final id in lineup) id: 'race'}));
    }
    for (final k in ['phase.index', 'phase.checked']) {
      if (p.containsKey('$legacy.$k')) await _copy(p, '$legacy.$k', '$prefix$k');
    }
  }
  for (final k in p.getKeys().where((k) => k.startsWith('$legacy.')).toList()) {
    await p.remove(k);
  }
}

Future<void> _copy(SharedPreferences p, String from, String to) async {
  switch (p.get(from)) {
    case final String v:
      await p.setString(to, v);
    case final int v:
      await p.setInt(to, v);
    case final bool v:
      await p.setBool(to, v);
    case final double v:
      await p.setDouble(to, v);
    case final List<Object?> v:
      await p.setStringList(to, v.cast<String>());
  }
}
