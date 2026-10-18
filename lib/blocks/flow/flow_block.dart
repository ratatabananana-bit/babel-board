import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/game_switcher.dart';
import '../symbol_text.dart';
import '../../core/theme.dart';
import '../../core/widgets/confirm.dart';
import '../../module_format/block_specs.dart';
import '../../module_format/path_expr.dart';
import '../../modules/loaded_module.dart';
import '../../modules/module_state.dart';
import '../item_picture.dart';
import 'flow_state.dart';

/// A row of the parchment checklist: a [ChecklistRow] from module data, or an item row
/// with its picture.
class ChecklistItem {
  const ChecklistItem({required this.id, required this.text, this.sub, this.action, this.actionLabel, this.leading});

  ChecklistItem.of(ChecklistRow r)
    : this(id: r.id, text: r.text, sub: r.sub, action: r.action, actionLabel: r.actionLabel);

  final String id;
  final String text;
  final String? sub;
  final ChecklistAction? action;
  final String? actionLabel;

  /// Optional picture before the text (an item thumbnail).
  final Widget? leading;
}

/// Flow tab: step progress, then the checklist for the current step (parchment, the
/// brightest thing on screen), then "How this step works" folded away.
class FlowBlock extends StatefulWidget {
  const FlowBlock({super.key, required this.spec});
  final FlowSpec spec;

  @override
  State<FlowBlock> createState() => _FlowBlockState();
}

class _FlowBlockState extends State<FlowBlock> {
  /// First tap on Next with open steps arms it; the second tap skips them.
  bool _armed = false;
  bool _howOpen = false;

