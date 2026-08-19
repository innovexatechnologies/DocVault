import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

class FileUtils {
  static const String _pdfDirName = 'DocVault/PDFs';
  static const String _tempDirName = 'DocVault/Temp';
  static const String _cacheDirName = 'DocVault/Cache';

  /// Normalizes and cleans a user-provided or internal PDF filename:
  /// - Strips invalid filesystem characters: \ / : * ? " < > |
  /// - Strips repetitive or malformed .pdf extensions (e.g. doc.pdf.pdf -> doc.pdf)
  /// - Preserves user's actual base name, letters, digits, and spaces
  /// - Guarantees exactly one .pdf extension
  static String normalizePdfFileName(String name) {
    var clean = name.trim();
    if (clean.isEmpty) {
      return 'DocVault_Document.pdf';
    }

    // Replace illegal characters with underscore
    clean = clean.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    // Remove any trailing .pdf extensions (case-insensitive)
    final pdfRegex = RegExp(r'(\.pdf)+$', caseSensitive: false);
    clean = clean.replaceAll(pdfRegex, '');
    clean = clean.trim();

    if (clean.isEmpty) {
      clean = 'DocVault_Document';
    }

    return '$clean.pdf';
  }

  /// Extracts/rasterizes all pages of an existing PDF to temporary high-resolution images.
  /// Returns the ordered list of extracted JPEG file paths.
  static Future<List<String>> extractPdfPagesToImages(String pdfPath) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw Exception('PDF file does not exist on disk: $pdfPath');
    }

    final document = await pdfx.PdfDocument.openFile(pdfPath);
    final tempDir = await getTempDirectory();
    final sessionDir = Directory(
      '${tempDir.path}/edit_${DateTime.now().millisecondsSinceEpoch}',
    );
    await sessionDir.create(recursive: true);

    final List<String> extractedPaths = [];

    try {
      for (int i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);
        // Render at 2x resolution for crisp high-quality editing
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );

        if (pageImage != null && pageImage.bytes.isNotEmpty) {
          final pagePath = '${sessionDir.path}/page_$i.jpg';
          final pageFile = File(pagePath);
          await pageFile.writeAsBytes(pageImage.bytes, flush: true);
          extractedPaths.add(pagePath);
        }
        await page.close();
      }
    } finally {
      await document.close();
    }

    if (extractedPaths.isEmpty) {
      throw Exception('Failed to extract pages from PDF: no readable pages found.');
    }

    return extractedPaths;
  }

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
    final normalized = normalizePdfFileName(fileName);
    return '${directory.path}/$normalized';
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
