import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../utils/file_utils.dart';

class ExternalPdfService {
  static const MethodChannel _channel =
      MethodChannel('docvault/pdf_intent');

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
      throw Exception('PDF import failed.');
    }

    final data = Map<Object?, Object?>.from(result);

    final bytes = Uint8List.fromList(
      List<int>.from(data['bytes'] as List),
    );

    final originalFileName =
        data['fileName']?.toString() ?? 'Imported_PDF.pdf';

    String fileName = _sanitizeFileName(originalFileName);

    if (!fileName.toLowerCase().endsWith('.pdf')) {
      fileName = '$fileName.pdf';
    }

    fileName = await _getUniqueFileName(fileName);

    // IMPORTANT:
    // This uses the exact same storage location
    // used by your generated PDFs.
    final filePath = await FileUtils.getFullPdfPath(fileName);

    final file = await FileUtils.getPdfFile(filePath);

    await file.writeAsBytes(bytes, flush: true);

    return {
      'filePath': filePath,
      'fileName': fileName,
    };
  }

  static Future<String> _getUniqueFileName(
    String fileName,
  ) async {
    String name = fileName;

    final dotIndex = fileName.lastIndexOf('.');

    final baseName = dotIndex > 0
        ? fileName.substring(0, dotIndex)
        : fileName;

    final extension = dotIndex > 0
        ? fileName.substring(dotIndex)
        : '.pdf';

    int counter = 1;

    while (true) {
      final path = await FileUtils.getFullPdfPath(name);

      if (!await FileUtils.pdfFileExists(path)) {
        return name;
      }

      name = '${baseName}_$counter$extension';
      counter++;
    }
  }

  static String _sanitizeFileName(String fileName) {
    final cleaned = fileName
        .replaceAll(
          RegExp(r'[<>:"/\\|?*]'),
          '_',
        )
        .trim();

    if (cleaned.isEmpty) {
      return 'Imported_PDF.pdf';
    }

    return cleaned;
  }
}