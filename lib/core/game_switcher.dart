import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'game_module.dart';
import 'theme.dart';

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
                Center(child: game.icon(40)),
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
            GameList(onPicked: () => Navigator.pop(sheet)),
          ],
        ),
      ),
    ),
  );
}

/// Every game as a big row; the current one is ticked.
class GameList extends StatelessWidget {
  const GameList({super.key, this.onPicked});
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = context.watch<AppState>();
    return Column(
      children: [
        for (final GameModule g in app.games)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: p.surface2,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  app.open(g.id);
                  onPicked?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      g.icon(48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(g.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      if (app.active?.id == g.id) Icon(Icons.check_circle_rounded, color: p.mint),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// First launch: nothing has been played yet.
class GamePickerScreen extends StatelessWidget {
  const GamePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          children: [
            const Text('Which game?', style: T.display),
            const SizedBox(height: 8),
            Text('The app opens straight into the last game you played. Switch any time from the top bar.',
                style: T.body.copyWith(color: context.pal.text2)),
            const SizedBox(height: 24),
            const GameList(),
          ],
        ),
      ),
    );
  }
}
