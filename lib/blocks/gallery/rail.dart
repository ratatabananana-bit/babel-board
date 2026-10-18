import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// Jump rail: slim, full height, one fixed position per value of the module's range (or
/// per section present), so a cost is always in the same spot. Values the current filter
/// lacks are dots. Press anywhere and slide to scrub (the grid jumps live and a bubble
/// names the cost; releasing picks it), or tap a number.
///
/// Pills: [picked] is filled in the accent; [active] (what fills the screen while you
/// scroll) has a ring; the rest are muted.
class SectionRail extends StatefulWidget {
  const SectionRail({
    super.key,
    required this.keys,
    required this.range,
    required this.active,
    required this.picked,
    required this.labelOf,
    required this.onPick,
  });
  final List<Object?> keys;
  final List<int>? range;
  final Object? active;
  final Object? picked;

  /// Text of the scrub bubble for a section.
  final String Function(Object? section) labelOf;

  /// [animate] is false while scrubbing so the grid follows the finger instantly.
  final void Function(Object? section, {required bool animate}) onPick;

  @override
  State<SectionRail> createState() => _SectionRailState();
}

class _SectionRailState extends State<SectionRail> {
  static const inset = 6.0;
  static const pill = 22.0;

  /// Finger height while scrubbing (local y), else null.
  double? _scrubY;
  Object? _scrubSection;

  List<Object?> get _slots {
    final r = widget.range;
    if (r != null && r.length == 2 && widget.keys.every((k) => k is int)) {
      return [for (var n = r[0]; n <= r[1]; n++) n];
    }
    return widget.keys;
  }

  Object? _sectionAt(double dy, double height, List<Object?> slots) {
    final keys = widget.keys;
    if (keys.isEmpty || slots.isEmpty) return null;
    final slot = height / slots.length;
    final n = ((dy - inset) / slot).floor().clamp(0, slots.length - 1);
    if (keys.contains(slots[n])) return slots[n];
    // Nearest present section by slot distance.
    Object? best;
    var bestD = 1 << 30;
    for (final k in keys) {
      final d = (slots.indexOf(k) - n).abs();
      if (d < bestD) {
        bestD = d;
        best = k;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final slots = _slots;
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight - inset * 2;
        void scrub(Offset local) {
          final s = _sectionAt(local.dy, h, slots);
          if (s == null) return;
          final changed = s != _scrubSection || _scrubY == null;
          setState(() {
            _scrubY = local.dy.clamp(inset, box.maxHeight - inset);
            _scrubSection = s;
          });
          if (!changed) return;
          if (s != widget.picked) HapticFeedback.selectionClick();
          // Live, no smooth scroll: the grid follows the finger.
          widget.onPick(s, animate: false);
        }

        void release() {
          if (_scrubY != null) setState(() => _scrubY = null);
        }

        final scrubbing = _scrubY != null;
        return GestureDetector(
          key: const Key('sectionRail'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => scrub(d.localPosition),
          onTapUp: (_) => release(),
          onTapCancel: release,
          onVerticalDragStart: (d) => scrub(d.localPosition),
          onVerticalDragUpdate: (d) => scrub(d.localPosition),
          onVerticalDragEnd: (_) => release(),
          onVerticalDragCancel: release,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(vertical: inset),
                decoration: BoxDecoration(
                  color: scrubbing ? p.surface2.withValues(alpha: 0.92) : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  children: [
                    for (final s in slots)
                      Expanded(
                        child: Center(
                          child: widget.keys.contains(s)
                              ? _pill(p, s, picked: s == widget.picked, active: s == widget.active)
                              : Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(color: p.muted.withValues(alpha: 0.6), shape: BoxShape.circle),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              if (scrubbing)
                Positioned(
                  key: const Key('railBubble'),
                  right: box.maxWidth + 8,
                  top: _scrubY! - 22,
                  child: IgnorePointer(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [BoxShadow(blurRadius: 16, offset: Offset(0, 6), color: Colors.black45)],
                      ),
                      child: Text(
                        widget.labelOf(_scrubSection),
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: p.onAccentFill,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _pill(Palette p, Object? s, {required bool picked, required bool active}) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: pill,
    height: pill,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: picked ? p.accent : Colors.transparent,
      shape: BoxShape.circle,
      border: !picked && active ? Border.all(color: p.muted, width: 1.5) : null,
    ),
    child: Text(
      '$s',
      style: TextStyle(
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: picked
            ? p.onAccentFill
            : active
            ? p.text
            : p.muted,
      ),
    ),
  );
}

