import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Turns a card over around its vertical axis: [front] while [showBack] is false, [back]
/// once it is true. Only the face toward the viewer is built. A zero [duration] flips at
/// once (the "Instant" animation speed).
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.showBack,
    this.duration = const Duration(milliseconds: 360),
  });

  final Widget front;
  final Widget back;
  final bool showBack;
  final Duration duration;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final _turn = AnimationController(vsync: this, duration: widget.duration, value: widget.showBack ? 1 : 0);

  @override
  void didUpdateWidget(FlipCard old) {
    super.didUpdateWidget(old);
    _turn.duration = widget.duration;
    if (widget.showBack == old.showBack) return;
    final target = widget.showBack ? 1.0 : 0.0;
    if (widget.duration == Duration.zero) {
      _turn.value = target;
    } else {
      _turn.animateTo(target, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _turn,
    builder: (context, _) {
      final angle = _turn.value * math.pi;
      final backward = angle > math.pi / 2;
      return Transform(
        alignment: Alignment.center,
        // A little perspective, so the turn reads as a card and not a squeeze.
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(angle),
        child: backward
            ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: widget.back)
            : widget.front,
      );
    },
  );
}
