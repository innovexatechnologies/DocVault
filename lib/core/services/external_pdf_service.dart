import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../models/conversion_type.dart';
import '../utils/file_utils.dart';

class ExternalPdfService {
  static const MethodChannel _channel =
      MethodChannel('docvault/pdf_intent');

  // ===========================================================================
  // IMPORT EXTERNAL PDF / DOCX / PPTX
  // ===========================================================================

  static Future<Map<String, dynamic>> importDocumentFromUri(
    String uri,
  ) async {
    final cleanUri = uri.trim();

    if (cleanUri.isEmpty) {
      throw Exception('Document URI is empty.');
    }

    // -------------------------------------------------------------------------
    // READ FILE FROM ANDROID CONTENT URI
    // -------------------------------------------------------------------------

    final result = await _invokeDocumentRead(cleanUri);

    if (result == null || result.isEmpty) {
      throw Exception(
        'Android did not return document data.',
      );
    }

    // -------------------------------------------------------------------------
    // BYTES
    // -------------------------------------------------------------------------

    final rawBytes = result['bytes'];

    if (rawBytes == null) {
      throw Exception(
        'Android did not return document bytes.',
      );
    }

    late final Uint8List bytes;

    try {
      if (rawBytes is Uint8List) {
        bytes = rawBytes;
      } else if (rawBytes is List) {
        bytes = Uint8List.fromList(
          rawBytes.map((e) => e as int).toList(),
        );
      } else {
        throw Exception(
          'Invalid document byte data received from Android.',
        );
      }
    } catch (e) {
      throw Exception(
        'Failed to read external document bytes: $e',
      );
    }

    if (bytes.isEmpty) {
      throw Exception(
        'The external document is empty.',
      );
    }

    // -------------------------------------------------------------------------
    // FILE NAME
    // -------------------------------------------------------------------------

    final androidFileName =
        result['fileName']?.toString().trim();

    final mimeType =
        result['mimeType']?.toString().trim().toLowerCase();

    // First preference = Android returned file name.
    String originalFileName =
        androidFileName != null &&
                androidFileName.isNotEmpty
            ? androidFileName
            : _fileNameFromUri(cleanUri);

    // If Android did not give a usable extension, use MIME type.
    if (!_hasSupportedExtension(originalFileName)) {
      final extension = _extensionFromMimeType(mimeType);

      if (extension != null) {
        final baseName = _removeExtension(
          originalFileName,
        );

        originalFileName =
            '$baseName.$extension';
      }
    }

    // Final fallback.
    if (!_hasSupportedExtension(originalFileName)) {
      throw Exception(
        'Unable to determine whether the external file is PDF, DOCX, or PPTX.',
      );
    }

    // -------------------------------------------------------------------------
    // DETERMINE DOCUMENT TYPE
    // -------------------------------------------------------------------------

    final type =
        ConversionType.fromFileName(
      originalFileName,
    );

    // Only supported formats.
    if (!_isSupportedConversionType(type)) {
      throw Exception(
        'Unsupported external document type:\n'
        '$originalFileName',
      );
    }

    // -------------------------------------------------------------------------
    // NORMALIZE FILE NAME
    // -------------------------------------------------------------------------

    final fileName =
        FileUtils.normalizeFileName(
      originalFileName,
      type,
    );

    // -------------------------------------------------------------------------
    // UNIQUE CACHE FILE
    // -------------------------------------------------------------------------

    final cacheDir =
        await FileUtils.getCacheDirectory();

    final timestamp =
        DateTime.now().millisecondsSinceEpoch;

    final uniqueFileName =
        '${timestamp}_$fileName';

    final tempFilePath =
        '${cacheDir.path}/$uniqueFileName';

    final file =
        File(tempFilePath);

    await file.parent.create(
      recursive: true,
    );

    // -------------------------------------------------------------------------
    // WRITE FILE
    // -------------------------------------------------------------------------

    await file.writeAsBytes(
      bytes,
      flush: true,
    );

    // -------------------------------------------------------------------------
    // VERIFY FILE
    // -------------------------------------------------------------------------

    if (!await file.exists()) {
      throw Exception(
        'Failed to save external document.',
      );
    }

    final savedLength =
        await file.length();

    if (savedLength <= 0) {
      throw Exception(
        'Saved external document is empty.',
      );
    }

    // -------------------------------------------------------------------------
    // VERIFY EXTENSION
    // -------------------------------------------------------------------------

    final savedType =
        ConversionType.fromFileName(
      file.path,
    );

    if (!_isSupportedConversionType(savedType)) {
      await _safeDelete(file);

      throw Exception(
        'Saved external document has an unsupported format.',
      );
    }

    return {
      'filePath': file.path,
      'fileName': fileName,
      'type': savedType,
      'mimeType': mimeType,
    };
  }

