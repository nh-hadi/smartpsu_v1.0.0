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
        scaffoldBackgroundColor: const Color(0xFF08080A),
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

class _CyberpunkDashboardScreenState extends State<CyberpunkDashboardScreen> {
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
              color: const Color(0xFF08080A),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  // 1. TOP HEADER STATUS BAR (Ultra Compact Landscape)
                  _buildHeader(isConnected, telemetry),

                  const SizedBox(height: 6),

                  // 2. MAIN COCKPIT: LEFT GAUGES & RIGHT GRAPH / TERMINAL
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // LEFT PANEL: Multi-Channel Digital Multimeter Meters (38% width)
                        Expanded(
                          flex: 38,
                          child: _buildLeftMetersPanel(telemetry),
                        ),

                        const SizedBox(width: 8),

                        // RIGHT PANEL: Oscilloscope & Multi-Mode View (62% width)
                        Expanded(
                          flex: 62,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131318),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Branding
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF3344), Color(0xFFD50000)]),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFF3344).withOpacity(0.5), blurRadius: 6),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, color: Colors.yellowAccent, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      'NURHADI',
                      style: GoogleFonts.orbitron(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SMART PSU',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF08080A),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                ),
                child: Text(
                  'v1.0.0 PRO',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00E5FF),
                  ),
                ),
              ),
            ],
          ),

          // Quick Channel Pills (CH1, CH2, CH3)
          Row(
            children: [
              _buildQuickPill('CH1', '${t.v1.toStringAsFixed(1)}V', '${t.i1.toStringAsFixed(0)}mA', const Color(0xFF00E5FF)),
              const SizedBox(width: 6),
              _buildQuickPill('CH2', '${t.v2.toStringAsFixed(1)}V', '${t.i2.toStringAsFixed(0)}mA', const Color(0xFF00FF66)),
              const SizedBox(width: 6),
              _buildQuickPill('CH3', '${t.v3.toStringAsFixed(1)}V', '${t.i3.toStringAsFixed(0)}mA', const Color(0xFFFFDD00)),
            ],
          ),

          // IP Status & Actions
          Row(
            children: [
              // Current Mode Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF08080A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFFF8800).withOpacity(0.4)),
                ),
                child: Text(
                  '$_currentMode MODE',
                  style: GoogleFonts.orbitron(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFFFF8800)),
                ),
              ),

              const SizedBox(width: 6),

              // IP Status Button
              InkWell(
                onTap: _showIpDialog,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF08080A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isConnected ? const Color(0xFF00FF66) : const Color(0xFFFF3344),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected ? const Color(0xFF00FF66) : const Color(0xFFFF3344),
                          boxShadow: [
                            BoxShadow(
                              color: isConnected ? const Color(0xFF00FF66) : const Color(0xFFFF3344),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _udpService.isDemoMode
                            ? 'DEMO [${_udpService.espIp}]'
                            : (isConnected ? '${_udpService.espIp} (${_udpService.latencyMs}ms)' : 'OFFLINE [${_udpService.espIp}]'),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? const Color(0xFF00FF66) : const Color(0xFFFF3344),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Ping Button
              IconButton(
                onPressed: _showTestDialog,
                icon: const Icon(Icons.wifi_tethering, size: 15, color: Color(0xFF00FF66)),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: 'Ping & Test Connection',
              ),

              const SizedBox(width: 4),

              // OTA Flash Button
              IconButton(
                onPressed: _showOtaDialog,
                icon: const Icon(Icons.cloud_upload_outlined, size: 16, color: Color(0xFF00E5FF)),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: 'OTA Firmware Flash',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPill(String title, String v, String i, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF08080A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$title: ', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.white54, fontWeight: FontWeight.bold)),
          Text(v, style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 3),
          Text(i, style: GoogleFonts.jetBrainsMono(fontSize: 7.5, color: Colors.white38)),
        ],
      ),
    );
  }

  // --- LEFT PANEL: MULTIMETER GAUGES & HARDWARE CONTROLS ---
  Widget _buildLeftMetersPanel(PsuTelemetry t) {
    // Determine active metrics based on selected tab
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
        color: const Color(0xFF131318),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Channel Selector Tabs (CH1, CH2, CH3, AVO)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF08080A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF27272A)),
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

          const SizedBox(height: 6),

          // 2. PRIMARY STATS: ARUS & TEGANGAN BIG LCD
          Row(
            children: [
              // ARUS (Current)
              Expanded(
                child: _buildLcdCard(
                  title: 'ARUS',
                  badge: chBadge,
                  value: activeA.toStringAsFixed(3),
                  unit: 'A',
                  color: const Color(0xFFFF8800),
                  footerLeft: 'MA: ${activeMa.toStringAsFixed(0)} mA',
                  footerRight: 'SHNT: 0.1Ω',
                ),
              ),
              const SizedBox(width: 6),
              // TEGANGAN (Voltage)
              Expanded(
                child: _buildLcdCard(
                  title: 'TEGANGAN',
                  badge: chBadge,
                  value: activeV.toStringAsFixed(2),
                  unit: 'V',
                  color: const Color(0xFFFFDD00),
                  footerLeft: 'BUS: ACTIVE',
                  footerRight: 'MAX: 26.0V',
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // 3. SECONDARY STATS: DAYA & KAPASITAS
          Row(
            children: [
              // DAYA
              Expanded(
                child: _buildLcdCard(
                  title: 'DAYA AKTIF',
                  badge: '',
                  value: activeW.toStringAsFixed(2),
                  unit: 'W',
                  color: const Color(0xFFFF3344),
                  footerLeft: 'P = V × I',
                  footerRight: '',
                  isCompact: true,
                ),
              ),
              const SizedBox(width: 6),
              // KAPASITAS / ENERGY
              Expanded(
                child: _buildLcdCard(
                  title: 'KAPASITAS',
                  badge: '',
                  value: _udpService.totalCapacityMah.floor().toString(),
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

          const SizedBox(height: 6),

          // 4. DATA LINES: ADS1115 & QC PROBE (AVO, D+, D-)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF08080A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFF8800).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ADS1115 16-BIT ADC / QC PROBE',
                      style: GoogleFonts.orbitron(fontSize: 7.5, color: Colors.white54, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      qcProtocol,
                      style: GoogleFonts.jetBrainsMono(fontSize: 8, color: const Color(0xFF00FF66), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _buildAdcItem('AVO PROBE', '${t.avo.toStringAsFixed(2)}V', const Color(0xFFFF3344)),
                    const SizedBox(width: 4),
                    _buildAdcItem('QC D+', '${t.dp.toStringAsFixed(2)}V', const Color(0xFF00E5FF)),
                    const SizedBox(width: 4),
                    _buildAdcItem('QC D-', '${t.dm.toStringAsFixed(2)}V', const Color(0xFFFFDD00)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 5. HARDWARE SWITCH CONTROLS (MOSFET, RELAY 1, RELAY 2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF08080A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'HARDWARE SWITCH CONTROLS',
                      style: GoogleFonts.orbitron(fontSize: 7.5, color: Colors.white54, fontWeight: FontWeight.bold),
                    ),
                    InkWell(
                      onTap: _udpService.toggleAllSwitches,
                      child: Text(
                        'MASTER TOGGLE',
                        style: GoogleFonts.jetBrainsMono(fontSize: 7.5, color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildSwitchItem('MOSFET', t.mosfet, const Color(0xFF00E5FF), _udpService.toggleMosfet),
                    const SizedBox(width: 6),
                    _buildSwitchItem('RELAY 1', t.relay1, const Color(0xFF00FF66), _udpService.toggleRelay1),
                    const SizedBox(width: 6),
                    _buildSwitchItem('RELAY 2', t.relay2, const Color(0xFFFFDD00), _udpService.toggleRelay2),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // 6. ACTION BUTTON: MULAI ANALISA LIVE
          InkWell(
            onTap: () => setState(() => _isAnalyzing = !_isAnalyzing),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isAnalyzing ? const Color(0xFFFF3344) : const Color(0xFFFF8800),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isAnalyzing ? const Color(0xFFFF3344) : const Color(0xFFFF8800)).withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isAnalyzing ? Icons.stop : Icons.play_arrow,
                    size: 16,
                    color: _isAnalyzing ? const Color(0xFFFF3344) : const Color(0xFFFF8800),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isAnalyzing ? 'BERHENTI ANALISA' : 'MULAI ANALISA LIVE',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _isAnalyzing ? const Color(0xFFFF3344) : const Color(0xFFFF8800),
                    ),
                  ),
                ],
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
      child: InkWell(
        onTap: () => setState(() => _selectedChannel = ch),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: isSelected ? Border.all(color: color.withOpacity(0.6)) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? color : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLcdCard({
    required String title,
    required String badge,
    required String value,
    required String unit,
    required Color color,
    required String footerLeft,
    required String footerRight,
    bool isCompact = false,
    VoidCallback? onReset,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: isCompact ? 5 : 7),
      decoration: BoxDecoration(
        color: const Color(0xFF08080A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.06), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: color),
              ),
              if (onReset != null)
                InkWell(
                  onTap: onReset,
                  child: const Icon(Icons.refresh, size: 11, color: Colors.white54),
                )
              else if (badge.isNotEmpty)
                Text(
                  badge,
                  style: GoogleFonts.jetBrainsMono(fontSize: 7.5, color: Colors.white38, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: isCompact ? 20 : 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                  shadows: [Shadow(color: color.withOpacity(0.7), blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(footerLeft, style: GoogleFonts.jetBrainsMono(fontSize: 7, color: Colors.white38)),
              if (footerRight.isNotEmpty)
                Text(footerRight, style: GoogleFonts.jetBrainsMono(fontSize: 7, color: Colors.white38)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdcItem(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF131318),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 7, color: Colors.white54)),
            const SizedBox(height: 1),
            Text(
              val,
              style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(String label, bool isOn, Color color, VoidCallback onToggle) {
    return Expanded(
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isOn ? color.withOpacity(0.15) : const Color(0xFF131318),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isOn ? color : const Color(0xFF27272A), width: 1.2),
            boxShadow: isOn
                ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)]
                : null,
          ),
          child: Column(
            children: [
              Icon(Icons.power_settings_new, size: 14, color: isOn ? color : Colors.white38),
              const SizedBox(height: 1),
              Text(
                label,
                style: GoogleFonts.orbitron(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              Text(
                isOn ? 'ON' : 'OFF',
                style: GoogleFonts.jetBrainsMono(fontSize: 7, fontWeight: FontWeight.bold, color: isOn ? color : Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- RIGHT PANEL: OSCILLOSCOPE / MULTI-MODE & TERMINAL ---
  Widget _buildRightOscilloscopePanel(PsuTelemetry t) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131318),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Navigation Modes Bar (PSU, USB, PROBE, WAVE, TERMINAL, SET)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF08080A).withOpacity(0.8),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
              border: const Border(bottom: BorderSide(color: Color(0xFF27272A))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildNavButton('PSU', Icons.bolt, 'PSU'),
                    const SizedBox(width: 12),
                    _buildNavButton('USB/QC', Icons.usb, 'USB'),
                    const SizedBox(width: 12),
                    _buildNavButton('PROBE', Icons.speed, 'PROBE'),
                    const SizedBox(width: 12),
                    _buildNavButton('WAVE', Icons.waves, 'WAVE'),
                    const SizedBox(width: 12),
                    _buildNavButton('TERMINAL', Icons.terminal, 'TERMINAL'),
                    const SizedBox(width: 12),
                    _buildNavButton('SET', Icons.settings, 'SET', onTap: _showIpDialog),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.sensors, size: 12, color: Color(0xFF00FF66)),
                    const SizedBox(width: 4),
                    Text(
                      '${_udpService.pollingIntervalMs}ms (${(1000 / _udpService.pollingIntervalMs).round()}Hz)',
                      style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF00FF66), fontWeight: FontWeight.bold),
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
    return InkWell(
      onTap: onTap ?? () => _switchMode(modeKey),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isActive ? const Color(0xFF00E5FF) : Colors.white38),
          const SizedBox(height: 1),
          Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: isActive ? const Color(0xFF00E5FF) : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  // --- INTERACTIVE TERMINAL VIEW ---
  Widget _buildTerminalView() {
    return Container(
      color: const Color(0xFF08080A),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SMART PSU SERIAL CONSOLE',
                style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF00FF66), fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => _switchMode('PSU'),
                icon: const Icon(Icons.close, size: 14, color: Colors.white54),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(color: Color(0xFF27272A), height: 8),
          Expanded(
            child: ListView.builder(
              reverse: false,
              itemCount: _udpService.terminalLogs.length,
              itemBuilder: (context, index) {
                final log = _udpService.terminalLogs[index];
                return Text(
                  log,
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF00FF66)),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _terminalController,
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: Colors.white),
                  onSubmitted: (val) {
                    _udpService.sendRawTerminalCommand(val);
                    _terminalController.clear();
                  },
                  decoration: InputDecoration(
                    hintText: 'Ketik perintah: mosfet on, relay1 on, status, ping...',
                    hintStyle: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF131318),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF27272A))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF27272A))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF00FF66))),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF66),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {
                  _udpService.sendRawTerminalCommand(_terminalController.text);
                  _terminalController.clear();
                },
                child: Text('KIRIM', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
