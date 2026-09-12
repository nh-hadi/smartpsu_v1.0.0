import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';

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
      const typeGroup = XTypeGroup(
        label: 'Firmware (.bin)',
        extensions: <String>['bin'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (file != null) {
        final bytes = await file.readAsBytes();
        return FirmwareFile(name: file.name, bytes: bytes);
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
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 && response.body.contains('UPDATE_OK')) {
        onProgress(1.0);
        return true;
      } else {
        onError('Gagal update: ${response.body}');
        return false;
      }
    } catch (e) {
      onError('Error: $e');
      return false;
    }
  }
}
