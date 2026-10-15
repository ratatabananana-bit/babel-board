import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_module.dart';

/// Which game is open. The app always reopens the last game played.
class AppState extends ChangeNotifier {
  AppState(this._prefs, this.games) : _activeId = _prefs.getString(lastGameKey) {
    if (games.every((g) => g.id != _activeId)) _activeId = null;
  }

  static const lastGameKey = 'app.lastGame';

  final SharedPreferences _prefs;
  final List<GameModule> games;
  String? _activeId;

  /// Null until a game has been picked (first launch).
  GameModule? get active => games.where((g) => g.id == _activeId).firstOrNull;

  void open(String id) {
    if (id == _activeId || games.every((g) => g.id != id)) return;
    _activeId = id;
    _prefs.setString(lastGameKey, id);
    notifyListeners();
  }
}
