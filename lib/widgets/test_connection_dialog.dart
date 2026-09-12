import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/udp_service.dart';

class TestConnectionDialog extends StatefulWidget {
  final UdpService udpService;

  const TestConnectionDialog({super.key, required this.udpService});

  @override
  State<TestConnectionDialog> createState() => _TestConnectionDialogState();
}

class _TestConnectionDialogState extends State<TestConnectionDialog> {
  final TextEditingController _msgController = TextEditingController(text: 'PING_TEST_123');
  bool _isLoading = false;
  final List<Map<String, dynamic>> _testLogs = [];

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _runTest() async {
    final textToSend = _msgController.text.trim();
    if (textToSend.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final result = await widget.udpService.testConnection(textToSend);

    setState(() {
      _isLoading = false;
      _testLogs.insert(0, {
        'time': DateTime.now(),
        'sent': result['sent'],
        'success': result['success'] == true,
        'latency': result['latency_ms'],
        'response': result['success'] == true ? result['body'] : result['error'],
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F131D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF00E676), width: 1.5),
      ),
      child: Container(
        width: 550,
        padding: const EdgeInsets.all(22),
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
                    const Icon(Icons.network_ping, color: Color(0xFF00E676), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'UJI KONEKSI & DIAGNOSTIK',
                      style: GoogleFonts.orbitron(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Target Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.router, color: Color(0xFF00E5FF), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'TARGET ESP IP:',
                        style: GoogleFonts.rajdhani(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.udpService.espIp,
                        style: GoogleFonts.orbitron(color: const Color(0xFF00E5FF), fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.udpService.isConnected
                          ? const Color(0xFF00E676).withOpacity(0.15)
                          : const Color(0xFFFF1744).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: widget.udpService.isConnected ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                      ),
                    ),
                    child: Text(
                      widget.udpService.isConnected ? 'CONNECTED' : 'DISCONNECTED',
                      style: GoogleFonts.orbitron(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: widget.udpService.isConnected ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Send Input Box
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: GoogleFonts.orbitron(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'PESAN TEST (KIRIM KE ESP)',
                      labelStyle: GoogleFonts.rajdhani(color: const Color(0xFF00E676), fontWeight: FontWeight.bold),
                      prefixIcon: const Icon(Icons.send, color: Color(0xFF00E676), size: 18),
                      filled: true,
                      fillColor: const Color(0xFF090D16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF00E676)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : _runTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 6,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text('KIRIM & UJI', style: GoogleFonts.orbitron(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Log Console (Send & Receive Feed)
            Text(
              'LOG RIWAYAT PENGIRIMAN & BALASAN:',
              style: GoogleFonts.rajdhani(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54),
            ),
            const SizedBox(height: 6),

            Container(
              height: 160,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF06090F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: _testLogs.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada riwayat test. Ketik pesan di atas lalu klik KIRIM & UJI.',
                        style: GoogleFonts.rajdhani(color: Colors.white30, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _testLogs.length,
                      itemBuilder: (context, idx) {
                        final log = _testLogs[idx];
                        final bool success = log['success'];
                        final int latency = log['latency'] ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1422),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: success ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        success ? Icons.check_circle : Icons.error,
                                        size: 14,
                                        color: success ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '📤 KIRIM: "${log['sent']}"',
                                        style: GoogleFonts.orbitron(fontSize: 10, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '⏱️ ${latency}ms',
                                      style: GoogleFonts.orbitron(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF00E5FF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '📥 TERIMA: ${log['response']}',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: success ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
