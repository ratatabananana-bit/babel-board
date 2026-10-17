import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/zone.dart';

/// Where each of your cards is. Every card is unique, so a card is in at most one zone.
class Tracker extends ChangeNotifier {
  Tracker(this._prefs, {this.prefix = ''}) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in m.entries) {
        final z = Zone.values.where((z) => z.name == e.value).firstOrNull;
        if (z != null) _zones[e.key] = z;
      }
    }
  }

  /// Saved under `<prefix>tracker.zones`, e.g. `vale.tracker.zones`.
  final String prefix;
  String get _key => '${prefix}tracker.zones';
  final SharedPreferences _prefs;

  /// Insertion order is kept, so newest cards appear last in each zone.
  final Map<String, Zone> _zones = {};

  Zone? zoneOf(String cardId) => _zones[cardId];

  List<String> idsIn(Zone zone) => [
    for (final e in _zones.entries)
      if (e.value == zone) e.key,
  ];

  int count(Zone zone) => _zones.values.where((z) => z == zone).length;

  int get total => _zones.length;

  /// Puts a card at the end of [zone], or just before [beforeId] if given.
  void put(String cardId, Zone zone, {String? beforeId}) {
    _zones.remove(cardId);
    if (beforeId == null || beforeId == cardId || !_zones.containsKey(beforeId)) {
      _zones[cardId] = zone;
    } else {
      final entries = _zones.entries.toList();
      _zones.clear();
      for (final e in entries) {
        if (e.key == beforeId) _zones[cardId] = zone;
        _zones[e.key] = e.value;
      }
    }
    _save();
  }

  void remove(String cardId) {
    if (_zones.remove(cardId) != null) _save();
  }

  void clearZone(Zone zone) {
    _zones.removeWhere((_, z) => z == zone);
    _save();
  }

  void clearAll() {
    _zones.clear();
    _save();
  }

  void _save() {
    _prefs.setString(_key, jsonEncode({for (final e in _zones.entries) e.key: e.value.name}));
    notifyListeners();
  }
}
