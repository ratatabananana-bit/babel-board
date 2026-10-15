import 'package:flutter/foundation.dart';

/// Which bottom tab is showing, so pushed pages (card detail) can jump to another tab.
class Nav extends ChangeNotifier {
  static const cards = 0;
  static const myCards = 1;
  static const phase = 2;

  int _tab = cards;
  int get tab => _tab;

  void goTo(int tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }
}
