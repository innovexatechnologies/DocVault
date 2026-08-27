import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

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

      // Make a separate copy before sending data to isolate.
      final paths = List<String>.from(imagePaths);

      // ==========================================================
      // HEAVY PDF GENERATION
      // ==========================================================
      //
      // All CPU-heavy work runs in a background isolate.
      // This keeps Flutter UI responsive.
      //
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
        throw Exception(
          'Failed to create PDF file',
        );
      }

      final fileSize = await file.length();

      if (fileSize <= 0) {
        throw Exception(
          'Generated PDF file is empty',
        );
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

  // ================================================================
  // PDF PAGE SETTINGS
  // ================================================================

  final pageWidth = PdfPageFormat.a4.width;
  final pageHeight = PdfPageFormat.a4.height;

  const margin = 20.0;

  final availableWidth =
      pageWidth - (margin * 2);

  final availableHeight =
      pageHeight - (margin * 2);

  // ================================================================
  // IMAGE LIMIT
  // ================================================================
  //
  // Phone camera images can easily be:
  //
  // 4000 x 3000
  // 6000 x 4000
  // 8000 x 6000
  //
  // Putting these original images directly into PDF makes
  // generation much slower and creates unnecessarily large PDFs.
  //
  // 1800 px is enough for good document/PDF quality.
  //

  const maxImageWidth = 1800;
  const maxImageHeight = 2400;

  // ================================================================
  // PROCESS EACH IMAGE
  // ================================================================

  for (int i = 0; i < imagePaths.length; i++) {
    final imagePath = imagePaths[i];

    final imageFile = File(imagePath);

    if (!imageFile.existsSync()) {
      throw Exception(
        'Image file not found: $imagePath',
      );
    }

    // --------------------------------------------------------------
    // READ IMAGE
    // --------------------------------------------------------------

    final originalBytes =
        imageFile.readAsBytesSync();

    if (originalBytes.isEmpty) {
      throw Exception(
        'Image file is empty: $imagePath',
      );
    }

    // --------------------------------------------------------------
    // DECODE IMAGE
    // --------------------------------------------------------------

    final decodedImage =
        img.decodeImage(originalBytes);

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

    // --------------------------------------------------------------
    // RESIZE LARGE IMAGE
    // --------------------------------------------------------------

    img.Image processedImage =
        decodedImage;

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

    // --------------------------------------------------------------
    // ENCODE JPEG
    // --------------------------------------------------------------
    //
    // JPEG is much smaller than raw PNG/photo data.
    //
    // Quality 82 gives a good balance between:
    //
    // - Speed
    // - Quality
    // - PDF size
    //

    final jpegBytes = img.encodeJpg(
      processedImage,
      quality: 82,
    );

    if (jpegBytes.isEmpty) {
      throw Exception(
        'Failed to encode image: $imagePath',
      );
    }

    // --------------------------------------------------------------
    // PDF IMAGE
    // --------------------------------------------------------------

    final pdfImage = pw.MemoryImage(
      Uint8List.fromList(jpegBytes),
    );

    // --------------------------------------------------------------
    // IMAGE DIMENSIONS
    // --------------------------------------------------------------

    final imageWidth =
        processedImage.width.toDouble();

    final imageHeight =
        processedImage.height.toDouble();

    // --------------------------------------------------------------
    // FIT IMAGE INTO A4
    // --------------------------------------------------------------

    double fitWidth = availableWidth;

    double fitHeight =
        (availableWidth * imageHeight) /
        imageWidth;

    if (fitHeight > availableHeight) {
      fitHeight = availableHeight;

      fitWidth =
          (availableHeight * imageWidth) /
          imageHeight;
    }

    // --------------------------------------------------------------
    // ADD PAGE
    // --------------------------------------------------------------

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(
          margin,
        ),
        build: (context) {
          return pw.Center(
            child: pw.Image(
              pdfImage,
              width: fitWidth,
              height: fitHeight,
              fit: pw.BoxFit.contain,
            ),
          );
        },
      ),
    );
  }

  // ================================================================
  // ENCODE PDF
  // ================================================================
  //
  // IMPORTANT:
  //
  // pdf.save() is CPU-heavy.
  // It is intentionally executed inside this isolate.
  //

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