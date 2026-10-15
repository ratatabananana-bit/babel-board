import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The racers on the track in the current race, so their abilities can be read together.
class Lineup extends ChangeNotifier {
  Lineup(this._prefs, {required this.prefix}) : _ids = _prefs.getStringList('${prefix}lineup') ?? [];

  final SharedPreferences _prefs;
  final String prefix;
  final List<String> _ids;

  List<String> get ids => List.unmodifiable(_ids);
  int get count => _ids.length;
  bool contains(String id) => _ids.contains(id);

  void toggle(String id) {
    if (!_ids.remove(id)) _ids.add(id);
    _save();
  }

  void remove(String id) {
    if (_ids.remove(id)) _save();
  }

  void clear() {
    _ids.clear();
    _save();
  }

  void _save() {
    _prefs.setStringList('${prefix}lineup', _ids);
    notifyListeners();
  }
}
