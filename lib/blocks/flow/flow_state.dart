import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Current step in a game's flow and which checklist items are ticked.
/// Saved under a per-game [prefix] so games never share progress. The current step is
/// saved by id as well as by position, so a step an expansion inserts (or takes away when
/// switched off) does not move a game in progress onto another step.
class FlowState extends ChangeNotifier {
  FlowState(this._prefs, {required this.prefix, required List<String> steps})
    : steps = List.unmodifiable(steps),
      _index = _savedIndex(_prefs, prefix, steps),
      _checked = (_prefs.getStringList('${prefix}phase.checked') ?? []).toSet() {
    // A save from before step ids (index only) is pinned to its step now, while the steps
    // are still the ones it was made with, so an expansion installed later can't shift it.
    if (steps.isNotEmpty && !_prefs.containsKey('${prefix}phase.step')) {
      _prefs.setString('${prefix}phase.step', steps[index]);
    }
  }

  final SharedPreferences _prefs;
  final String prefix;

  /// The flow's step ids, in order.
  final List<String> steps;
  int _index;
  final Set<String> _checked;

  int get phaseCount => steps.isEmpty ? 1 : steps.length;

  static int _savedIndex(SharedPreferences prefs, String prefix, List<String> steps) {
    final at = steps.indexOf(prefs.getString('${prefix}phase.step') ?? '');
    return at >= 0 ? at : prefs.getInt('${prefix}phase.index') ?? 0;
  }

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
    if (steps.isNotEmpty) _prefs.setString('${prefix}phase.step', steps[index]);
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
