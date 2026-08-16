import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  static Future<Directory> getAppDocumentsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${directory.path}/DocVault/PDFs');

    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    return pdfDir;
  }

  static Future<String> generatePdfFileName() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'DocVault_$timestamp.pdf';
  }

  static Future<String> getFullPdfPath(String fileName) async {
    final directory = await getAppDocumentsDirectory();
    return '${directory.path}/$fileName';
  }

  static Future<bool> pdfFileExists(String filePath) async {
    return File(filePath).exists();
  }

  static Future<File> getPdfFile(String filePath) async {
    return File(filePath);
  }
}
