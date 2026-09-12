import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/udp_service.dart';

class IpSettingsDialog extends StatefulWidget {
  final UdpService udpService;

  const IpSettingsDialog({super.key, required this.udpService});

  @override
  State<IpSettingsDialog> createState() => _IpSettingsDialogState();
}

class _IpSettingsDialogState extends State<IpSettingsDialog> {
  late final TextEditingController _ipController;
  late final TextEditingController _intervalController;
  late bool _demoMode;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.udpService.espIp);
    _intervalController = TextEditingController(text: widget.udpService.pollingIntervalMs.toString());
    _demoMode = widget.udpService.isDemoMode;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131318),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.settings, color: Color(0xFF00E5FF), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'PENGATURAN KONEKSI ESP',
                      style: GoogleFonts.orbitron(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00E5FF),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // IP ESP Input
            Text(
              'IP / HOSTNAME ESP:',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _ipController,
              style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '192.168.4.1 atau smartpsu.local',
                hintStyle: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 11),
                filled: true,
                fillColor: const Color(0xFF08080A),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF27272A))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF27272A))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00E5FF))),
              ),
            ),

            const SizedBox(height: 12),

            // Polling interval
            Text(
              'POLLING INTERVAL (ms):',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '100',
                filled: true,
                fillColor: const Color(0xFF08080A),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF27272A))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF27272A))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00E5FF))),
              ),
            ),

            const SizedBox(height: 10),

            // Demo mode toggle
            Row(
              children: [
                Checkbox(
                  value: _demoMode,
                  activeColor: const Color(0xFFFF8800),
                  onChanged: (val) => setState(() => _demoMode = val ?? false),
                ),
                Expanded(
                  child: Text(
                    'Mode Simulasi Demo (Jika ESP belum aktif)',
                    style: GoogleFonts.rajdhani(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('BATAL', style: GoogleFonts.orbitron(color: Colors.white54, fontSize: 11)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    widget.udpService.setEspIp(_ipController.text);
                    final interval = int.tryParse(_intervalController.text) ?? 100;
                    widget.udpService.setPollingInterval(interval);
                    widget.udpService.setDemoMode(_demoMode);
                    widget.udpService.startListening();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'SIMPAN',
                    style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
