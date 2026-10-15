import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  Settings(this._prefs) : _columns = _prefs.getInt(_kColumns) ?? 4;

  /// Density toggle offers 4 / 3 / 2 cards per row.
  static const columnChoices = [4, 3, 2];
  static const minColumns = 2;
  static const maxColumns = 4;
  static const _kColumns = 'settings.columns';

  final SharedPreferences _prefs;
  int _columns;

  int get columns => _columns.clamp(minColumns, maxColumns);

  set columns(int v) {
    final c = v.clamp(minColumns, maxColumns);
    if (c == _columns) return;
    _columns = c;
    _prefs.setInt(_kColumns, c);
    notifyListeners();
  }
}
