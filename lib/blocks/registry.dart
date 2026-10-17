import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../modules/loaded_module.dart';
import '../modules/module_state.dart';
import 'flow/flow_state.dart';
import 'text_block.dart';

typedef BlockBuilder = Widget Function(BuildContext context, BlockSpec spec);

/// Block type → widget. The keys are a subset of `kBlockTypes`; each block file adds its
/// own entry here. Tests may remove an entry to exercise [UnknownBlock].
final Map<String, BlockBuilder> blockRegistry = {
  'text': (context, spec) => TextBlock(spec: spec),
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
  const ModuleScope({
    super.key,
    required this.module,
    required this.zones,
    required this.flow,
    required this.child,
  });

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
