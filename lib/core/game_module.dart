import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One bottom tab of a game.
class GameTab {
  const GameTab({required this.label, required this.icon, required this.builder, this.badge});

  final String label;
  final IconData icon;
  final WidgetBuilder builder;

  /// Live count for the tab's badge (e.g. tracked cards); null or 0 hides it.
  final int Function(BuildContext context)? badge;
}

/// A board game the app supports. Each game owns its data, saved state and tabs.
abstract class GameModule {
  /// Stable id, also the prefix for its saved state (`<id>.`) and its launcher shortcut.
  String get id;
  String get title;

  /// Small round picture for the game switcher.
  Widget icon(double size);

  /// Loads bundled data and restores saved state. Called once at startup.
  Future<void> load(AssetBundle bundle, SharedPreferences prefs);

  List<GameTab> get tabs;

  /// Wraps the app (above the Navigator) with this game's providers while it is active,
  /// so sheets and dialogs can read them too.
  Widget wrap(Widget child);
}
