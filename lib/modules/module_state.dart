import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which zone each tracked item of a module is in. An item is in at most one zone.
/// Saved as a JSON map under `mod.<moduleId>.zones`, so modules never share state.
///
/// Given the [items] and [zones] the open game has, it sees only entries for those: the
/// cards of an expansion switched off stay saved, untouched, until it is back on (or
/// [forget] drops them, when the expansion is uninstalled).
class ZoneState extends ChangeNotifier {
  ZoneState(this._prefs, this.moduleId, {Set<String>? items, Set<String>? zones}) : _items = items, _known = zones {
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

  /// Insertion order is kept, so newest items appear last in each zone. Holds every saved
  /// entry, seen or not.
  final Map<String, String> _zones = {};

  /// The item and zone ids of the open game; null sees everything.
  final Set<String>? _items, _known;

  bool _sees(String itemId, String zone) =>
      (_items?.contains(itemId) ?? true) && (_known?.contains(zone) ?? true);

  Iterable<MapEntry<String, String>> get _seen => _zones.entries.where((e) => _sees(e.key, e.value));

  String? zoneOf(String itemId) {
    final zone = _zones[itemId];
    return zone != null && _sees(itemId, zone) ? zone : null;
  }

  List<String> idsIn(String zone) => [
    for (final e in _seen)
      if (e.value == zone) e.key,
  ];

  int count(String zone) => _seen.where((e) => e.value == zone).length;

  int get total => _seen.length;

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
      for (final e in _seen)
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
    _zones.removeWhere((id, z) => z == zone && _sees(id, z));
    _save();
  }

  /// New game: every entry goes, seen or not, so nothing stale comes back with an expansion.
  void clearAll() {
    _zones.clear();
    _save();
  }

  /// Drops every entry, seen or not, for one of [items] or in one of [zones]: what an
  /// uninstalled expansion alone provided. Nothing else is touched.
  void forget({Set<String> items = const {}, Set<String> zones = const {}}) {
    final before = _zones.length;
    _zones.removeWhere((id, z) => items.contains(id) || zones.contains(z));
    if (_zones.length != before) _save();
  }

  void _save() {
    _prefs.setString(_key, jsonEncode(_zones));
    notifyListeners();
  }
}
