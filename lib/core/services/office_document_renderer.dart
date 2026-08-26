import 'dart:io';
import 'package:flutter/services.dart';

class OfficeDocumentRenderer {
  static const MethodChannel _channel =
      MethodChannel('docvault/office_renderer');

  static Future<String> convertToPdf({
    required String inputPath,
    required String outputPath,
  }) async {
    final inputFile = File(inputPath);

    if (!await inputFile.exists()) {
      throw Exception(
        'Office document does not exist:\n$inputPath',
      );
    }

    final extension =
        inputFile.path.toLowerCase().split('.').last;

    if (extension != 'docx' && extension != 'pptx') {
      throw Exception(
        'Only DOCX and PPTX are supported.',
      );
    }

    final result = await _channel.invokeMethod<String>(
      'convertOfficeToPdf',
      {
        'inputPath': inputPath,
        'outputPath': outputPath,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception(
        'Office document conversion failed.',
      );
    }

    final outputFile = File(result);

    if (!await outputFile.exists()) {
      throw Exception(
        'Converted PDF was not created.',
      );
    }

    final size = await outputFile.length();

    if (size == 0) {
      throw Exception(
        'Converted PDF is empty.',
      );
    }

    return result;
  }
}