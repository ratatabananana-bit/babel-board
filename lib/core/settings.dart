import 'package:flutter/material.dart' show ThemeMode;
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

  static const _kTheme = 'settings.themeMode';

  /// Light, dark, or follow the phone (the default).
  ThemeMode get themeMode =>
      ThemeMode.values.where((m) => m.name == _prefs.getString(_kTheme)).firstOrNull ?? ThemeMode.system;

  set themeMode(ThemeMode m) {
    if (m == themeMode) return;
    _prefs.setString(_kTheme, m.name);
    notifyListeners();
  }

  static const _kFlowing = 'settings.flowingSections';

  /// Picked a family (or any filter with sections): show one flowing grid with a separator
  /// where each cost starts, instead of a group with a header per cost.
  bool get flowingSections => _prefs.getBool(_kFlowing) ?? false;

  set flowingSections(bool v) {
    if (v == flowingSections) return;
    _prefs.setBool(_kFlowing, v);
    notifyListeners();
  }

  /// The density setting, as cards per row on a phone (4 / 3 / 2).
  int get columns => _columns.clamp(minColumns, maxColumns);

  /// Cards per row for a screen [width] (logical pixels): the phone count on phones, and
  /// proportionally more on wider screens, so a tablet shows 8 / 6 / 4.
  static int columnsFor(int phoneColumns, double width) {
    const phoneWidth = 400.0;
    final scaled = (phoneColumns * width / phoneWidth).floor();
    return scaled < phoneColumns ? phoneColumns : scaled;
  }

  set columns(int v) {
    final c = v.clamp(minColumns, maxColumns);
    if (c == _columns) return;
    _columns = c;
    _prefs.setInt(_kColumns, c);
    notifyListeners();
  }
}
