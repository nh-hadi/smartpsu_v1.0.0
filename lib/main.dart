import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/psu_telemetry.dart';
import 'services/udp_service.dart';
import 'widgets/telemetry_chart.dart';
import 'widgets/ota_dialog.dart';
import 'widgets/test_connection_dialog.dart';
import 'widgets/ip_settings_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Hide system status bar and bottom navigation bar for true immersive fullscreen on Android
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Lock landscape orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const SmartPsuCyberpunkApp());
}

class SmartPsuCyberpunkApp extends StatelessWidget {
  const SmartPsuCyberpunkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMART PSU v1.0.0 PRO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF08080C),
        primaryColor: const Color(0xFF00E5FF),
        textTheme: GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme),
      ),
      home: const CyberpunkDashboardScreen(),
    );
  }
}

class CyberpunkDashboardScreen extends StatefulWidget {
  const CyberpunkDashboardScreen({super.key});

  @override
  State<CyberpunkDashboardScreen> createState() => _CyberpunkDashboardScreenState();
}

class _CyberpunkDashboardScreenState extends State<CyberpunkDashboardScreen> with SingleTickerProviderStateMixin {
  final UdpService _udpService = UdpService();
  final TextEditingController _terminalController = TextEditingController();

  int _selectedChannel = 1; // 1: CH1, 2: CH2, 3: CH3, 4: AVO
  GraphMetric _graphMetric = GraphMetric.arus;
  String _currentMode = 'PSU'; // 'PSU', 'USB', 'PROBE', 'WAVE', 'TERMINAL'
  bool _isAnalyzing = true;
  bool _isChartPaused = false;

  @override
  void initState() {
    super.initState();
    _udpService.startListening();
  }

  @override
  void dispose() {
    _udpService.dispose();
    _terminalController.dispose();
    super.dispose();
  }

  void _showOtaDialog() {
    showDialog(
      context: context,
      builder: (context) => OtaDialog(currentIp: _udpService.espIp),
    );
  }

  void _showTestDialog() {
    showDialog(
      context: context,
      builder: (context) => TestConnectionDialog(udpService: _udpService),
    );
  }

  void _showIpDialog() {
    showDialog(
      context: context,
      builder: (context) => IpSettingsDialog(udpService: _udpService),
    );
  }

  void _switchMode(String mode) {
    setState(() {
      _currentMode = mode;
      if (mode == 'USB') _selectedChannel = 3;
      if (mode == 'PSU') _selectedChannel = 1;
      if (mode == 'PROBE') _selectedChannel = 4;
    });
  }

