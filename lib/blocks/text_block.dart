import 'package:flutter/material.dart';

import '../core/game_switcher.dart';
import 'symbol_text.dart';
import '../core/theme.dart';
import '../module_format/block_specs.dart';

/// Settings: `{title?, paragraphs?: [String], bullets?: [String]}`.
class TextBlock extends StatelessWidget {
  const TextBlock({super.key, required this.spec});
  final TextSpec spec;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final title = spec.title;
    final paragraphs = spec.paragraphs;
    final bullets = spec.bullets;
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
                if (title != null) Expanded(child: Text(title, style: T.title)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              for (final t in paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SymbolText(t, style: T.body.copyWith(color: p.text)),
                ),
              for (final b in bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
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
                        child: SymbolText(b, style: T.body.copyWith(color: p.text)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
