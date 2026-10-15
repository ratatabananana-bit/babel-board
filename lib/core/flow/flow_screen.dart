import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game_switcher.dart';
import '../theme.dart';
import '../widgets/confirm.dart';
import 'flow_rules.dart';
import 'flow_state.dart';

/// One checklist row as shown on the parchment card.
class FlowItem {
  const FlowItem({
    required this.id,
    required this.text,
    this.sub,
    this.action,
    this.actionLabel,
    this.leading,
  });

  FlowItem.fromChecklist(ChecklistItem i)
      : this(id: i.id, text: i.text, sub: i.sub, action: i.action, actionLabel: i.actionLabel);

  final String id;
  final String text;
  final String? sub;

  /// In-app action shown as a pill on the row (e.g. `clearTable`, `newGame`).
  final String? action;
  final String? actionLabel;

  /// Optional picture before the text (e.g. a card thumbnail).
  final Widget? leading;
}

/// What a game plugs into the shared flow screen. Provided with [FlowState] by the game.
class FlowConfig {
  const FlowConfig({
    required this.rules,
    required this.resetGame,
    required this.newGameBody,
    this.itemsFor,
    this.runAction,
  });

  final Rules rules;

  /// Clears the game's own state (tracked cards etc.) for a new game; the flow resets itself.
  final void Function(BuildContext context) resetGame;

  /// Confirm-dialog text for New game, e.g. "Clears all your tracked cards…".
  final String newGameBody;

  /// Replaces a step's checklist with live items (e.g. Vale's Active Field cards).
  /// Return null to use the checklist from the rules file.
  final List<FlowItem>? Function(BuildContext context, PhaseInfo phase)? itemsFor;

  /// Runs a game-specific checklist action; returns true when done (the row then ticks).
  final Future<bool> Function(BuildContext context, String action)? runAction;
}

