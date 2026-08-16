import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  static const String _pdfDirName = 'DocVault/PDFs';
  static const String _tempDirName = 'DocVault/Temp';
  static const String _cacheDirName = 'DocVault/Cache';

  // Get PDF storage directory
  static Future<Directory> getAppDocumentsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${directory.path}/$_pdfDirName');

    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    return pdfDir;
  }

  // Get temporary directory for image processing
  static Future<Directory> getTempDirectory() async {
    final directory = await getTemporaryDirectory();
    final tempDir = Directory('${directory.path}/$_tempDirName');

    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    return tempDir;
  }

  // Get cache directory
  static Future<Directory> getCacheDirectory() async {
    final directory = await getTemporaryDirectory();
    final cacheDir = Directory('${directory.path}/$_cacheDirName');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  // Generate unique PDF file name with timestamp
  static Future<String> generatePdfFileName() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'DocVault_$timestamp.pdf';
  }

  // Get full PDF file path
  static Future<String> getFullPdfPath(String fileName) async {
    final directory = await getAppDocumentsDirectory();
    return '${directory.path}/$fileName';
  }

  // Check if PDF file exists
  static Future<bool> pdfFileExists(String filePath) async {
    return File(filePath).exists();
  }

  // Get PDF file
  static Future<File> getPdfFile(String filePath) async {
    return File(filePath);
  }

  // Get all saved PDFs
  static Future<List<File>> getAllSavedPdfs() async {
    try {
      final directory = await getAppDocumentsDirectory();
      final List<File> pdfFiles = [];

      if (await directory.exists()) {
        final entities = directory.listSync();
        for (var entity in entities) {
          if (entity is File && entity.path.endsWith('.pdf')) {
            pdfFiles.add(entity);
          }
        }
      }

      return pdfFiles;
    } catch (e) {
      return [];
    }
  }

  // Delete PDF file
  static Future<bool> deletePdfFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get PDF file size in MB
  static Future<double> getPdfFileSizeInMB(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final size = await file.length();
        return size / (1024 * 1024);
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Clear temporary directory
  static Future<void> clearTempDirectory() async {
    try {
      final directory = await getTempDirectory();
      if (await directory.exists()) {
        directory.deleteSync(recursive: true);
        await directory.create(recursive: true);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Clear cache directory
  static Future<void> clearCacheDirectory() async {
    try {
      final directory = await getCacheDirectory();
      if (await directory.exists()) {
        directory.deleteSync(recursive: true);
        await directory.create(recursive: true);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Get total storage used by PDFs
  static Future<double> getTotalStorageUsedInMB() async {
    try {
      final files = await getAllSavedPdfs();
      double totalSize = 0;

      for (var file in files) {
        final size = await file.length();
        totalSize += size;
      }

      return totalSize / (1024 * 1024);
    } catch (e) {
      return 0;
    }
  }
}
