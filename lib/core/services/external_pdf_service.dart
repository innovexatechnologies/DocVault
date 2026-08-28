import 'dart:io';
import 'package:flutter/services.dart';

import '../../models/conversion_type.dart';
import '../utils/file_utils.dart';

class ExternalPdfService {
  static const MethodChannel _channel =
      MethodChannel('docvault/pdf_intent');

  /// Imports an external PDF, DOCX, or PPTX from an Android content URI.
  ///
  /// The file is copied into the app cache directory so it can be opened in-app
  /// without being permanently added to the All Files library.
  static Future<Map<String, dynamic>> importDocumentFromUri(
    String uri,
  ) async {
    if (uri.trim().isEmpty) {
      throw Exception('Document URI is empty.');
    }

    final result = await _invokeDocumentRead(uri);

    final data = Map<Object?, Object?>.from(result ?? {});

    final rawBytes = data['bytes'];

    if (rawBytes == null) {
      throw Exception(
        'Android did not return document data.',
      );
    }

    final bytes = Uint8List.fromList(
      List<int>.from(rawBytes as List),
    );

    if (bytes.isEmpty) {
      throw Exception(
        'The external document is empty.',
      );
    }

    final originalFileName =
        data['fileName']?.toString() ??
            'External_Document.pdf';

    final type = ConversionType.fromFileName(originalFileName);

    final fileName = FileUtils.normalizeFileName(
      originalFileName,
      type,
    );

    final cacheDir = await FileUtils.getCacheDirectory();
    final tempFilePath = '${cacheDir.path}/$fileName';
    final file = File(tempFilePath);

    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    if (!await file.exists()) {
      throw Exception(
        'Failed to save external document.',
      );
    }

    if (await file.length() == 0) {
      throw Exception(
        'Saved external document is empty.',
      );
    }

    return {
      'filePath': tempFilePath,
      'fileName': fileName,
    };
  }

  static Future<Map<String, dynamic>> importPdfFromUri(
    String uri,
  ) async {
    return importDocumentFromUri(uri);
  }

  static Future<Map<dynamic, dynamic>?> _invokeDocumentRead(String uri) async {
    try {
      final result = await _channel.invokeMethod(
        'readDocument',
        {'uri': uri},
      );
      if (result != null) {
        return Map<dynamic, dynamic>.from(result as Map);
      }
    } catch (_) {}

    try {
      final legacyResult = await _channel.invokeMethod(
        'readPdf',
        {'uri': uri},
      );
      if (legacyResult != null) {
        return Map<dynamic, dynamic>.from(legacyResult as Map);
      }
    } catch (_) {}

    throw Exception('Failed to read external document.');
  }
}