/// Flow tab: step progress, then the checklist for the current step (parchment, the
/// brightest thing on screen), then "How this step works" folded away.
class FlowScreen extends StatefulWidget {
  const FlowScreen({super.key});

  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> {
  /// First tap on Next with open steps arms it; the second tap skips them.
  bool _armed = false;
  bool _howOpen = false;

  List<FlowItem> _items(FlowConfig config, PhaseInfo phase) =>
      config.itemsFor?.call(context, phase) ??
      [for (final i in phase.checklist) FlowItem.fromChecklist(i)];

  void _advance(FlowState state, List<FlowItem> items) {
    state.next(items.map((i) => i.id));
    setState(() {
      _armed = false;
      _howOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final config = context.read<FlowConfig>();
    final rules = config.rules;
    final state = context.watch<FlowState>();
    final phase = rules.phases[state.index];
    final items = _items(config, phase);
    final done = items.where((i) => state.isChecked(i.id)).length;
    final remaining = items.length - done;
    final isLast = state.index == rules.phases.length - 1;
    final finished = isLast && !rules.cyclic;
    final nextPhase = rules.phases[(state.index + 1) % rules.phases.length];

    return Column(
      children: [
        _Header(config: config),
        _PhaseBar(
          phases: rules.phases,
          index: state.index,
          onTap: (i) {
            state.goTo(i);
            setState(() => _armed = false);
          },
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(phase.title, style: T.display),
                    const SizedBox(height: 6),
                    Text(phase.summary, style: T.body.copyWith(fontSize: 16.5, color: p.text2)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _Checklist(
                title: phase.listTitle,
                items: items,
                emptyText: phase.emptyText,
                onToggle: () => setState(() => _armed = false),
              ),
              const SizedBox(height: 18),
              _HowItWorks(
                steps: phase.steps,
                open: _howOpen,
                onToggle: () => setState(() => _howOpen = !_howOpen),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _NextButton(
            label: phase.nextLabel ?? (finished ? 'New game' : 'Next: ${nextPhase.title}'),
            remaining: remaining,
            armed: _armed,
            onTap: () {
              if (remaining > 0 && !_armed) {
                setState(() => _armed = true);
              } else if (finished) {
                setState(() => _armed = false);
                confirmNewGame(context);
              } else {
                _advance(state, items);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.config});
  final FlowConfig config;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final rules = config.rules;
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
        child: Row(
          children: [
            const GameSwitcherButton(),
            const SizedBox(width: 10),
            Expanded(child: Text(rules.title, style: T.title)),
            Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showRules(context, rules.reminders),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Icon(Icons.menu_book_rounded, size: 20, color: p.text),
                    const SizedBox(width: 6),
                    const Text('Rules', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: Icon(Icons.more_vert_rounded, color: p.text2),
              onSelected: (v) {
                if (v == 'setup') _showSetup(context, rules.setup);
                if (v == 'new') confirmNewGame(context);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'setup', child: Text('Setup checklist')),
                PopupMenuItem(value: 'new', child: Text('New game', style: TextStyle(color: p.danger))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRules(BuildContext context, List<String> reminders) {
    final p = context.pal;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const Text('Key rules', style: T.title),
            const SizedBox(height: 12),
            for (final r in reminders)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 10),
                      child: Container(width: 6, height: 6, decoration: BoxDecoration(color: p.text2, shape: BoxShape.circle)),
                    ),
                    Expanded(child: Text(r, style: T.body.copyWith(color: p.text))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSetup(BuildContext context, PhaseInfo setup) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(left: 4), child: Text('Setup', style: T.title)),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(setup.summary, style: T.body.copyWith(color: context.pal.text2)),
              ),
              const SizedBox(height: 14),
              _Checklist(
                title: setup.listTitle,
                items: [for (final i in setup.checklist) FlowItem.fromChecklist(i)],
              ),
              const SizedBox(height: 14),
              _HowItWorks(steps: setup.steps, open: true, onToggle: null),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirms, then resets the game's state and its flow. Returns true if confirmed.
Future<bool> confirmNewGame(BuildContext context) async {
  final config = context.read<FlowConfig>();
  final ok = await confirm(context, 'Start a new game?', config.newGameBody, 'New game');
  if (ok && context.mounted) {
    config.resetGame(context);
    context.read<FlowState>().reset();
  }
  return ok;
}

/// Full-width progress bar; labels wrap instead of being cut off.
class _PhaseBar extends StatelessWidget {
  const _PhaseBar({required this.phases, required this.index, required this.onTap});
  final List<PhaseInfo> phases;
  final int index;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < phases.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 6,
                            decoration: BoxDecoration(
                              color: i <= index ? p.text : p.line,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            phases[i].short ?? phases[i].title,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.2,
                              color: i == index ? p.text : p.muted,
                              fontWeight: i == index ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                          if (phases[i].tag != null)
                            Text(phases[i].tag!, style: TextStyle(fontSize: 11, height: 1.2, color: p.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The parchment checklist card with a done count and progress bar.
class _Checklist extends StatelessWidget {
  const _Checklist({required this.title, required this.items, this.emptyText, this.onToggle});

  final String title;
  final List<FlowItem> items;
  final String? emptyText;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FlowState>();
    final done = items.where((i) => state.isChecked(i.id)).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(
        color: Palette.parchment,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(blurRadius: 30, offset: Offset(0, 10), color: Color(0x59000000))],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Palette.ink),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const Icon(Icons.checklist_rounded, size: 21, color: Palette.ink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title.toUpperCase(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  ),
                  Text('$done / ${items.length}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: items.isEmpty ? 1 : done / items.length,
                  minHeight: 6,
                  color: Palette.ink,
                  backgroundColor: Palette.ink.withValues(alpha: 0.12),
                ),
              ),
            ),
            if (items.isEmpty && emptyText != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(emptyText!, style: const TextStyle(fontSize: 15, color: Palette.inkMuted)),
              ),
            for (final i in items) _ChecklistRow(item: i, onToggle: onToggle),
          ],
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item, this.onToggle});
  final FlowItem item;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FlowState>();
    final on = state.isChecked(item.id);
    return Semantics(
      checked: on,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          state.toggle(item.id);
          onToggle?.call();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: on ? Palette.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Palette.ink, width: 2.5),
                  ),
                  child: on ? const Icon(Icons.check_rounded, size: 20, color: Palette.parchment) : null,
                ),
                const SizedBox(width: 12),
                if (item.leading != null) ...[
                  SizedBox(width: 40, child: item.leading),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.text,
                        style: TextStyle(
                          fontSize: 16.5,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: on ? Palette.inkDone : Palette.ink,
                          decoration: on ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (item.sub != null)
                        Text(item.sub!,
                            style: const TextStyle(fontSize: 14, height: 1.35, color: Palette.inkMuted)),
                    ],
                  ),
                ),
                if (item.action != null && !on) ...[
                  const SizedBox(width: 8),
                  _ActionPill(item: item),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline app action on a checklist row; doing it also ticks the row.
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.item});
  final FlowItem item;

  @override
  Widget build(BuildContext context) {
    final config = context.read<FlowConfig>();
    final label = item.actionLabel ?? (item.action == 'newGame' ? 'New game' : 'Do it');
    Future<bool> run() async => item.action == 'newGame'
        ? confirmNewGame(context)
        : await config.runAction?.call(context, item.action!) ?? true;
    return Material(
      color: Palette.ink,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final ok = await run();
          if (ok && context.mounted) {
            final state = context.read<FlowState>();
            if (!state.isChecked(item.id)) state.toggle(item.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Palette.parchment)),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.steps, required this.open, required this.onToggle});
  final List<String> steps;
  final bool open;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 21, color: p.text2),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: Text('How this phase works',
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
                    if (onToggle != null)
                      Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: p.text2),
                  ],
                ),
              ),
              if (open)
                Padding(
                  padding: const EdgeInsets.fromLTRB(31, 0, 0, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in steps)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(s, style: TextStyle(fontSize: 15, height: 1.45, color: p.text.withValues(alpha: 0.85))),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filled when every step is ticked; otherwise amber outline with "n steps left".
/// With steps left, the first tap arms it and the second tap skips them.
class _NextButton extends StatelessWidget {
  const _NextButton({required this.label, required this.remaining, required this.armed, required this.onTap});
  final String label;
  final int remaining;
  final bool armed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ready = remaining == 0;
    return Material(
      color: ready ? p.text : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: ready ? p.text : p.warn, width: 2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 60,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ready ? p.bg : p.text)),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 21, color: ready ? p.bg : p.text),
                ],
              ),
              if (!ready)
                Text(
                  armed ? 'Tap again to skip them' : '$remaining step${remaining > 1 ? 's' : ''} left',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.warn),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
