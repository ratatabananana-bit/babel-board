import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Current step in a game's flow and which checklist items are ticked.
/// Saved under a per-game [prefix] so games never share progress.
class FlowState extends ChangeNotifier {
  FlowState(this._prefs, {required this.prefix, required this.phaseCount})
    : _index = _prefs.getInt('${prefix}phase.index') ?? 0,
      _checked = (_prefs.getStringList('${prefix}phase.checked') ?? []).toSet();

  final SharedPreferences _prefs;
  final String prefix;
  final int phaseCount;
  int _index;
  final Set<String> _checked;

  int get index => _index.clamp(0, phaseCount - 1);

  bool isChecked(String itemId) => _checked.contains(itemId);

  void toggle(String itemId) {
    if (!_checked.remove(itemId)) _checked.add(itemId);
    _save();
  }

  /// Moves to the next step (wrapping to the first) and clears ticks for the step just left.
  void next(Iterable<String> leavingItemIds) {
    _checked.removeAll(leavingItemIds);
    _index = (index + 1) % phaseCount;
    _save();
  }

  void goTo(int i) {
    _index = i.clamp(0, phaseCount - 1);
    _save();
  }

  void reset() {
    _index = 0;
    _checked.clear();
    _save();
  }

  void _save() {
    _prefs.setInt('${prefix}phase.index', _index);
    _prefs.setStringList('${prefix}phase.checked', _checked.toList());
    notifyListeners();
  }
}

/// Every flow of a module with its saved progress, by flow id. The first flow in tab order
/// keeps the keys a one-flow module always used, so an update never loses a game's place.
class FlowStates {
  FlowStates(this.byId, {this.first});

  final Map<String, FlowState> byId;

  /// The first flow in tab order (hubs walked), null when the module has no flow.
  final FlowState? first;

  FlowState? operator [](String id) => byId[id];

  /// New game: every tracker back to its first step.
  void resetAll() {
    for (final s in byId.values) {
      s.reset();
    }
  }
}
