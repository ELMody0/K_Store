import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:k_store/core/theme/app_theme.dart';

class WavyBackground extends StatefulWidget {
  final Widget child;
  const WavyBackground({super.key, required this.child});

  @override
  State<WavyBackground> createState() => _WavyBackgroundState();
}

class _WavyBackgroundState extends State<WavyBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isDark ? AppColors.pureBlack : AppColors.lightGrey,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _WavyPainter(_controller.value, isDark),
                  );
                },
              ),
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.transparent,
              scaffoldBackgroundColor: Colors.transparent,
            ),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _WavyPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;
  _WavyPainter(this.animationValue, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = isDark ? Colors.white : Colors.black;
    
    final paint1 = Paint()
      ..color = baseColor.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    _drawSeamlessWave(path1, size, animationValue, 0.88, 0.02, 0.8, 0.0);
    canvas.drawPath(path1, paint1);

    final paint2 = Paint()
      ..color = baseColor.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    _drawSeamlessWave(path2, size, animationValue, 0.9, 0.03, 1.0, math.pi / 2);
    canvas.drawPath(path2, paint2);
  }

  void _drawSeamlessWave(Path path, Size size, double anim, double yOffsetFactor, double amplitude, double frequency, double phase) {
    double baseHeight = size.height * yOffsetFactor;
    path.moveTo(0, baseHeight);

    for (double i = 0; i <= size.width; i++) {
      double x = i / size.width;
      double sineValue = math.sin((x * 2 * math.pi * frequency) - (anim * 2 * math.pi) + phase);
      path.lineTo(i, baseHeight + sineValue * (size.height * amplitude));
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
  }

  @override
  bool shouldRepaint(covariant _WavyPainter oldDelegate) => 
      oldDelegate.animationValue != animationValue || oldDelegate.isDark != isDark;
}
