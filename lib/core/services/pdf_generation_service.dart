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

  // ================================================================
  // PDF PAGE BASE WIDTH
  // ================================================================
  //
  // We use A4 width as the base physical width.
  //
  // IMPORTANT:
  // Height is calculated from the ORIGINAL IMAGE ASPECT RATIO.
  //
  // Therefore:
  //
  // image ratio == PDF page ratio
  //
  // No unnecessary white margins.
  //

  final basePageWidth = PdfPageFormat.a4.width;

  // ================================================================
  // IMAGE LIMIT
  // ================================================================

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

    final originalBytes = imageFile.readAsBytesSync();

    if (originalBytes.isEmpty) {
      throw Exception(
        'Image file is empty: $imagePath',
      );
    }

    // --------------------------------------------------------------
    // DECODE IMAGE
    // --------------------------------------------------------------

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

    // --------------------------------------------------------------
    // RESIZE LARGE IMAGE
    // --------------------------------------------------------------

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

    // --------------------------------------------------------------
    // ENCODE JPEG
    // --------------------------------------------------------------

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

    // ==============================================================
    // CALCULATE EXACT PAGE SIZE
    // ==============================================================
    //
    // This is the IMPORTANT FIX.
    //
    // Instead of:
    //
    // A4 width + A4 height
    //
    // we calculate the PDF height from the image ratio.
    //
    // Example:
    //
    // Image = 1080 x 1920
    //
    // Page width  = 595.28
    // Page height = 595.28 * 1920 / 1080
    //
    // So PDF page has exactly the same ratio as the image.
    //

    final imageWidth =
        processedImage.width.toDouble();

    final imageHeight =
        processedImage.height.toDouble();

    final pageWidth = basePageWidth;

    final pageHeight =
        pageWidth *
        imageHeight /
        imageWidth;

    // --------------------------------------------------------------
    // CUSTOM PAGE FORMAT
    // --------------------------------------------------------------

    final pageFormat = PdfPageFormat(
      pageWidth,
      pageHeight,
    );

    // --------------------------------------------------------------
    // ADD IMAGE AS FULL PAGE
    // --------------------------------------------------------------

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.SizedBox(
            width: pageWidth,
            height: pageHeight,
            child: pw.Image(
              pdfImage,
              width: pageWidth,
              height: pageHeight,
              fit: pw.BoxFit.fill,
            ),
          );
        },
      ),
    );
  }

  // ================================================================
  // SAVE PDF
  // ================================================================

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