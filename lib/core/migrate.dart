import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';

/// Before the app held several games, Vale of Eternity saved its state without a prefix.
/// Move those keys under `vale.` once, and reopen Vale so nothing seems to have changed.
Future<void> migrateLegacyPrefs(SharedPreferences p) async {
  const legacyKeys = ['tracker.zones', 'phase.index', 'phase.checked'];
  var moved = false;
  for (final k in legacyKeys) {
    if (!p.containsKey(k)) continue;
    final target = 'vale.$k';
    if (!p.containsKey(target)) {
      switch (p.get(k)) {
        case final String v:
          await p.setString(target, v);
        case final int v:
          await p.setInt(target, v);
        case final List<Object?> v:
          await p.setStringList(target, v.cast<String>());
      }
    }
    await p.remove(k);
    moved = true;
  }
  if (moved && !p.containsKey(AppState.lastGameKey)) {
    await p.setString(AppState.lastGameKey, 'vale');
  }
}