  void _advance(FlowState state, List<ChecklistItem> items) {
    state.next(items.map((i) => i.id));
    setState(() {
      _armed = false;
      _howOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final flow = widget.spec;
    final state = context.watch<FlowState?>();
    if (state == null || flow.steps.isEmpty) {
      return Center(
        child: Text('This flow has no steps.', style: T.body.copyWith(color: p.text2)),
      );
    }
    final index = state.index.clamp(0, flow.steps.length - 1);
    final step = flow.steps[index];
    final items = stepItems(context, step);
    final done = items.where((i) => state.isChecked(i.id)).length;
    final remaining = items.length - done;
    final isLast = index == flow.steps.length - 1;
    final finished = isLast && !flow.cyclic;
    final nextStep = flow.steps[(index + 1) % flow.steps.length];

    return Provider<FlowSpec>.value(
      value: flow,
      child: Column(
        children: [
          _Header(flow: flow),
          _PhaseBar(
            steps: flow.steps,
            index: index,
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
                      Text(step.title, style: T.display),
                      const SizedBox(height: 6),
                      SymbolText(step.summary, style: T.body.copyWith(fontSize: 16.5, color: p.text2)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ParchmentChecklist(
                  title: step.listTitle,
                  items: items,
                  emptyText: step.emptyText,
                  onToggle: () => setState(() => _armed = false),
                ),
                const SizedBox(height: 18),
                _HowItWorks(steps: step.how, open: _howOpen, onToggle: () => setState(() => _howOpen = !_howOpen)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _NextButton(
              label: step.nextLabel ?? (finished ? 'New game' : 'Next: ${nextStep.title}'),
              remaining: remaining,
              armed: _armed,
              onTap: () {
                if (remaining > 0 && !_armed) {
                  setState(() => _armed = true);
                } else if (finished) {
                  setState(() => _armed = false);
                  confirmNewGame(context, flow.newGameText);
                } else {
                  _advance(state, items);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The rows of a step: its checklist, or the items matching its `cardChecklist`.
List<ChecklistItem> stepItems(BuildContext context, StepSpec step) {
  final cc = step.cardChecklist;
  if (cc == null) return [for (final r in step.checklist) ChecklistItem.of(r)];
  final module = context.read<LoadedModule>();
  final zones = context.watch<ZoneState>();
  final collection = cc.collection;
  final spec = module.manifest.collections[collection];
  if (spec == null) return const [];
  final filter = cc.filter;
  final sub = cc.sub;
  // In zone order when the filter names a zone (what you tracked, in order), else data order.
  final candidates = filter.zone != null
      ? [for (final id in zones.idsIn(filter.zone!)) ?module.item(collection, id)]
      : module.items(collection);
  return [
    for (final it in candidates)
      if (filter.matches(it.data, zones.zoneOf(it.id)))
        ChecklistItem(
          id: 'card.${it.id}',
          text: it.title(spec),
          sub: sub == null ? null : fillTemplate(sub, it.data),
          leading: ItemPicture(it, spec, radius: 6),
        ),
  ];
}

class _Header extends StatelessWidget {
  const _Header({required this.flow});
  final FlowSpec flow;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
        child: Row(
          children: [
            const GameSwitcherButton(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(flow.title, style: T.title, overflow: TextOverflow.ellipsis),
            ),
            if (flow.reminders.isNotEmpty)
              Material(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _showRules(context, flow.reminders),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.menu_book_rounded, size: 20, color: p.text),
                        const SizedBox(width: 6),
                        const Text('Rules', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: Icon(Icons.more_vert_rounded, color: p.text2),
              onSelected: (v) {
                if (v == 'setup' && flow.setup != null) _showSetup(context, flow.setup!);
                if (v == 'new') confirmNewGame(context, flow.newGameText);
              },
              itemBuilder: (_) => [
                if (flow.setup != null) const PopupMenuItem(value: 'setup', child: Text('Setup checklist')),
                PopupMenuItem(
                  value: 'new',
                  child: Text('New game', style: TextStyle(color: p.danger)),
                ),
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
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: p.text2, shape: BoxShape.circle),
                      ),
                    ),
                    Expanded(
                      child: SymbolText(r, style: T.body.copyWith(color: p.text)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSetup(BuildContext context, StepSpec setup) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Provider<FlowSpec>.value(
        value: flow,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(setup.title, style: T.title),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: SymbolText(setup.summary, style: T.body.copyWith(color: context.pal.text2)),
                ),
                const SizedBox(height: 14),
                ParchmentChecklist(
                  title: setup.listTitle,
                  items: [for (final r in setup.checklist) ChecklistItem.of(r)],
                ),
                const SizedBox(height: 14),
                _HowItWorks(steps: setup.how, open: true, onToggle: null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirms, then clears every zone and resets the flow. Returns true if confirmed.
Future<bool> confirmNewGame(BuildContext context, String body) async {
  final ok = await confirm(context, 'Start a new game?', body, 'New game');
  if (ok && context.mounted) {
    context.read<ZoneState>().clearAll();
    context.read<FlowState?>()?.reset();
  }
  return ok;
}

/// Runs a checklist row's action. Returns true when done (the row then ticks).
Future<bool> runChecklistAction(BuildContext context, ChecklistAction action) async {
  switch (action.type) {
    case 'clearZone':
      final zone = action.zone;
      if (zone == null) return false;
      context.read<ZoneState>().clearZone(zone);
      return true;
    case 'newGame':
      final body = context.read<FlowSpec?>()?.newGameText ?? 'Clears everything you tracked and starts over.';
      return confirmNewGame(context, body);
  }
  return false;
}

/// Full-width progress bar; labels wrap instead of being cut off.
class _PhaseBar extends StatelessWidget {
  const _PhaseBar({required this.steps, required this.index, required this.onTap});
  final List<StepSpec> steps;
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
          for (var i = 0; i < steps.length; i++)
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
                            steps[i].short ?? steps[i].title,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.2,
                              color: i == index ? p.text : p.muted,
                              fontWeight: i == index ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                          if (steps[i].tag != null)
                            Text(steps[i].tag!, style: TextStyle(fontSize: 11, height: 1.2, color: p.muted)),
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
class ParchmentChecklist extends StatelessWidget {
  const ParchmentChecklist({super.key, required this.title, required this.items, this.emptyText, this.onToggle});

  final String title;
  final List<ChecklistItem> items;
  final String? emptyText;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FlowState?>();
    final done = items.where((i) => state?.isChecked(i.id) ?? false).length;
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
                    child: Text(
                      title.toUpperCase(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                    ),
                  ),
                  Text(
                    '$done / ${items.length}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
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
            for (final i in items) _ChecklistRowView(item: i, onToggle: onToggle),
          ],
        ),
      ),
    );
  }
}

class _ChecklistRowView extends StatelessWidget {
  const _ChecklistRowView({required this.item, this.onToggle});
  final ChecklistItem item;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FlowState?>();
    final on = state?.isChecked(item.id) ?? false;
    return Semantics(
      checked: on,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: state == null
            ? null
            : () {
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
                if (item.leading != null) ...[SizedBox(width: 40, child: item.leading), const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SymbolText(
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
                        SymbolText(
                          item.sub!,
                          style: const TextStyle(fontSize: 14, height: 1.35, color: Palette.inkMuted),
                        ),
                    ],
                  ),
                ),
                if (item.action != null && !on) ...[const SizedBox(width: 8), _ActionPill(item: item)],
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
  final ChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final label = item.actionLabel ?? (item.action!.type == 'newGame' ? 'New game' : 'Do it');
    return Material(
      color: Palette.ink,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final ok = await runChecklistAction(context, item.action!);
          if (ok && context.mounted) {
            final state = context.read<FlowState?>();
            if (state != null && !state.isChecked(item.id)) state.toggle(item.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Palette.parchment),
          ),
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
    if (steps.isEmpty) return const SizedBox.shrink();
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
                      child: Text(
                        'How this phase works',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                    ),
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
                          child: SymbolText(
                            s,
                            style: TextStyle(fontSize: 15, height: 1.45, color: p.text.withValues(alpha: 0.85)),
                          ),
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

/// Filled (accent) when every step is ticked; otherwise an accent outline with "n steps left".
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
    // Accent, not amber: zone colours mean zones only.
    return Material(
      color: ready ? p.accent : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: p.accent, width: 2)),
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
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ready ? p.onAccentFill : p.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 21, color: ready ? p.onAccentFill : p.text),
                ],
              ),
              if (!ready)
                Text(
                  armed ? 'Tap again to skip them' : '$remaining step${remaining > 1 ? 's' : ''} left',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.text2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
