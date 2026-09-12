import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class FirmwareFile {
  final String name;
  final Uint8List bytes;

  FirmwareFile({required this.name, required this.bytes});

  int get size => bytes.length;
  String get sizeKb => (bytes.length / 1024).toStringAsFixed(1);
}

class OtaService {
  static Future<FirmwareFile?> pickFirmwareFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final f = result.files.first;
        if (f.bytes != null && f.bytes!.isNotEmpty) {
          return FirmwareFile(name: f.name, bytes: f.bytes!);
        }
      }
    } catch (e) {
      debugPrint('[OTA] Error picking file: $e');
    }
    return null;
  }

  static Future<bool> uploadFirmware({
    required String ip,
    required FirmwareFile file,
    required Function(double progress) onProgress,
    required Function(String error) onError,
  }) async {
    try {
      final uri = Uri.parse('http://$ip/update');
      final request = http.MultipartRequest('POST', uri);

      final multipartFile = http.MultipartFile.fromBytes(
        'update',
        file.bytes,
        filename: file.name,
      );
      request.files.add(multipartFile);

      onProgress(0.1);
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw Exception('Upload timeout ke ESP.'),
      );

      onProgress(0.9);

      if (streamedResponse.statusCode == 200) {
        onProgress(1.0);
        return true;
      } else {
        onError('Gagal upload: HTTP ${streamedResponse.statusCode}');
        return false;
      }
    } catch (e) {
      onError('Terjadi kesalahan saat upload OTA: $e');
      return false;
    }
  }
}
