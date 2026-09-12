import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/psu_telemetry.dart';

enum GraphMetric { arus, volt, daya, all }

class CyberpunkTelemetryChart extends StatelessWidget {
  final List<PsuTelemetry> history;
  final int selectedChannel; // 1: CH1, 2: CH2, 3: CH3, 4: AVO
  final GraphMetric metric;
  final bool isPaused;
  final VoidCallback onTogglePause;
  final VoidCallback onReset;
  final ValueChanged<GraphMetric> onMetricChanged;
  final double totalEnergyMwh;

  const CyberpunkTelemetryChart({
    super.key,
    required this.history,
    required this.selectedChannel,
    required this.metric,
    required this.isPaused,
    required this.onTogglePause,
    required this.onReset,
    required this.onMetricChanged,
    required this.totalEnergyMwh,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate live statistics
    double peak = 0.0;
    double min = 9999.0;
    double sum = 0.0;
    int count = 0;

    for (final t in history) {
      double val = _extractValue(t);
      if (val > peak) peak = val;
      if (val < min && val > 0) min = val;
      sum += val;
      count++;
    }
    if (min == 9999.0) min = 0.0;
    final avg = count > 0 ? (sum / count) : 0.0;
    final unit = metric == GraphMetric.volt ? 'V' : (metric == GraphMetric.daya ? 'W' : 'A');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0E13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF3344).withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3344).withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Colors.black87,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP METRIC SELECTOR & TOOLBAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF13141C),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: const Border(
                bottom: BorderSide(color: Color(0xFF1F2330), width: 1.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Metric Pills
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF08080C),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'METRIC',
                        style: GoogleFonts.orbitron(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white60,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildMetricButton('ARUS', GraphMetric.arus, const Color(0xFFFF8800)),
                    const SizedBox(width: 5),
                    _buildMetricButton('VOLT', GraphMetric.volt, const Color(0xFFFFDD00)),
                    const SizedBox(width: 5),
                    _buildMetricButton('DAYA', GraphMetric.daya, const Color(0xFFFF3344)),
                    const SizedBox(width: 5),
                    _buildMetricButton('ALL CH', GraphMetric.all, const Color(0xFF00E5FF)),
                  ],
                ),

                // Controls & Range Display
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF08080C),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFF3344).withOpacity(0.4)),
                      ),
                      child: Text(
                        _getRangeLabel(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF3344),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Pause/Resume Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onTogglePause,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isPaused ? const Color(0xFFFF8800) : const Color(0xFF1B1E2B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isPaused ? const Color(0xFFFF8800) : const Color(0xFF2C3246),
                            ),
                          ),
                          child: Icon(
                            isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                            size: 15,
                            color: isPaused ? Colors.black : const Color(0xFF00E5FF),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Reset Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onReset,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1E2B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF2C3246)),
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            size: 15,
                            color: Color(0xFFFF8800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. OSCILLOSCOPE CANVAS WITH Y-AXIS TICKS & ON-GRAPH STATS OVERLAY
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: CustomPaint(
                      painter: _CyberpunkWaveformPainter(
                        history: history,
                        selectedChannel: selectedChannel,
                        metric: metric,
                      ),
                    ),
                  ),
                ),

                // Floating On-Graph Statistics Overlay (Bottom Right Glass Card)
                Positioned(
                  bottom: 12,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0B10).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2C3246)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black87,
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatRow('PEAK', '${peak.toStringAsFixed(3)} $unit', const Color(0xFF00FF66)),
                        const SizedBox(height: 2),
                        _buildStatRow('AVG', '${avg.toStringAsFixed(3)} $unit', const Color(0xFFA1A1AA)),
                        const SizedBox(height: 2),
                        _buildStatRow('MIN', '${min.toStringAsFixed(3)} $unit', const Color(0xFF00E5FF)),
                        const SizedBox(height: 2),
                        _buildStatRow('ENERGY', '${totalEnergyMwh.toStringAsFixed(1)} mWh', const Color(0xFFFFDD00)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricButton(String label, GraphMetric targetMetric, Color activeColor) {
    final isSelected = metric == targetMetric;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onMetricChanged(targetMetric),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : const Color(0xFF08080C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFF2C3246),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isSelected
                  ? (targetMetric == GraphMetric.arus || targetMetric == GraphMetric.volt ? Colors.black : Colors.white)
                  : Colors.white60,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  double _extractValue(PsuTelemetry t) {
    if (metric == GraphMetric.volt) {
      if (selectedChannel == 1) return t.v1;
      if (selectedChannel == 2) return t.v2;
      if (selectedChannel == 3) return t.v3;
      return t.avo;
    } else if (metric == GraphMetric.daya) {
      if (selectedChannel == 1) return t.p1;
      if (selectedChannel == 2) return t.p2;
      if (selectedChannel == 3) return t.p3;
      return 0.0;
    } else {
      if (selectedChannel == 1) return t.i1 / 1000.0;
      if (selectedChannel == 2) return t.i2 / 1000.0;
      if (selectedChannel == 3) return t.i3 / 1000.0;
      return 0.0;
    }
  }

  String _getRangeLabel() {
    if (metric == GraphMetric.volt) return 'SDP: 0 - 30.0V';
    if (metric == GraphMetric.daya) return 'PWR: 0 - 50.0W';
    if (metric == GraphMetric.all) return 'ALL 4 TRACES';
    return 'SDP: 0 - 3.000A';
  }
}

class _CyberpunkWaveformPainter extends CustomPainter {
  final List<PsuTelemetry> history;
  final int selectedChannel;
  final GraphMetric metric;

  _CyberpunkWaveformPainter({
    required this.history,
    required this.selectedChannel,
    required this.metric,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 38.0;
    const rightMargin = 10.0;
    const topMargin = 14.0;
    const bottomMargin = 14.0;

    final plotWidth = size.width - leftMargin - rightMargin;
    final plotHeight = size.height - topMargin - bottomMargin;

    if (plotWidth <= 0 || plotHeight <= 0) return;

    // Determine Scale Max
    double maxScale = 3.0;
    Color traceColor = const Color(0xFFFF8800);

    if (metric == GraphMetric.volt) {
      maxScale = 25.0;
      traceColor = const Color(0xFFFFDD00);
    } else if (metric == GraphMetric.daya) {
      maxScale = 40.0;
      traceColor = const Color(0xFFFF3344);
    }

    // 1. Draw Background Grid & Y-Axis Labels
    final gridPaint = Paint()
      ..color = const Color(0xFF1A1F2C)
      ..strokeWidth = 0.8;

    const rows = 5;
    for (int i = 0; i <= rows; i++) {
      final y = topMargin + (plotHeight * (i / rows));
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width - rightMargin, y), gridPaint);

      // Y-Axis Tick Text
      final tickVal = maxScale * (1.0 - (i / rows));
      final textSpan = TextSpan(
        text: metric == GraphMetric.volt ? tickVal.toStringAsFixed(0) : tickVal.toStringAsFixed(1),
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 9,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    // Vertical Columns Grid
    const cols = 8;
    for (int i = 0; i <= cols; i++) {
      final x = leftMargin + (plotWidth * (i / cols));
      canvas.drawLine(Offset(x, topMargin), Offset(x, size.height - bottomMargin), gridPaint);
    }

    // 2. Horizontal Reference Guideline (Dashed Red Line at 1.2A / target)
    final guidePaint = Paint()
      ..color = traceColor.withOpacity(0.45)
      ..strokeWidth = 1.0;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final guideY = topMargin + plotHeight * 0.4;
    double startX = leftMargin;
    while (startX < size.width - rightMargin) {
      canvas.drawLine(
        Offset(startX, guideY),
        Offset(math.min(startX + dashWidth, size.width - rightMargin), guideY),
        guidePaint,
      );
      startX += dashWidth + dashSpace;
    }

    if (history.length < 2) return;

    // 3. Draw Metric Traces
    if (metric == GraphMetric.all) {
      _drawSingleTrace(canvas, leftMargin, topMargin, plotWidth, plotHeight, (t) => t.v1, 26.0, const Color(0xFF00E5FF));
      _drawSingleTrace(canvas, leftMargin, topMargin, plotWidth, plotHeight, (t) => t.v2, 26.0, const Color(0xFF00FF66));
      _drawSingleTrace(canvas, leftMargin, topMargin, plotWidth, plotHeight, (t) => t.v3, 26.0, const Color(0xFFFFDD00));
      _drawSingleTrace(canvas, leftMargin, topMargin, plotWidth, plotHeight, (t) => t.avo, 26.0, const Color(0xFFFF3344));
    } else {
      _drawSingleTrace(
        canvas,
        leftMargin,
        topMargin,
        plotWidth,
        plotHeight,
        (t) => _getSingleValue(t),
        maxScale,
        traceColor,
        fillArea: true,
      );
    }
  }

  double _getSingleValue(PsuTelemetry t) {
    if (metric == GraphMetric.volt) {
      if (selectedChannel == 1) return t.v1;
      if (selectedChannel == 2) return t.v2;
      if (selectedChannel == 3) return t.v3;
      return t.avo;
    } else if (metric == GraphMetric.daya) {
      if (selectedChannel == 1) return t.p1;
      if (selectedChannel == 2) return t.p2;
      if (selectedChannel == 3) return t.p3;
      return 0.0;
    } else {
      if (selectedChannel == 1) return t.i1 / 1000.0;
      if (selectedChannel == 2) return t.i2 / 1000.0;
      if (selectedChannel == 3) return t.i3 / 1000.0;
      return 0.0;
    }
  }

  void _drawSingleTrace(
    Canvas canvas,
    double leftMargin,
    double topMargin,
    double plotWidth,
    double plotHeight,
    double Function(PsuTelemetry) extractor,
    double maxScale,
    Color color, {
    bool fillArea = false,
  }) {
    final points = <Offset>[];
    final stepX = plotWidth / math.max(history.length - 1, 1);

    for (int i = 0; i < history.length; i++) {
      final x = leftMargin + (i * stepX);
      final val = extractor(history[i]);
      final clamped = val.clamp(0.0, maxScale);
      final y = topMargin + plotHeight - (clamped / maxScale) * plotHeight;
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }
    path.lineTo(points.last.dx, points.last.dy);

    // Outer Neon Glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Inner Sharp Neon Stroke
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, strokePaint);

    if (fillArea) {
      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, topMargin + plotHeight)
        ..lineTo(points.first.dx, topMargin + plotHeight)
        ..close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.28),
            color.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(leftMargin, topMargin, plotWidth, plotHeight));

      canvas.drawPath(fillPath, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberpunkWaveformPainter oldDelegate) => true;
}
