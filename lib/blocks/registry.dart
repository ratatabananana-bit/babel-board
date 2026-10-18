import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../module_format/block_specs.dart';
import '../modules/loaded_module.dart';
import '../modules/module_state.dart';
import 'board_block.dart';
import 'flow/flow_block.dart';
import 'flow/flow_state.dart';
import 'gallery_block.dart';
import 'text_block.dart';

typedef BlockBuilder = Widget Function(BuildContext context, BlockSpec spec);

/// Block type → widget, keyed by [kBlockTypes] (the parsers' list), so a type the parser
/// knows and this file does not fails loudly at startup. `step` has no widget of its own
/// (it is data for `flow`), so a tab holding one shows [UnknownBlock]. Tests may remove an
/// entry to exercise [UnknownBlock].
final Map<String, BlockBuilder> blockRegistry = {
  for (final t in kBlockTypes)
    t: ?_builderFor(t),
};

BlockBuilder? _builderFor(String type) => switch (type) {
  'text' => (_, s) => TextBlock(spec: s as TextSpec),
  'flow' => (_, s) => FlowBlock(spec: s as FlowSpec),
  'gallery' => (_, s) => GalleryBlock(spec: s as GallerySpec),
  'board' => (_, s) => BoardBlock(spec: s as BoardSpec),
  // A zone on its own is a one-lane board.
  'zone' => (_, s) => BoardBlock(spec: BoardSpec(zones: [s as ZoneBlockSpec])),
  'cardList' => (_, s) => CardListBlock(spec: s as CardListSpec),
  'step' => null,
  _ => throw StateError("No widget for block type '$type'; add it to blockRegistry"),
};

Widget buildBlock(BuildContext context, BlockSpec spec) {
  final b = blockRegistry[spec.type];
  return b == null ? UnknownBlock(type: spec.type) : b(context, spec);
}

/// Shown for a block type this app doesn't know (newer module than app).
class UnknownBlock extends StatelessWidget {
  const UnknownBlock({super.key, required this.type});
  final String type;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        "This game needs a newer Table Helper (unknown block '$type').",
        textAlign: TextAlign.center,
        style: T.body.copyWith(color: context.pal.text2),
      ),
    ),
  );
}

/// Provides the open module and its state to everything below, including sheets and
/// dialogs when placed in `MaterialApp.builder`.
class ModuleScope extends StatelessWidget {
  const ModuleScope({super.key, required this.module, required this.zones, required this.flow, required this.child});

  final LoadedModule module;
  final ZoneState zones;
  final FlowState? flow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final flow = this.flow;
    return MultiProvider(
      providers: [
        Provider<LoadedModule>.value(value: module),
        ChangeNotifierProvider<ZoneState>.value(value: zones),
        if (flow != null) ChangeNotifierProvider<FlowState>.value(value: flow),
      ],
      child: child,
    );
  }
}
