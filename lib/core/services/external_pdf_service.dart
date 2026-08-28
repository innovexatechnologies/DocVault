import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../models/conversion_type.dart';
import '../utils/file_utils.dart';

class ExternalPdfService {
  static const MethodChannel _channel =
      MethodChannel('docvault/pdf_intent');

  static Future<Map<String, dynamic>> importDocumentFromUri(
    String uri,
  ) async {
    final cleanUri = uri.trim();

    if (cleanUri.isEmpty) {
      throw Exception('Document URI is empty.');
    }

    final result = await _invokeDocumentRead(cleanUri);

    if (result.isEmpty) {
      throw Exception('Android did not return document data.');
    }

    final rawBytes = result['bytes'];

    if (rawBytes == null) {
      throw Exception('Android did not return document bytes.');
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
        'Failed to convert external document bytes: $e',
      );
    }

    if (bytes.isEmpty) {
      throw Exception('The external document is empty.');
    }

    final androidFileName =
        result['fileName']?.toString().trim();

    final mimeType =
        result['mimeType']?.toString().trim().toLowerCase();

    String originalFileName;

    if (androidFileName != null &&
        androidFileName.isNotEmpty) {
      originalFileName = androidFileName;
    } else {
      originalFileName = _fileNameFromUri(cleanUri);
    }

    if (!_hasSupportedExtension(originalFileName)) {
      final extension = _extensionFromMimeType(mimeType);

      if (extension != null) {
        final baseName = _removeExtension(originalFileName);
        originalFileName = '$baseName.$extension';
      }
    }

    if (!_hasSupportedExtension(originalFileName)) {
      throw Exception(
        'Unsupported external document format: $originalFileName',
      );
    }

    final type = ConversionType.fromFileName(
      originalFileName,
    );

    if (!_isSupportedConversionType(type)) {
      throw Exception(
        'Unsupported external document type: $originalFileName',
      );
    }

    final fileName = FileUtils.normalizeFileName(
      originalFileName,
      type,
    );

    final cacheDir =
        await FileUtils.getCacheDirectory();

    final timestamp =
        DateTime.now().millisecondsSinceEpoch;

    final uniqueFileName =
        '${timestamp}_$fileName';

    final tempFilePath =
        '${cacheDir.path}/$uniqueFileName';

    final file = File(tempFilePath);

    await file.parent.create(
      recursive: true,
    );

    await file.writeAsBytes(
      bytes,
      flush: true,
    );

    if (!await file.exists()) {
      throw Exception(
        'Failed to save external document.',
      );
    }

    final savedLength = await file.length();

    if (savedLength <= 0) {
      throw Exception(
        'Saved external document is empty.',
      );
    }

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

  static Future<Map<String, dynamic>> importPdfFromUri(
    String uri,
  ) async {
    return importDocumentFromUri(uri);
  }

  static Future<Map<String, dynamic>> _invokeDocumentRead(
    String uri,
  ) async {
    try {
      final result = await _channel.invokeMethod(
        'readDocument',
        {
          'uri': uri,
        },
      );

      if (result is Map) {
        return Map<String, dynamic>.from(
          result.map(
            (key, value) => MapEntry(
              key.toString(),
              value,
            ),
          ),
        );
      }
    } catch (_) {}

    try {
      final result = await _channel.invokeMethod(
        'readPdf',
        {
          'uri': uri,
        },
      );

      if (result is Map) {
        return Map<String, dynamic>.from(
          result.map(
            (key, value) => MapEntry(
              key.toString(),
              value,
            ),
          ),
        );
      }
    } catch (_) {}

    throw Exception(
      'Unable to read external document from Android.',
    );
  }

  static String _fileNameFromUri(
    String uriString,
  ) {
    try {
      final uri = Uri.parse(uriString);

      if (uri.pathSegments.isNotEmpty) {
        final lastSegment =
            uri.pathSegments.last;

        if (lastSegment.isNotEmpty) {
          return Uri.decodeComponent(lastSegment);
        }
      }
    } catch (_) {}

    return 'External_Document';
  }

  static bool _hasSupportedExtension(
    String fileName,
  ) {
    final lower =
        fileName.toLowerCase().trim();

    return lower.endsWith('.pdf') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.ppt') ||
        lower.endsWith('.pptx');
  }

  static bool _isSupportedConversionType(
    ConversionType type,
  ) {
    return type == ConversionType.pdf ||
        type == ConversionType.docs ||
        type == ConversionType.ppt;
  }

  static String? _extensionFromMimeType(
    String? mimeType,
  ) {
    if (mimeType == null ||
        mimeType.isEmpty) {
      return null;
    }

    switch (mimeType.toLowerCase()) {
      case 'application/pdf':
        return 'pdf';

      case 'application/msword':
        return 'doc';

      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return 'docx';

      case 'application/vnd.ms-powerpoint':
        return 'ppt';

      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return 'pptx';

      default:
        return null;
    }
  }

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