  // ===========================================================================
  // PDF COMPATIBILITY METHOD
  // ===========================================================================

  static Future<Map<String, dynamic>> importPdfFromUri(
    String uri,
  ) async {
    return importDocumentFromUri(uri);
  }

  // ===========================================================================
  // ANDROID METHOD CHANNEL
  // ===========================================================================

  static Future<Map<String, dynamic>?> _invokeDocumentRead(
    String uri,
  ) async {
    // -------------------------------------------------------------------------
    // NEW METHOD
    // -------------------------------------------------------------------------

    try {
      final result = await _channel.invokeMethod(
        'readDocument',
        {
          'uri': uri,
        },
      );

      if (result != null && result is Map) {
        return Map<String, dynamic>.from(
          result.map(
            (key, value) => MapEntry(
              key.toString(),
              value,
            ),
          ),
        );
      }
    } catch (e) {
      // Continue to legacy method.
    }

    // -------------------------------------------------------------------------
    // LEGACY METHOD
    // -------------------------------------------------------------------------

    try {
      final result = await _channel.invokeMethod(
        'readPdf',
        {
          'uri': uri,
        },
      );

      if (result != null && result is Map) {
        return Map<String, dynamic>.from(
          result.map(
            (key, value) => MapEntry(
              key.toString(),
              value,
            ),
          ),
        );
      }
    } catch (e) {
      // Continue to final error.
    }

    throw Exception(
      'Failed to read external document from Android.',
    );
  }

  // ===========================================================================
  // FILE NAME FROM URI
  // ===========================================================================

  static String _fileNameFromUri(
    String uri,
  ) {
    try {
      final decoded =
          Uri.decodeComponent(uri);

      final lastPart =
          decoded.split('/').last;

      if (lastPart.isNotEmpty &&
          lastPart.contains('.')) {
        return lastPart;
      }
    } catch (_) {}

    return 'External_Document';
  }

  // ===========================================================================
  // SUPPORTED EXTENSIONS
  // ===========================================================================

  static bool _hasSupportedExtension(
    String fileName,
  ) {
    final lower =
        fileName.toLowerCase().trim();

    return lower.endsWith('.pdf') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.pptx');
  }

  static bool _isSupportedConversionType(
    ConversionType type,
  ) {
    return type == ConversionType.pdf ||
        type == ConversionType.docs ||
        type == ConversionType.ppt;
  }

  // ===========================================================================
  // MIME TYPE → EXTENSION
  // ===========================================================================

  static String? _extensionFromMimeType(
    String? mimeType,
  ) {
    if (mimeType == null ||
        mimeType.isEmpty) {
      return null;
    }

    switch (mimeType) {
      // PDF
      case 'application/pdf':
        return 'pdf';

      // DOCX
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return 'docx';

      // PPTX
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return 'pptx';

      // Older Word
      case 'application/msword':
        return 'doc';

      // Older PowerPoint
      case 'application/vnd.ms-powerpoint':
        return 'ppt';

      default:
        return null;
    }
  }

  // ===========================================================================
  // REMOVE EXTENSION
  // ===========================================================================

  static String _removeExtension(
    String fileName,
  ) {
    final index =
        fileName.lastIndexOf('.');

    if (index <= 0) {
      return fileName;
    }

    return fileName.substring(
      0,
      index,
    );
  }

  // ===========================================================================
  // SAFE DELETE
  // ===========================================================================

  static Future<void> _safeDelete(
    File file,
  ) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}