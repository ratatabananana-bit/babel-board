/// The pieces the gallery's three layouts are built from: the flowing cell with its cost
/// ruler, and the grouped layout's section panel and sticky header.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../modules/loaded_module.dart';
import '../item_tile.dart';

/// Flowing layout: the picture is 8 dp narrower than its cell (4 dp a side); rows are 8 dp apart.
const kFlowInset = 8.0;

/// Grouped layout: the padding every section container keeps, picked or not.
const kGroupPad = EdgeInsets.symmetric(vertical: 8, horizontal: 6);

/// One cell of the flowing layout: the cost ruler strip, then the tile with its side
/// insets. The strip's 2 dp line runs the whole cell width so it joins the neighbours of
/// the same section; the first card of a section starts it with a number pill, the last
/// stops it 6 dp early so the next section reads as separate.
class FlowCell extends StatelessWidget {
  const FlowCell({
    super.key,
    required this.item,
    required this.spec,
    required this.collectionId,
    required this.showName,
    required this.label,
    required this.endsRun,
    required this.picked,
  });
  final Item item;
  final CollectionSpec spec;
  final String collectionId;
  final bool showName;

  /// The section's number when this is its first card.
  final String? label;
  final bool endsRun;
  final bool picked;

  static const rulerH = 16.0;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final line = picked ? p.accent : p.muted.withValues(alpha: 0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: rulerH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: label == null ? 0 : kFlowInset / 2,
                right: endsRun ? 6 : 0,
                top: rulerH / 2 - 1,
                height: 2,
                child: ColoredBox(color: line),
              ),
              if (label != null)
                Positioned(
                  left: kFlowInset / 2,
                  top: 0,
                  child: Container(
                    key: Key('cost-pill-$label'),
                    height: rulerH,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: picked ? p.accent : p.surface2,
                      borderRadius: BorderRadius.circular(rulerH / 2),
                    ),
                    child: Text(
                      label!,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: picked ? p.onAccentFill : p.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: kFlowInset / 2),
            child: ItemTile(item: item, collection: spec, collectionId: collectionId, showName: showName),
          ),
        ),
      ],
    );
  }
}

/// A section's cards in the grouped layout: the same padding whether picked or not; picked
/// gets a soft accent fill and an inset outline.
class SectionPanel extends StatelessWidget {
  const SectionPanel({super.key, required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AnimatedContainer(
      duration: context.read<Settings>().anim(const Duration(milliseconds: 200)),
      padding: kGroupPad,
      decoration: BoxDecoration(
        color: active ? p.accent.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? p.accent.withValues(alpha: 0.55) : Colors.transparent, width: 1.5),
      ),
      child: child,
    );
  }
}

/// Sticky separator above a section: label pill, a rule, and the count.
class SectionHeader extends SliverPersistentHeaderDelegate {
  SectionHeader(this.label, this.count, this.p, {this.active = false});
  final String label;
  final String count;
  final Palette p;
  final bool active;

  @override
  double get minExtent => 36;
  @override
  double get maxExtent => 36;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: p.bg,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? p.accent : p.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: active ? p.onAccentFill : p.text2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(height: 1.5, color: active ? p.accent.withValues(alpha: 0.5) : p.surface2),
          ),
          const SizedBox(width: 8),
          Text(count, style: T.caption.copyWith(color: p.muted, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(SectionHeader old) =>
      old.label != label || old.count != count || old.p != p || old.active != active;
}

