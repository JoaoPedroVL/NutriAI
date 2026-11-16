import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.value,
    required this.goal,
    this.size = 132,
  });

  final double value;
  final double goal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final isDark = theme.brightness == Brightness.dark;
    final progress = goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: animated,
              track: isDark
                  ? colors.muted.withValues(alpha: 0.28)
                  : colors.greenSoft,
              gradient: [colors.green, colors.greenDark],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: size * 0.23,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: context.colors.ink,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'de ${goal.toStringAsFixed(0)} kcal',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: context.colors.muted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.gradient,
  });

  final double progress;
  final Color track;
  final List<Color> gradient;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    if (progress <= 0) return;

    final foreground = Paint()
      ..shader = SweepGradient(
        colors: gradient,
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, foreground);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.progress != progress;
}
