import 'package:flutter/material.dart';

/// كارت تفاعلي: ريبِل عند الضغط + تصغير خفيف (scale) لإحساس فخم.
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Duration duration;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 28,
    this.duration = const Duration(milliseconds: 130),
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  double _scale = 1.0;

  void _down(_) => setState(() => _scale = 0.95);
  void _up(_) {
    setState(() => _scale = 1.0);
    widget.onTap?.call();
  }

  void _cancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: widget.duration,
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(widget.radius),
        child: InkWell(
          onTapDown: _down,
          onTapUp: _up,
          onTapCancel: _cancel,
          child: widget.child,
        ),
      ),
    );
  }
}
