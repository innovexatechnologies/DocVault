import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../models/conversion_type.dart';
import '../utils/file_utils.dart';

class ExternalPdfService {
  static const MethodChannel _channel =
      MethodChannel('docvault/pdf_intent');

  /// Imports an external PDF/DOCX/PPTX from an Android content URI.
  ///
  /// The file is copied into the app's cache directory so it can be
  /// opened by the PDF viewer without being permanently added to
  /// the All Files library.
  static Future<Map<String, dynamic>> importPdfFromUri(
    String uri,
  ) async {
    if (uri.trim().isEmpty) {
      throw Exception('PDF URI is empty.');
    }

    // ============================================================
    // READ DOCUMENT FROM ANDROID
    // ============================================================

    final result = await _channel.invokeMethod(
      'readPdf',
      {
        'uri': uri,
      },
    );

    if (result == null) {
      throw Exception(
        'Failed to read external document.',
      );
    }

    final data = Map<Object?, Object?>.from(result);

    // ============================================================
    // READ BYTES
    // ============================================================

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

    final type =
        ConversionType.fromFileName(originalFileName);

    final fileName =
        FileUtils.normalizeFileName(
      originalFileName,
      type,
    );

    // ============================================================
    // SAVE TO CACHE
    // ============================================================

    final cacheDir =
        await FileUtils.getCacheDirectory();

    final tempFilePath =
        '${cacheDir.path}/$fileName';

    final file = File(tempFilePath);

    await file.parent.create(
      recursive: true,
    );

    await file.writeAsBytes(
      bytes,
      flush: true,
    );

    // ============================================================
    // VERIFY FILE
    // ============================================================

    if (!await file.exists()) {
      throw Exception(
        'Failed to save external document.',
      );
    }

    final fileSize =
        await file.length();

    if (fileSize == 0) {
      throw Exception(
        'Saved external document is empty.',
      );
    }

    return {
      'filePath': tempFilePath,
      'fileName': fileName,
    };
  }
}