  String _detectQcProtocol(double dp, double dm, double v) {
    if (dp > 3.0 && dm < 0.8 && v > 8.0) return 'QC 3.0 / 9V';
    if (dp > 2.5 && dm > 2.5) return 'APPLE 2.4A';
    if (dp > 0.5 && dm > 0.5 && (dp - dm).abs() < 0.3) return 'DCP 1.5A';
    if (v > 11.0) return 'QC 12V / PD';
    return 'NORMAL 5V';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _udpService,
      builder: (context, _) {
        final telemetry = _udpService.telemetry;
        final isConnected = _udpService.isConnected;

        return Scaffold(
          body: SafeArea(
            child: Container(
              color: const Color(0xFF07080B),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                children: [
                  // 1. TOP HEADER STATUS BAR
                  _buildHeader(isConnected, telemetry),

                  const SizedBox(height: 8),

                  // 2. MAIN COCKPIT: LEFT METERS & RIGHT OSCILLOSCOPE
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // LEFT PANEL: Multi-Channel Digital Multimeter Meters (36% width)
                        Expanded(
                          flex: 36,
                          child: _buildLeftMetersPanel(telemetry),
                        ),

                        const SizedBox(width: 10),

                        // RIGHT PANEL: Oscilloscope & Multi-Mode View (64% width)
                        Expanded(
                          flex: 64,
                          child: _buildRightOscilloscopePanel(telemetry),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- TOP HEADER ---
  Widget _buildHeader(bool isConnected, PsuTelemetry t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF10121A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E2333)),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Branding Badge (High-Contrast Red Carbon Emblem)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22080D),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFF2233), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2233).withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.bolt, color: Color(0xFFFFDD00), size: 16),
                    SizedBox(width: 5),
                    Text(
                      'NURHADI',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF2233),
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'SMART PSU',
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF08080C),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                ),
                child: Text(
                  'v1.0.0 PRO',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00E5FF),
                  ),
                ),
              ),
            ],
          ),

          // Quick Channel Readouts with Smooth 90ms Animation
          Row(
            children: [
              _buildSmoothQuickPill('CH1', t.v1, t.i1, const Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              _buildSmoothQuickPill('CH2', t.v2, t.i2, const Color(0xFF00FF66)),
              const SizedBox(width: 8),
              _buildSmoothQuickPill('CH3', t.v3, t.i3, const Color(0xFFFFDD00)),
            ],
          ),

          // Right Status & Action Buttons
          Row(
            children: [
              // Mode Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF08080C),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFFFF8800).withOpacity(0.5)),
                ),
                child: Text(
                  '$_currentMode MODE',
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF8800),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // IP Status & Latency
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showIpDialog,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF08080C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isConnected ? const Color(0xFF00FF66) : const Color(0xFFFF3344),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConnected ? const Color(0xFF00FF66) : const Color(0xFFFF3344),
                            boxShadow: [
                              BoxShadow(
                                color: isConnected ? const Color(0xFF00FF66) : const Color(0xFFFF3344),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _udpService.isDemoMode
                              ? 'DEMO [${_udpService.espIp}]'
                              : (isConnected ? '${_udpService.espIp} (${_udpService.latencyMs}ms)' : 'OFFLINE [${_udpService.espIp}]'),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isConnected ? const Color(0xFF00FF66) : const Color(0xFFFF3344),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Ping Action Button
              IconButton(
                onPressed: _showTestDialog,
                icon: const Icon(Icons.wifi_tethering_rounded, size: 16, color: Color(0xFF00FF66)),
                padding: const EdgeInsets.all(5),
                constraints: const BoxConstraints(),
                tooltip: 'Ping & Test Connection',
              ),

              const SizedBox(width: 4),

              // OTA Flash Button
              IconButton(
                onPressed: _showOtaDialog,
                icon: const Icon(Icons.cloud_upload_rounded, size: 17, color: Color(0xFF00E5FF)),
                padding: const EdgeInsets.all(5),
                constraints: const BoxConstraints(),
                tooltip: 'OTA Wireless Firmware Flash',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmoothQuickPill(String title, double targetV, double targetMa, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF08080C),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$title: ',
            style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: Colors.white54, fontWeight: FontWeight.bold),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: targetV, end: targetV),
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOutQuad,
            builder: (context, animV, _) => Text(
              '${animV.toStringAsFixed(1)}V',
              style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: targetMa, end: targetMa),
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOutQuad,
            builder: (context, animI, _) => Text(
              '${animI.toStringAsFixed(0)}mA',
              style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }

  // --- LEFT PANEL: MULTIMETER GAUGES & HARDWARE CONTROLS ---
  Widget _buildLeftMetersPanel(PsuTelemetry t) {
    double activeV = t.v1;
    double activeMa = t.i1;
    String chBadge = 'CH1 EXT';

    if (_selectedChannel == 2) {
      activeV = t.v2;
      activeMa = t.i2;
      chBadge = 'CH2 STEP';
    } else if (_selectedChannel == 3) {
      activeV = t.v3;
      activeMa = t.i3;
      chBadge = 'CH3 QC';
    } else if (_selectedChannel == 4) {
      activeV = t.avo;
      activeMa = 0.0;
      chBadge = 'AVO DIGITAL';
    }

    final double activeA = activeMa / 1000.0;
    final double activeW = activeV * activeA;
    final String qcProtocol = _detectQcProtocol(t.dp, t.dm, activeV);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0E13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2333)),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Channel Selector Tabs (CH1, CH2, CH3, AVO)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF06070A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1F2330)),
            ),
            child: Row(
              children: [
                _buildChannelTab(1, 'CH1', const Color(0xFF00E5FF)),
                _buildChannelTab(2, 'CH2', const Color(0xFF00FF66)),
                _buildChannelTab(3, 'CH3', const Color(0xFFFFDD00)),
                _buildChannelTab(4, 'AVO', const Color(0xFFFF3344)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 2. PRIMARY STATS: ARUS & TEGANGAN BIG LCD
          Expanded(
            flex: 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ARUS (Current)
                Expanded(
                  child: _buildSmoothLcdCard(
                    title: 'ARUS',
                    badge: chBadge,
                    numericValue: activeA,
                    decimals: 3,
                    unit: 'A',
                    color: const Color(0xFFFF8800),
                    footerLeft: 'MA: ${activeMa.toStringAsFixed(0)} mA',
                    footerRight: 'SHNT: 0.1Ω',
                  ),
                ),
                const SizedBox(width: 8),
                // TEGANGAN (Voltage)
                Expanded(
                  child: _buildSmoothLcdCard(
                    title: 'TEGANGAN',
                    badge: chBadge,
                    numericValue: activeV,
                    decimals: 2,
                    unit: 'V',
                    color: const Color(0xFFFFDD00),
                    footerLeft: 'BUS: ACTIVE',
                    footerRight: 'MAX: 26.0V',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 3. SECONDARY STATS: DAYA & KAPASITAS
          Expanded(
            flex: 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // DAYA
                Expanded(
                  child: _buildSmoothLcdCard(
                    title: 'DAYA AKTIF',
                    badge: '',
                    numericValue: activeW,
                    decimals: 2,
                    unit: 'W',
                    color: const Color(0xFFFF3344),
                    footerLeft: 'P = V × I',
                    footerRight: '',
                    isCompact: true,
                  ),
                ),
                const SizedBox(width: 8),
                // KAPASITAS / ENERGY
                Expanded(
                  child: _buildSmoothLcdCard(
                    title: 'KAPASITAS',
                    badge: '',
                    numericValue: _udpService.totalCapacityMah,
                    decimals: 0,
                    unit: 'mAh',
                    color: const Color(0xFF00E5FF),
                    footerLeft: 'ENERGY: ${_udpService.totalEnergyMWh.toStringAsFixed(1)} mWh',
                    footerRight: '',
                    isCompact: true,
                    onReset: _udpService.resetTripStats,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 4. DATA LINES: ADS1115 & QC PROBE (AVO, D+, D-)
          Expanded(
            flex: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF06070A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF8800).withOpacity(0.35)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ADS1115 16-BIT ADC / QC PROBE',
                        style: GoogleFonts.orbitron(fontSize: 8, color: Colors.white54, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        qcProtocol,
                        style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF00FF66), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildSmoothAdcItem('AVO PROBE', t.avo, const Color(0xFFFF3344)),
                      const SizedBox(width: 6),
                      _buildSmoothAdcItem('QC D+', t.dp, const Color(0xFF00E5FF)),
                      const SizedBox(width: 6),
                      _buildSmoothAdcItem('QC D-', t.dm, const Color(0xFFFFDD00)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 5. HARDWARE SWITCH CONTROLS (MOSFET, RELAY 1, RELAY 2)
          Expanded(
            flex: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF06070A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1F2330)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'HARDWARE SWITCH CONTROLS',
                        style: GoogleFonts.orbitron(fontSize: 8, color: Colors.white54, fontWeight: FontWeight.bold),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _udpService.toggleAllSwitches,
                          child: Text(
                            'MASTER TOGGLE',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8,
                              color: const Color(0xFF00E5FF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildSwitchItem('MOSFET', t.mosfet, const Color(0xFF00E5FF), _udpService.toggleMosfet),
                      const SizedBox(width: 8),
                      _buildSwitchItem('RELAY 1', t.relay1, const Color(0xFF00FF66), _udpService.toggleRelay1),
                      const SizedBox(width: 8),
                      _buildSwitchItem('RELAY 2', t.relay2, const Color(0xFFFFDD00), _udpService.toggleRelay2),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 6. ACTION BUTTON: MULAI ANALISA LIVE
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _isAnalyzing = !_isAnalyzing),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isAnalyzing ? const Color(0xFFFF3344) : const Color(0xFFFF8800),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isAnalyzing ? const Color(0xFFFF3344) : const Color(0xFFFF8800)).withOpacity(0.25),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isAnalyzing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 18,
                      color: _isAnalyzing ? const Color(0xFFFF3344) : const Color(0xFFFF8800),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAnalyzing ? 'BERHENTI ANALISA' : 'MULAI ANALISA LIVE',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: _isAnalyzing ? const Color(0xFFFF3344) : const Color(0xFFFF8800),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelTab(int ch, String label, Color color) {
    final isSelected = _selectedChannel == ch;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedChannel = ch),
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.22) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isSelected ? Border.all(color: color.withOpacity(0.7), width: 1.2) : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(color: color.withOpacity(0.4), blurRadius: 8),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmoothLcdCard({
    required String title,
    required String badge,
    required double numericValue,
    required int decimals,
    required String unit,
    required Color color,
    required String footerLeft,
    required String footerRight,
    bool isCompact = false,
    VoidCallback? onReset,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF06070A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 1.1),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.08), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.orbitron(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (onReset != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onReset,
                    child: const Icon(Icons.refresh_rounded, size: 13, color: Colors.white60),
                  ),
                )
              else if (badge.isNotEmpty)
                Text(
                  badge,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8,
                    color: Colors.white38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: numericValue, end: numericValue),
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOutQuad,
                builder: (context, animVal, _) => Text(
                  decimals == 0 ? animVal.floor().toString() : animVal.toStringAsFixed(decimals),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: isCompact ? 22 : 30,
                    fontWeight: FontWeight.w800,
                    color: color,
                    shadows: [
                      Shadow(color: color.withOpacity(0.8), blurRadius: 10),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: isCompact ? 11 : 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                footerLeft,
                style: GoogleFonts.jetBrainsMono(fontSize: 7.5, color: Colors.white38, fontWeight: FontWeight.w600),
              ),
              if (footerRight.isNotEmpty)
                Text(
                  footerRight,
                  style: GoogleFonts.jetBrainsMono(fontSize: 7.5, color: Colors.white38, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmoothAdcItem(String label, double val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10121A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFF1F2330)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(fontSize: 7.5, color: Colors.white54, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 1),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: val, end: val),
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOutQuad,
              builder: (context, animV, _) => Text(
                '${animV.toStringAsFixed(2)}V',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(String label, bool isOn, Color color, VoidCallback onToggle) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isOn ? color.withOpacity(0.18) : const Color(0xFF10121A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isOn ? color : const Color(0xFF1F2330),
                width: 1.2,
              ),
              boxShadow: isOn
                  ? [
                      BoxShadow(color: color.withOpacity(0.45), blurRadius: 8),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.power_settings_new_rounded,
                  size: 15,
                  color: isOn ? color : Colors.white38,
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: GoogleFonts.orbitron(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  isOn ? 'ON' : 'OFF',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: isOn ? color : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- RIGHT PANEL: OSCILLOSCOPE / MULTI-MODE & TERMINAL ---
  Widget _buildRightOscilloscopePanel(PsuTelemetry t) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0E13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2333)),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Navigation Modes Bar (PSU, USB, PROBE, WAVE, TERMINAL, SET)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                Row(
                  children: [
                    _buildNavButton('PSU', Icons.bolt_rounded, 'PSU'),
                    const SizedBox(width: 16),
                    _buildNavButton('USB/QC', Icons.usb_rounded, 'USB'),
                    const SizedBox(width: 16),
                    _buildNavButton('PROBE', Icons.speed_rounded, 'PROBE'),
                    const SizedBox(width: 16),
                    _buildNavButton('WAVE', Icons.waves_rounded, 'WAVE'),
                    const SizedBox(width: 16),
                    _buildNavButton('TERMINAL', Icons.terminal_rounded, 'TERMINAL'),
                    const SizedBox(width: 16),
                    _buildNavButton('SET', Icons.settings_rounded, 'SET', onTap: _showIpDialog),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.sensors_rounded, size: 14, color: Color(0xFF00FF66)),
                    const SizedBox(width: 4),
                    Text(
                      '${_udpService.pollingIntervalMs}ms (${(1000 / _udpService.pollingIntervalMs).round()}Hz)',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: const Color(0xFF00FF66),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Body: Either Live Oscilloscope or Interactive Terminal View
          Expanded(
            child: _currentMode == 'TERMINAL'
                ? _buildTerminalView()
                : CyberpunkTelemetryChart(
                    history: _udpService.history,
                    selectedChannel: _selectedChannel,
                    metric: _graphMetric,
                    isPaused: _isChartPaused,
                    totalEnergyMwh: _udpService.totalEnergyMWh,
                    onTogglePause: () => setState(() => _isChartPaused = !_isChartPaused),
                    onReset: _udpService.resetTripStats,
                    onMetricChanged: (m) => setState(() => _graphMetric = m),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(String label, IconData icon, String modeKey, {VoidCallback? onTap}) {
    final isActive = _currentMode == modeKey && onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => _switchMode(modeKey),
        borderRadius: BorderRadius.circular(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? const Color(0xFF00E5FF) : Colors.white38,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: isActive ? const Color(0xFF00E5FF) : Colors.white38,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 2,
              width: isActive ? 22 : 0,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF00E5FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isActive
                    ? [
                        BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.8), blurRadius: 4),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- INTERACTIVE TERMINAL VIEW ---
  Widget _buildTerminalView() {
    return Container(
      color: const Color(0xFF07080B),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SMART PSU SERIAL CONSOLE',
                style: GoogleFonts.orbitron(fontSize: 11, color: const Color(0xFF00FF66), fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => _switchMode('PSU'),
                icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E2333), height: 12),
          Expanded(
            child: ListView.builder(
              reverse: false,
              itemCount: _udpService.terminalLogs.length,
              itemBuilder: (context, index) {
                final log = _udpService.terminalLogs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Text(
                    log,
                    style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF00FF66)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _terminalController,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, color: Colors.white),
                  onSubmitted: (val) {
                    _udpService.sendRawTerminalCommand(val);
                    _terminalController.clear();
                  },
                  decoration: InputDecoration(
                    hintText: 'Ketik perintah: mosfet on, relay1 on, status, ping...',
                    hintStyle: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF10121A),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF1E2333))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF1E2333))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF00FF66))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF66),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {
                  _udpService.sendRawTerminalCommand(_terminalController.text);
                  _terminalController.clear();
                },
                child: Text('KIRIM', style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
