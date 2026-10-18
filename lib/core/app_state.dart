import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../blocks/flow/flow_state.dart';
import '../module_format/block_specs.dart';
import '../modules/loaded_module.dart';
import '../modules/module_state.dart';

/// A loaded module together with its saved state.
class OpenGame {
  OpenGame({required this.module, required this.zones, required this.flow});

  /// Builds the state for [module]: zones under `mod.<id>.zones`, and a flow state sized
  /// to the first flow tab's steps (null when the module has no flow).
  factory OpenGame.load(SharedPreferences prefs, LoadedModule module) {
    final id = module.manifest.id;
    FlowState? flow;
    for (final t in module.manifest.tabs) {
      if (t.block case FlowSpec f) {
        flow = FlowState(prefs, prefix: 'mod.$id.', phaseCount: f.steps.length.clamp(1, 1 << 20));
        break;
      }
    }
    return OpenGame(module: module, zones: ZoneState(prefs, id), flow: flow);
  }

  final LoadedModule module;
  final ZoneState zones;
  final FlowState? flow;

  String get id => module.manifest.id;
  String get title => module.manifest.name;
}

/// Which game is open. The app always reopens the last game played.
class AppState extends ChangeNotifier {
  AppState(this._prefs, this.games) : _activeId = _prefs.getString(lastGameKey) {
    if (games.every((g) => g.id != _activeId)) _activeId = null;
  }

  static const lastGameKey = 'app.lastGame';

  final SharedPreferences _prefs;
  List<OpenGame> games;
  String? _activeId;

  /// Replaces the installed games (after an install, update or uninstall). The open game
  /// stays open when its id is still present, now backed by the new module.
  void setGames(List<OpenGame> next) {
    games = List.unmodifiable(next);
    if (_activeId != null && games.every((g) => g.id != _activeId)) _activeId = null;
    notifyListeners();
  }

  /// Null while the Library (or first-launch picker) is showing.
  OpenGame? get active => games.where((g) => g.id == _activeId).firstOrNull;

  void open(String id) {
    if (id == _activeId || games.every((g) => g.id != id)) return;
    _activeId = id;
    _prefs.setString(lastGameKey, id);
    notifyListeners();
  }

  /// Leaves the game screen for the Library. The last game stays remembered.
  void showLibrary() {
    if (_activeId == null) return;
    _activeId = null;
    notifyListeners();
  }
}
