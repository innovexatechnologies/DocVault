import 'dart:io';
import 'package:flutter/services.dart';
import '../utils/file_utils.dart';

class ExternalPdfService {
  static const MethodChannel _channel =
      MethodChannel('docvault/pdf_intent');

  /// Processes an incoming external PDF content/file URI.
  /// Reads the bytes natively and writes them to a temporary cache location
  /// so that the in-app viewer can read it without automatically adding it
  /// to the persistent library (All Files).
  static Future<Map<String, dynamic>> importPdfFromUri(
    String uri,
  ) async {
    final result = await _channel.invokeMethod(
      'readPdf',
      {
        'uri': uri,
      },
    );

    if (result == null) {
      throw Exception('Failed to read external PDF document.');
    }

    final data = Map<Object?, Object?>.from(result);

    final bytes = Uint8List.fromList(
      List<int>.from(data['bytes'] as List),
    );

    final originalFileName =
        data['fileName']?.toString() ?? 'External_Document.pdf';

    String fileName = _sanitizeFileName(originalFileName);

    if (!fileName.toLowerCase().endsWith('.pdf')) {
      fileName = '$fileName.pdf';
    }

    // Save to Cache directory (temporary, not in permanent All Files catalog)
    final cacheDir = await FileUtils.getCacheDirectory();
    final tempFilePath = '${cacheDir.path}/$fileName';
    final file = File(tempFilePath);
    
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    return {
      'filePath': tempFilePath,
      'fileName': fileName,
    };
  }

  static String _sanitizeFileName(String fileName) {
    final cleaned = fileName
        .replaceAll(
          RegExp(r'[<>:"/\\|?*]'),
          '_',
        )
        .trim();

    if (cleaned.isEmpty) {
      return 'External_Document.pdf';
    }

    return cleaned;
  }
}