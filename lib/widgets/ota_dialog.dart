import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ota_service.dart';

class OtaDialog extends StatefulWidget {
  final String currentIp;

  const OtaDialog({super.key, required this.currentIp});

  @override
  State<OtaDialog> createState() => _OtaDialogState();
}

class _OtaDialogState extends State<OtaDialog> {
  late TextEditingController _ipController;
  FirmwareFile? _selectedFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.currentIp);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _chooseFile() async {
    final file = await OtaService.pickFirmwareFile();
    if (file != null) {
      setState(() {
        _selectedFile = file;
        _statusMessage = 'File dipilih: ${file.name} (${file.sizeKb} KB)';
        _isSuccess = false;
      });
    }
  }

  Future<void> _startUpload() async {
    if (_selectedFile == null) {
      setState(() {
        _statusMessage = 'Silakan pilih file firmware (.bin) terlebih dahulu!';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
      _statusMessage = 'Mengunggah firmware ke ESP via OTA...';
      _isSuccess = false;
    });

    final success = await OtaService.uploadFirmware(
      ip: _ipController.text.trim(),
      file: _selectedFile!,
      onProgress: (progress) {
        setState(() {
          _uploadProgress = progress;
        });
      },
      onError: (error) {
        setState(() {
          _statusMessage = error;
          _isSuccess = false;
          _isUploading = false;
        });
      },
    );

    if (success) {
      setState(() {
        _isUploading = false;
        _isSuccess = true;
        _uploadProgress = 1.0;
        _statusMessage = '🎉 FLASHING FIRMWARE SUKSES! ESP Sedang Restart...';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F131D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.system_update_alt, color: Color(0xFF00E5FF), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'OTA FIRMWARE FLASHER',
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
                  onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Target IP Input
            TextField(
              controller: _ipController,
              enabled: !_isUploading,
              style: GoogleFonts.orbitron(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'TARGET ESP IP / HOSTNAME',
                labelStyle: GoogleFonts.rajdhani(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                prefixIcon: const Icon(Icons.wifi, color: Color(0xFF00E5FF), size: 18),
                filled: true,
                fillColor: const Color(0xFF090D16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // File Selector Box
            InkWell(
              onTap: _isUploading ? null : _chooseFile,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedFile != null ? const Color(0xFF00E676) : Colors.white24,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedFile != null ? Icons.check_circle : Icons.folder_open,
                      color: _selectedFile != null ? const Color(0xFF00E676) : const Color(0xFF00E5FF),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFile != null
                            ? _selectedFile!.name
                            : 'Klik untuk memilih file firmware (.bin)',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          color: _selectedFile != null ? Colors.white : Colors.white54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Progress Bar
            if (_isUploading || _isSuccess) ...[
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: const Color(0xFF161F30),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isSuccess ? const Color(0xFF00E676) : const Color(0xFF00E5FF),
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${(_uploadProgress * 100).toInt()}%',
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _isSuccess ? const Color(0xFF00E676) : const Color(0xFF00E5FF),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Status message
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isSuccess ? const Color(0xFF1B5E20).withOpacity(0.3) : const Color(0xFFB71C1C).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSuccess ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                  ),
                ),
                child: Text(
                  _statusMessage!,
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('BATAL', style: GoogleFonts.orbitron(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _startUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF1744), // Racing Red
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 8,
                      shadowColor: const Color(0xFFFF1744).withOpacity(0.6),
                    ),
                    child: Text(
                      _isUploading ? 'FLASHING...' : '⚡ FLASH FIRMWARE',
                      style: GoogleFonts.orbitron(fontWeight: FontWeight.w900),
                    ),
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
