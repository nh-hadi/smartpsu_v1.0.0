import 'dart:convert';

class PsuTelemetry {
  final double v1; // Voltage CH1 (External)
  final double i1; // Current CH1 (mA)
  final double v2; // Voltage CH2 (StepDown)
  final double i2; // Current CH2 (mA)
  final double v3; // Voltage CH3 (QC 3.0)
  final double i3; // Current CH3 (mA)

  final double dm;  // ADS1115 A1 (D-)
  final double dp;  // ADS1115 A2 (D+)
  final double avo; // ADS1115 A3 (AVO Digital)

  final bool mosfet;
  final bool relay1;
  final bool relay2;

  final DateTime timestamp;

  PsuTelemetry({
    this.v1 = 0.0,
    this.i1 = 0.0,
    this.v2 = 0.0,
    this.i2 = 0.0,
    this.v3 = 0.0,
    this.i3 = 0.0,
    this.dm = 0.0,
    this.dp = 0.0,
    this.avo = 0.0,
    this.mosfet = false,
    this.relay1 = false,
    this.relay2 = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // Watt calculations
  double get p1 => (v1 * (i1 / 1000.0));
  double get p2 => (v2 * (i2 / 1000.0));
  double get p3 => (v3 * (i3 / 1000.0));
  double get totalPower => p1 + p2 + p3;

  factory PsuTelemetry.fromJson(Map<String, dynamic> json) {
    return PsuTelemetry(
      v1: (json['v1'] as num?)?.toDouble() ?? 0.0,
      i1: (json['i1'] as num?)?.toDouble() ?? 0.0,
      v2: (json['v2'] as num?)?.toDouble() ?? 0.0,
      i2: (json['i2'] as num?)?.toDouble() ?? 0.0,
      v3: (json['v3'] as num?)?.toDouble() ?? 0.0,
      i3: (json['i3'] as num?)?.toDouble() ?? 0.0,
      dm: (json['dm'] as num?)?.toDouble() ?? 0.0,
      dp: (json['dp'] as num?)?.toDouble() ?? 0.0,
      avo: (json['avo'] as num?)?.toDouble() ?? 0.0,
      mosfet: (json['m'] == 1 || json['mosfet'] == 1 || json['mosfet'] == true),
      relay1: (json['r1'] == 1 || json['relay1'] == 1 || json['relay1'] == true),
      relay2: (json['r2'] == 1 || json['relay2'] == 1 || json['relay2'] == true),
      timestamp: DateTime.now(),
    );
  }

  static PsuTelemetry? tryParse(String rawData) {
    try {
      final decoded = jsonDecode(rawData);
      if (decoded is Map<String, dynamic>) {
        return PsuTelemetry.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}
