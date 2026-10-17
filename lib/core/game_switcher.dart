import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'theme.dart';

/// A module's round icon; falls back to its initial on a tinted disc.
class GameIcon extends StatelessWidget {
  const GameIcon(this.game, {super.key, required this.size});
  final OpenGame game;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final img = game.module.files.image(game.module.manifest.icon);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.surface2, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        game.title.isEmpty ? '?' : game.title[0].toUpperCase(),
        style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w800, color: p.text),
      ),
    );
    if (img == null) return fallback;
    return ClipOval(
      child: Image(image: img, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}

/// Round button showing the current game; tap to switch games.
class GameSwitcherButton extends StatelessWidget {
  const GameSwitcherButton({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final game = app.active;
    if (game == null) return const SizedBox.shrink();
    return Tooltip(
      message: 'Switch game',
      child: Semantics(
        button: true,
        label: 'Switch game, now ${game.title}',
        excludeSemantics: true,
        child: InkResponse(
          key: const Key('gameSwitcher'),
          radius: 26,
          onTap: () => showGamePicker(context),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              children: [
                Center(child: GameIcon(game, size: 40)),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(color: context.pal.surface2, shape: BoxShape.circle),
                    child: Icon(Icons.swap_horiz_rounded, size: 13, color: context.pal.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showGamePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text('Switch game', style: T.title),
            ),
            GameList(onPicked: () => Navigator.pop(sheet), showLibrary: true),
          ],
        ),
      ),
    ),
  );
}

/// Every installed game as a big row; the current one is ticked. Optionally ends with a
/// "Library" row that leaves the game screen.
class GameList extends StatelessWidget {
  const GameList({super.key, this.onPicked, this.showLibrary = false});
  final VoidCallback? onPicked;
  final bool showLibrary;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = context.watch<AppState>();
    Widget row({required Widget icon, required String title, required VoidCallback onTap, bool current = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: p.surface2,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    icon,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    if (current) Icon(Icons.check_circle_rounded, color: p.mint),
                  ],
                ),
              ),
            ),
          ),
        );
    return Column(
      children: [
        for (final g in app.games)
          row(
            icon: GameIcon(g, size: 48),
            title: g.title,
            current: app.active?.id == g.id,
            onTap: () {
              app.open(g.id);
              onPicked?.call();
            },
          ),
        if (showLibrary)
          row(
            icon: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
              child: Icon(Icons.apps_rounded, color: p.text),
            ),
            title: 'Library',
            onTap: () {
              app.showLibrary();
              onPicked?.call();
            },
          ),
      ],
    );
  }
}

/// Shown while no game is open. Becomes the Library in a later task.
class GamePickerScreen extends StatelessWidget {
  const GamePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          children: [
            const Text('Which game?', style: T.display),
            const SizedBox(height: 8),
            Text(
              app.games.isEmpty
                  ? 'No games yet.'
                  : 'The app opens straight into the last game you played. Switch any time from the top bar.',
              style: T.body.copyWith(color: context.pal.text2),
            ),
            const SizedBox(height: 24),
            const GameList(),
          ],
        ),
      ),
    );
  }
}
