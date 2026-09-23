import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  // Filtered Image se text extract karna
  Future<String> extractTextFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  // Text ko PDF mein convert karna
  Future<File> generatePdfFromText(String text) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 14),
            ),
          );
        },
      ),
    );

    final outputDir = await getApplicationDocumentsDirectory();
    final file = File("${outputDir.path}/OCR_Doc_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  void dispose() {
    _textRecognizer.close();
  }
}