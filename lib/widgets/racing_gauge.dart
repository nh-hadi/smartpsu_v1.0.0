import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RacingGauge extends StatelessWidget {
  final double value;
  final double maxValue;
  final String label;
  final String unit;
  final Color primaryColor;
  final Color accentColor;
  final double size;

  const RacingGauge({
    super.key,
    required this.value,
    required this.maxValue,
    required this.label,
    this.unit = 'V',
    this.primaryColor = const Color(0xFF00E5FF), // Neon Cyan
    this.accentColor = const Color(0xFFFF1744),  // Racing Red
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      builder: (context, animatedVal, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RacingGaugePainter(
              value: animatedVal,
              maxValue: maxValue,
              primaryColor: primaryColor,
              accentColor: accentColor,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.rajdhani(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white70,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        animatedVal.toStringAsFixed(2),
                        style: GoogleFonts.orbitron(
                          fontSize: size * 0.16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: primaryColor.withOpacity(0.8),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        unit,
                        style: GoogleFonts.orbitron(
                          fontSize: size * 0.09,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
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

class _RacingGaugePainter extends CustomPainter {
  final double value;
  final double maxValue;
  final Color primaryColor;
  final Color accentColor;

  _RacingGaugePainter({
    required this.value,
    required this.maxValue,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    const startAngle = 135 * (math.pi / 180);
    const sweepAngle = 270 * (math.pi / 180);

    // 1. Background Track Arc
    final bgPaint = Paint()
      ..color = const Color(0xFF1E2638)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // 2. Ticks (Speedometer / Tachometer tick marks)
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;

    final redZoneTickPaint = Paint()
      ..color = accentColor.withOpacity(0.7)
      ..strokeWidth = 2;

    const totalTicks = 20;
    for (int i = 0; i <= totalTicks; i++) {
      final angle = startAngle + (i / totalTicks) * sweepAngle;
      final isMajor = i % 5 == 0;
      final isRedZone = i >= totalTicks * 0.8;

      final innerR = radius - (isMajor ? 12 : 7);
      final outerR = radius - 2;

      final p1 = Offset(
        center.dx + innerR * math.cos(angle),
        center.dy + innerR * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + outerR * math.cos(angle),
        center.dy + outerR * math.sin(angle),
      );

      canvas.drawLine(p1, p2, isRedZone ? redZoneTickPaint : tickPaint);
    }

    // 3. Active Value Progress Arc with Neon Gradient
    final clampedRatio = (maxValue > 0 ? (value / maxValue) : 0.0).clamp(0.0, 1.0);
    final activeSweep = sweepAngle * clampedRatio;

    if (activeSweep > 0) {
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          primaryColor,
          const Color(0xFF76FF03), // Lime Green
          const Color(0xFFFFD600), // Amber
          accentColor,             // Neon Red
        ],
        stops: const [0.0, 0.4, 0.75, 1.0],
      );

      final activePaint = Paint()
        ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;

      // Glow effect
      final glowPaint = Paint()
        ..color = primaryColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        glowPaint,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RacingGaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.maxValue != maxValue;
  }
}
