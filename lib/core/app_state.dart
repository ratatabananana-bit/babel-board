import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../blocks/flow/flow_state.dart';
import '../module_format/block_specs.dart';
import '../modules/loaded_module.dart';
import '../modules/module_state.dart';

/// A loaded module together with its saved state.
class OpenGame {
  OpenGame({required this.module, required this.zones, required this.flows});

  /// Builds the state for [module]: zones under `mod.<id>.zones`, and one flow state per
  /// flow (hubs walked). The first flow keeps the keys `mod.<id>.phase.*` a one-flow module
  /// always used; later ones live under `mod.<id>.flow.<flowId>.`.
  factory OpenGame.load(SharedPreferences prefs, LoadedModule module) {
    final id = module.manifest.id;
    final byId = <String, FlowState>{};
    FlowState? first;
    for (final t in module.manifest.tabs) {
      for (final b in walkBlocks(t.block)) {
        if (b case FlowSpec f when !byId.containsKey(f.id)) {
          final prefix = first == null ? 'mod.$id.' : 'mod.$id.flow.${f.id}.';
          final s = FlowState(prefs, prefix: prefix, phaseCount: f.steps.length.clamp(1, 1 << 20));
          byId[f.id] = s;
          first ??= s;
        }
      }
    }
    return OpenGame(module: module, zones: ZoneState(prefs, id), flows: FlowStates(byId, first: first));
  }

  final LoadedModule module;
  final ZoneState zones;
  final FlowStates flows;

  /// The first flow's state (null without a flow); kept for callers that know one flow.
  FlowState? get flow => flows.first;

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
