import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which zone each tracked item of a module is in. An item is in at most one zone.
/// Saved as a JSON map under `mod.<moduleId>.zones`, so modules never share state.
class ZoneState extends ChangeNotifier {
  ZoneState(this._prefs, this.moduleId) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in m.entries) {
          if (e.value is String) _zones[e.key] = e.value as String;
        }
      } on FormatException {
        // Corrupt saved state: start empty rather than crash.
      }
    }
  }

  static String keyFor(String moduleId) => 'mod.$moduleId.zones';

  final SharedPreferences _prefs;
  final String moduleId;
  String get _key => keyFor(moduleId);

  /// Insertion order is kept, so newest items appear last in each zone.
  final Map<String, String> _zones = {};

  String? zoneOf(String itemId) => _zones[itemId];

  List<String> idsIn(String zone) => [
    for (final e in _zones.entries)
      if (e.value == zone) e.key,
  ];

  int count(String zone) => _zones.values.where((z) => z == zone).length;

  int get total => _zones.length;

  /// Puts an item at the end of [zone], or just before [beforeId] if given.
  void put(String itemId, String zone, {String? beforeId}) {
    _zones.remove(itemId);
    if (beforeId == null || beforeId == itemId || !_zones.containsKey(beforeId)) {
      _zones[itemId] = zone;
    } else {
      final entries = _zones.entries.toList();
      _zones.clear();
      for (final e in entries) {
        if (e.key == beforeId) _zones[itemId] = zone;
        _zones[e.key] = e.value;
      }
    }
    _save();
  }

  void remove(String itemId) {
    if (_zones.remove(itemId) != null) _save();
  }

  /// Moves every item in any of [from] to [to], keeping their order (after what [to]
  /// already holds). Nothing moved: nothing saved.
  void moveAll(Iterable<String> from, String to) {
    final set = from.toSet()..remove(to);
    final moving = [
      for (final e in _zones.entries)
        if (set.contains(e.value)) e.key,
    ];
    if (moving.isEmpty) return;
    for (final id in moving) {
      _zones.remove(id);
    }
    for (final id in moving) {
      _zones[id] = to;
    }
    _save();
  }

  void clearZone(String zone) {
    _zones.removeWhere((_, z) => z == zone);
    _save();
  }

  void clearAll() {
    _zones.clear();
    _save();
  }

  void _save() {
    _prefs.setString(_key, jsonEncode(_zones));
    notifyListeners();
  }
}
