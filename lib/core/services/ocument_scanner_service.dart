import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class DocumentScannerService {
  /// 1. CamScanner-Style Auto Crop & Document Scanner
  /// Google ML Kit Document Scanner UI launch karta hai (auto-edge detection, crop & filter)
  static Future<List<String>?> scanDocument({int pageLimit = 10}) async {
    // Latest ML Kit options: default options handle JPEG and full auto-crop mode
    final options = DocumentScannerOptions(
      pageLimit: pageLimit,
    );

    final documentScanner = DocumentScanner(options: options);

    try {
      final result = await documentScanner.scanDocument();
      return result.images; // Scanned aur cropped images ke file paths
    } catch (e) {
      debugPrint("Document scanning error: $e");
      return null;
    }
  }

  /// 2. Extract Text From Image (OCR / Text Scanner)
  /// Image file path leta hai aur page par likha saara text extract karke String return karta hai
  static Future<String?> extractTextFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      return recognizedText.text; // Extracted text string
    } catch (e) {
      debugPrint("Text extraction error: $e");
      await textRecognizer.close();
      return null;
    }
  }
}