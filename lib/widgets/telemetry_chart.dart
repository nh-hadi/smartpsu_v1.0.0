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
    // Calculate statistics
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
        color: const Color(0xFF131318),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.06),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Metric Selector & Utilities Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF08080A).withOpacity(0.6),
              border: const Border(bottom: BorderSide(color: Color(0xFF27272A), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Metric filter buttons
                Row(
                  children: [
                    Text(
                      'METRIC:',
                      style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54),
                    ),
                    const SizedBox(width: 8),
                    _buildMetricButton('ARUS', GraphMetric.arus, const Color(0xFFFF8800)),
                    const SizedBox(width: 4),
                    _buildMetricButton('VOLT', GraphMetric.volt, const Color(0xFFFFDD00)),
                    const SizedBox(width: 4),
                    _buildMetricButton('DAYA', GraphMetric.daya, const Color(0xFFFF3344)),
                    const SizedBox(width: 4),
                    _buildMetricButton('ALL CH', GraphMetric.all, const Color(0xFF00E5FF)),
                  ],
                ),

                // Controls: Range label, Pause, Clear
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                      ),
                      child: Text(
                        _getRangeLabel(),
                        style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF00E5FF)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: onTogglePause,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isPaused ? const Color(0xFFFF8800) : const Color(0xFF27272A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          isPaused ? Icons.play_arrow : Icons.pause,
                          size: 13,
                          color: isPaused ? Colors.black : const Color(0xFF00E5FF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onReset,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27272A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.refresh, size: 13, color: Color(0xFFFF8800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Waveform Canvas with On-Graph Stats Overlay
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
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

                // On-Graph Statistics Overlay (Bottom Right)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF08080A).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF27272A)),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatRow('PEAK', '${peak.toStringAsFixed(3)} $unit', const Color(0xFF00FF66)),
                        _buildStatRow('AVG', '${avg.toStringAsFixed(3)} $unit', const Color(0xFFA1A1AA)),
                        _buildStatRow('MIN', '${min.toStringAsFixed(3)} $unit', const Color(0xFF00E5FF)),
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
    return InkWell(
      onTap: () => onMetricChanged(targetMetric),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [BoxShadow(color: activeColor.withOpacity(0.5), blurRadius: 6)]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.orbitron(
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? (targetMetric == GraphMetric.arus || targetMetric == GraphMetric.volt ? Colors.black : Colors.white) : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
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
      // Arus (in Amperes)
      if (selectedChannel == 1) return t.i1 / 1000.0;
      if (selectedChannel == 2) return t.i2 / 1000.0;
      if (selectedChannel == 3) return t.i3 / 1000.0;
      return 0.0;
    }
  }

  String _getRangeLabel() {
    if (metric == GraphMetric.volt) return 'CH$selectedChannel: 0-30V';
    if (metric == GraphMetric.daya) return 'CH$selectedChannel: 0-50W';
    if (metric == GraphMetric.all) return 'ALL 4 TRACES';
    return 'CH$selectedChannel: 0-5.000A';
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
    // 1. Oscilloscope Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF27272A).withOpacity(0.35)
      ..strokeWidth = 1.0;

    const rows = 4;
    for (int i = 1; i <= rows; i++) {
      final y = size.height * (i / (rows + 1));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    const cols = 8;
    for (int i = 1; i <= cols; i++) {
      final x = size.width * (i / (cols + 1));
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // 2. Horizontal Target Guideline (Dashed effect)
    final guidePaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.3)
      ..strokeWidth = 1.0;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final guideY = size.height * 0.45;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, guideY), Offset(math.min(startX + dashWidth, size.width), guideY), guidePaint);
      startX += dashWidth + dashSpace;
    }

    if (history.length < 2) return;

    // 3. Render Metric Traces
    if (metric == GraphMetric.all) {
      // Draw all channels simultaneously
      _drawTrace(canvas, size, (t) => t.v1, 26.0, const Color(0xFF00E5FF), 'V1');
      _drawTrace(canvas, size, (t) => t.v2, 26.0, const Color(0xFF00FF66), 'V2');
      _drawTrace(canvas, size, (t) => t.v3, 26.0, const Color(0xFFFFDD00), 'V3');
      _drawTrace(canvas, size, (t) => t.avo, 26.0, const Color(0xFFFF3344), 'AVO');
    } else {
      double maxScale = 3.0;
      Color traceColor = const Color(0xFFFF8800);

      if (metric == GraphMetric.volt) {
        maxScale = 25.0;
        traceColor = const Color(0xFFFFDD00);
      } else if (metric == GraphMetric.daya) {
        maxScale = 35.0;
        traceColor = const Color(0xFFFF3344);
      }

      _drawTrace(canvas, size, (t) => _getSingleValue(t), maxScale, traceColor, '', fillArea: true);
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

  void _drawTrace(
    Canvas canvas,
    Size size,
    double Function(PsuTelemetry) extractor,
    double maxScale,
    Color color,
    String label, {
    bool fillArea = false,
  }) {
    final path = Path();
    final points = <Offset>[];
    final stepX = size.width / (math.max(history.length - 1, 1));

    for (int i = 0; i < history.length; i++) {
      final x = i * stepX;
      final val = extractor(history[i]);
      final clamped = val.clamp(0.0, maxScale);
      final y = size.height - (clamped / maxScale) * (size.height - 12) - 6;
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }
    path.lineTo(points.last.dx, points.last.dy);

    // Glowing stroke
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, strokePaint);

    if (fillArea) {
      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(fillPath, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberpunkWaveformPainter oldDelegate) => true;
}
