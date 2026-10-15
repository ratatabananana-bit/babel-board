import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Current phase in the round cycle and which checklist items are ticked.
class PhaseState extends ChangeNotifier {
  PhaseState(this._prefs, {required this.phaseCount})
      : _index = _prefs.getInt(_kIndex) ?? 0,
        _checked = (_prefs.getStringList(_kChecked) ?? []).toSet();

  static const _kIndex = 'phase.index';
  static const _kChecked = 'phase.checked';

  final SharedPreferences _prefs;
  final int phaseCount;
  int _index;
  final Set<String> _checked;

  int get index => _index.clamp(0, phaseCount - 1);

  bool isChecked(String itemId) => _checked.contains(itemId);

  void toggle(String itemId) {
    if (!_checked.remove(itemId)) _checked.add(itemId);
    _save();
  }

  /// Moves to the next phase (wrapping to the first) and clears ticks for the phase just left.
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
    _prefs.setInt(_kIndex, _index);
    _prefs.setStringList(_kChecked, _checked.toList());
    notifyListeners();
  }
}
