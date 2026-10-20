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

/// Grouped layout: the padding and border every section container keeps, picked or not.
const kGroupPad = EdgeInsets.symmetric(vertical: 6, horizontal: 6);
const kGroupBorder = 1.5;

/// Grouped layout: the sticky header's height.
const kSectionHeaderH = 30.0;

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
    this.subtitle,
    required this.label,
    required this.endsRun,
    required this.picked,
    this.pictureWidth,
  });
  final Item item;

  /// Logical width of the picture, for decoding at tile size.
  final double? pictureWidth;
  final CollectionSpec spec;
  final String collectionId;
  final bool showName;
  final String? subtitle;

  /// The section's number when this is its first card.
  final String? label;
  final bool endsRun;
  final bool picked;

  /// The strip: a 16 dp pill (or line) plus 6 dp of air before the card, so nothing touches.
  static const pillH = 16.0;
  static const rulerH = pillH + 6;

  /// A run ends this far before the cell edge: well inside the card's rounded corner.
  static const tailGap = 14.0;

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
                    height: pillH,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: picked ? p.accent : p.surface2,
                      borderRadius: BorderRadius.circular(pillH / 2),
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
            child: ItemTile(
              item: item,
              collection: spec,
              collectionId: collectionId,
              showName: showName,
              subtitle: subtitle,
              pictureWidth: pictureWidth,
            ),
          ),
        ),
      ],
    );
  }
}

/// A section's cards in the grouped layout: the lower part of the group container (the
/// sticky [SectionHeader] is the upper part). The same padding whether picked or not;
/// picked gets a soft highlight fill and an outline that continues from the header.
/// The group container's lower part: a soft highlight fill and an outline when picked, the
/// bottom corners rounded. Shared by [SectionPanel] and the lazy grouped layout.
BoxDecoration sectionPanelDecoration(Palette p, {required bool active}) {
  final line = BorderSide(color: active ? p.highlight.withValues(alpha: 0.7) : Colors.transparent, width: kGroupBorder);
  return BoxDecoration(
    color: active ? p.highlight.withValues(alpha: 0.14) : null,
    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
    border: Border(left: line, right: line, bottom: line),
  );
}

class SectionPanel extends StatelessWidget {
  const SectionPanel({super.key, required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: context.read<Settings>().anim(const Duration(milliseconds: 200)),
      // Top padding too: a tracked card's corner chip overhangs by 6 dp and must not slide
      // under the pinned header.
      padding: kGroupPad,
      decoration: sectionPanelDecoration(context.pal, active: active),
      child: child,
    );
  }
}

/// Sticky top of a section's container: label pill, a rule, and the count, inset by the
/// group padding so the label lines up with the first card. Opaque, so cards scroll under it.
class SectionHeader extends SliverPersistentHeaderDelegate {
  SectionHeader(this.label, this.count, this.p, {this.active = false});
  final String label;
  final String count;
  final Palette p;
  final bool active;

  @override
  double get minExtent => kSectionHeaderH;
  @override
  double get maxExtent => kSectionHeaderH;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final line = BorderSide(color: active ? p.highlight.withValues(alpha: 0.7) : Colors.transparent, width: kGroupBorder);
    return Container(
      decoration: BoxDecoration(
        color: active ? Color.alphaBlend(p.highlight.withValues(alpha: 0.14), p.bg) : p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(top: line, left: line, right: line),
      ),
      padding: EdgeInsets.symmetric(horizontal: kGroupPad.left),
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

