import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/game_switcher.dart';
import '../core/theme.dart';
import '../module_format/block_specs.dart';
import '../modules/loaded_module.dart';
import 'icons.dart';
import 'registry.dart';

/// A menu page: one row per entry; tapping pushes the entry's block on its own screen with
/// a back arrow. Lets a game with many sets of cards (abilities, items, monsters, events…)
/// keep a four-button bar. Pushed screens sit under [ModuleScope], so sheets and zones work.
class HubBlock extends StatelessWidget {
  const HubBlock({super.key, required this.spec});
  final HubSpec spec;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Row(
              children: [
                const GameSwitcherButton(),
                const SizedBox(width: 10),
                Expanded(child: Text(spec.title, style: T.title, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            itemCount: spec.entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _HubTile(entry: spec.entries[i]),
          ),
        ),
      ],
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.entry});
  final HubEntrySpec entry;

  static const _leading = 56.0;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final module = context.read<LoadedModule>();
    final img = entry.image == null ? null : module.files.image(entry.image);
    final summary = entry.summary;
    return Semantics(
      button: true,
      label: entry.label,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => HubScreen(entry: entry, moduleId: module.manifest.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: _leading,
                    height: _leading,
                    child: img == null
                        ? ColoredBox(
                            color: p.surface2,
                            child: Icon(moduleIcon(entry.icon), color: p.text, size: 26),
                          )
                        : Image(
                            image: img,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(color: p.surface2),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.label, style: T.body.copyWith(fontWeight: FontWeight.w700, color: p.text)),
                      if (summary != null && summary.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(summary, style: T.caption.copyWith(color: p.text2)),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pushed screen for one hub entry: a back arrow, the entry's label, and its block.
/// Bound to the module it was opened from: when the game changes underneath it (the
/// switcher pops it, but it still builds while sliding away) it draws nothing rather than
/// the old module's cards over the new module's state.
class HubScreen extends StatelessWidget {
  const HubScreen({super.key, required this.entry, required this.moduleId});
  final HubEntrySpec entry;
  final String moduleId;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final module = context.watch<LoadedModule?>();
    if (module == null || module.manifest.id != moduleId) return const SizedBox.shrink();
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        leading: const BackButton(),
        title: Text(entry.label, style: T.title),
      ),
      body: SafeArea(top: false, child: buildBlock(context, entry.block)),
    );
  }
}
