import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'racing_gauge.dart';

class RacingChannelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double voltage;
  final double currentMa;
  final double maxVoltage;
  final Color themeColor;
  final IconData icon;

  const RacingChannelCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.voltage,
    required this.currentMa,
    this.maxVoltage = 30.0,
    required this.themeColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final double powerWatt = (voltage * (currentMa / 1000.0));
    final double currentAmp = currentMa / 1000.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10141E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeColor.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: -2,
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top accent racing carbon stripe
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            height: 3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    themeColor.withOpacity(0.1),
                    themeColor,
                    themeColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Channel badge & Subtitle)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: themeColor),
                        const SizedBox(width: 6),
                        Text(
                          title,
                          style: GoogleFonts.orbitron(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: themeColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        subtitle.toUpperCase(),
                        style: GoogleFonts.rajdhani(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Center Voltmeter Gauge (Smooth Animated)
                Expanded(
                  child: Center(
                    child: RacingGauge(
                      value: voltage,
                      maxValue: maxVoltage,
                      label: 'VOLTAGE',
                      unit: 'V',
                      primaryColor: themeColor,
                      size: 130,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Bottom Dual Telemetry Box (Current & Power Smooth Animated)
                Row(
                  children: [
                    // CURRENT BOX
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CURRENT',
                              style: GoogleFonts.rajdhani(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 2),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: currentMa, end: currentMa),
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOutCubic,
                              builder: (context, animMa, _) {
                                final animAmp = animMa / 1000.0;
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      animAmp >= 1.0
                                          ? animAmp.toStringAsFixed(2)
                                          : animMa.toStringAsFixed(1),
                                      style: GoogleFonts.orbitron(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF00E676), // Neon Green
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      animAmp >= 1.0 ? 'A' : 'mA',
                                      style: GoogleFonts.orbitron(
                                        fontSize: 9,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // POWER BOX
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'POWER',
                              style: GoogleFonts.rajdhani(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 2),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: powerWatt, end: powerWatt),
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOutCubic,
                              builder: (context, animWatt, _) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      animWatt.toStringAsFixed(2),
                                      style: GoogleFonts.orbitron(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFFFD600), // Neon Yellow/Amber
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'W',
                                      style: GoogleFonts.orbitron(
                                        fontSize: 9,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
