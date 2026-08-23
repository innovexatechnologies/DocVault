import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../utils/file_utils.dart';
import 'pdf_storage_service.dart';

class ExternalPdfService {
  static const MethodChannel _channel =
      MethodChannel('docvault/pdf_intent');

  /// Imports an external PDF into DocVault permanent storage.
  static Future<Map<String, dynamic>> importPdfFromUri(
    String uri,
  ) async {
    if (uri.trim().isEmpty) {
      throw Exception('PDF URI is empty.');
    }

    // ============================================================
    // READ PDF FROM ANDROID
    // ============================================================

    final result = await _channel.invokeMethod(
      'readPdf',
      {
        'uri': uri,
      },
    );

    if (result == null) {
      throw Exception(
        'Failed to read external PDF document.',
      );
    }

    final data = Map<Object?, Object?>.from(result);

    final rawBytes = data['bytes'];

    if (rawBytes == null) {
      throw Exception(
        'Android did not return PDF data.',
      );
    }

    final bytes = Uint8List.fromList(
      List<int>.from(rawBytes as List),
    );

    if (bytes.isEmpty) {
      throw Exception(
        'The external PDF is empty.',
      );
    }

    // ============================================================
    // FILE NAME
    // ============================================================

    final originalFileName =
        data['fileName']?.toString() ??
            'External_Document.pdf';

    String fileName =
        _sanitizeFileName(originalFileName);

    if (!fileName
        .toLowerCase()
        .endsWith('.pdf')) {
      fileName = '$fileName.pdf';
    }

    // ============================================================
    // PERMANENT DOCVAULT STORAGE
    // ============================================================

    final appDirectory =
        await FileUtils.getAppDocumentsDirectory();

    await appDirectory.create(
      recursive: true,
    );

    // ============================================================
    // UNIQUE FILE NAME
    // ============================================================

    final finalFileName =
        await _getUniqueFileName(
      appDirectory,
      fileName,
    );

    final permanentPath =
        '${appDirectory.path}/$finalFileName';

    final file = File(permanentPath);

    await file.writeAsBytes(
      bytes,
      flush: true,
    );

    // ============================================================
    // VERIFY FILE
    // ============================================================

    if (!await file.exists()) {
      throw Exception(
        'Failed to save PDF inside DocVault.',
      );
    }

    final fileSize = await file.length();

    if (fileSize == 0) {
      throw Exception(
        'Saved PDF file is empty.',
      );
    }

    // ============================================================
    // REGISTER PDF IN DOCVAULT LIBRARY
    // ============================================================

    final storageService =
        PdfStorageService();

    await storageService.saveDocument(
      filePath: permanentPath,
      fileName: finalFileName,
      pageCount: 1,
    );

    // ============================================================
    // RETURN PERMANENT FILE PATH
    // ============================================================

    return {
      'filePath': permanentPath,
      'fileName': finalFileName,
    };
  }

  // ==============================================================
  // UNIQUE FILE NAME
  // ==============================================================

  static Future<String> _getUniqueFileName(
    Directory directory,
    String originalName,
  ) async {
    const extension = '.pdf';

    String baseName = originalName;

    if (baseName
        .toLowerCase()
        .endsWith(extension)) {
      baseName = baseName.substring(
        0,
        baseName.length - extension.length,
      );
    }

    String candidate =
        '$baseName$extension';

    int counter = 1;

    while (
        await File(
          '${directory.path}/$candidate',
        ).exists()) {
      candidate =
          '${baseName}_$counter$extension';

      counter++;
    }

    return candidate;
  }

  // ==============================================================
  // SANITIZE FILE NAME
  // ==============================================================

  static String _sanitizeFileName(
    String fileName,
  ) {
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