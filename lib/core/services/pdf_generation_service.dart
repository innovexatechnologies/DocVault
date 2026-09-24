import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/file_utils.dart';
import 'pdf_storage_service.dart';
import '../../models/pdf_result.dart';

class PdfGenerationService {
  Future<PdfResult> generatePdfFromImages(
    List<String> imagePaths,
  ) async {
    try {
      if (imagePaths.isEmpty) {
        throw Exception('No images provided');
      }

      final startTime = DateTime.now();

      final paths = List<String>.from(imagePaths);

      // ==========================================================
      // BACKGROUND PDF GENERATION
      // ==========================================================

      final Uint8List pdfBytes = await Isolate.run(
        () => _generatePdfInBackground(paths),
      );

      if (pdfBytes.isEmpty) {
        throw Exception('Generated PDF is empty');
      }

      // ==========================================================
      // FILE NAME
      // ==========================================================

      final fileName = await FileUtils.generatePdfFileName();

      // ==========================================================
      // FILE PATH
      // ==========================================================

      final filePath = await FileUtils.getFullPdfPath(fileName);

      final file = File(filePath);

      await file.parent.create(
        recursive: true,
      );

      // ==========================================================
      // WRITE PDF
      // ==========================================================

      await file.writeAsBytes(
        pdfBytes,
        flush: true,
      );

      // ==========================================================
      // VERIFY FILE
      // ==========================================================

      if (!await file.exists()) {
        throw Exception('Failed to create PDF file');
      }

      final fileSize = await file.length();

      if (fileSize <= 0) {
        throw Exception('Generated PDF file is empty');
      }

      // ==========================================================
      // SAVE METADATA
      // ==========================================================

      await PdfStorageService().saveDocument(
        filePath: filePath,
        fileName: fileName,
        pageCount: paths.length,
      );

      debugPrint(
        'PDF generated successfully in '
        '${DateTime.now().difference(startTime).inMilliseconds} ms',
      );

      return PdfResult(
        filePath: filePath,
        fileName: fileName,
        pageCount: paths.length,
        generatedAt: startTime,
      );
    } catch (e) {
      debugPrint(
        'PDF generation error: $e',
      );

      rethrow;
    }
  }
}

// ==================================================================
// BACKGROUND PDF GENERATION
// ==================================================================

Future<Uint8List> _generatePdfInBackground(
  List<String> imagePaths,
) async {
  final pdf = pw.Document();

  const maxImageWidth = 1800;
  const maxImageHeight = 2400;

  for (int i = 0; i < imagePaths.length; i++) {
    final imagePath = imagePaths[i];

    final imageFile = File(imagePath);

    if (!imageFile.existsSync()) {
      throw Exception(
        'Image file not found: $imagePath',
      );
    }

    final originalBytes = imageFile.readAsBytesSync();

    if (originalBytes.isEmpty) {
      throw Exception(
        'Image file is empty: $imagePath',
      );
    }

    final decodedImage = img.decodeImage(originalBytes);

    if (decodedImage == null) {
      throw Exception(
        'Failed to decode image: $imagePath',
      );
    }

    if (decodedImage.width <= 0 ||
        decodedImage.height <= 0) {
      throw Exception(
        'Invalid image dimensions: $imagePath',
      );
    }

    img.Image processedImage = decodedImage;

    final needsResize =
        decodedImage.width > maxImageWidth ||
        decodedImage.height > maxImageHeight;

    if (needsResize) {
      final widthScale =
          maxImageWidth / decodedImage.width;

      final heightScale =
          maxImageHeight / decodedImage.height;

      final scale =
          widthScale < heightScale
              ? widthScale
              : heightScale;

      final newWidth =
          (decodedImage.width * scale).round();

      final newHeight =
          (decodedImage.height * scale).round();

      processedImage = img.copyResize(
        decodedImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    final jpegBytes = img.encodeJpg(
      processedImage,
      quality: 82,
    );

    if (jpegBytes.isEmpty) {
      throw Exception(
        'Failed to encode image: $imagePath',
      );
    }

    final pdfImage = pw.MemoryImage(
      Uint8List.fromList(jpegBytes),
    );

    // ==============================================================
    // FIXED: Standard A4 format with full image containment
    // ==============================================================

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Center(
            child: pw.Image(
              pdfImage,
              fit: pw.BoxFit.contain,
            ),
          );
        },
      ),
    );
  }

  final List<int> encodedPdf = await pdf.save();

  if (encodedPdf.isEmpty) {
    throw Exception(
      'Failed to encode PDF',
    );
  }

  return Uint8List.fromList(
    encodedPdf,
  );
}