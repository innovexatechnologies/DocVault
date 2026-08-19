import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import '../utils/file_utils.dart';
import 'pdf_storage_service.dart';
import '../../models/pdf_result.dart';

class PdfGenerationService {
  Future<PdfResult> generatePdfFromImages(List<String> imagePaths) async {
    try {
      if (imagePaths.isEmpty) {
        throw Exception('No images provided');
      }

      final pdf = pw.Document();

      // Load and add each image as a separate page
      for (final imagePath in imagePaths) {
        final imageFile = File(imagePath);

        if (!await imageFile.exists()) {
          throw Exception('Image file not found: $imagePath');
        }

        // Read image
        final imageBytes = await imageFile.readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        // Get image dimensions to maintain aspect ratio
        final decodedImage = img.decodeImage(imageBytes);
        if (decodedImage == null) {
          throw Exception('Failed to decode image: $imagePath');
        }

        final imageWidth = decodedImage.width.toDouble();
        final imageHeight = decodedImage.height.toDouble();

        // Calculate dimensions for A4 page
        final pageWidth = PdfPageFormat.a4.width;
        final pageHeight = PdfPageFormat.a4.height;
        const margin = 20.0;

        final availableWidth = pageWidth - (margin * 2);
        final availableHeight = pageHeight - (margin * 2);

        // Maintain aspect ratio
        double fitWidth = availableWidth;
        double fitHeight = (availableWidth * imageHeight) / imageWidth;

        if (fitHeight > availableHeight) {
          fitHeight = availableHeight;
          fitWidth = (availableHeight * imageWidth) / imageHeight;
        }

        // Add page with image
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) {
              return pw.Center(
                child: pw.Image(image, width: fitWidth, height: fitHeight),
              );
            },
          ),
        );
      }

      // Save PDF to app-private storage
      final fileName = await FileUtils.generatePdfFileName();
      final filePath = await FileUtils.getFullPdfPath(fileName);
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Register persistent metadata
      await PdfStorageService().saveDocument(
        filePath: filePath,
        fileName: fileName,
        pageCount: imagePaths.length,
      );

      return PdfResult(
        filePath: filePath,
        fileName: fileName,
        pageCount: imagePaths.length,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('PDF generation error: $e');
      rethrow;
    }
  }
}
