import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../../models/conversion_type.dart';

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
    return normalizeFileName(name, ConversionType.pdf);
  }

  /// Normalizes and cleans a user-provided or internal filename for any supported format:
  /// - Strips invalid filesystem characters: \ / : * ? " < > |
  /// - Strips repetitive or malformed extensions (e.g. doc.docx.docx -> doc.docx)
  /// - Guarantees exactly one extension matching the specified ConversionType
  static String normalizeFileName(String name, ConversionType type) {
    var clean = name.trim();
    final ext = type.extension;
    final defaultName = 'DocVault_Document.$ext';

    if (clean.isEmpty) {
      return defaultName;
    }

    // Replace illegal characters with underscore
    clean = clean.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    // Remove any trailing extensions for all supported types (case-insensitive)
    final extRegex = RegExp(r'(\.(pdf|docx|pptx|doc|ppt))+$', caseSensitive: false);
    clean = clean.replaceAll(extRegex, '');
    clean = clean.trim();

    if (clean.isEmpty) {
      clean = 'DocVault_Document';
    }

    return '$clean.$ext';
  }

  /// Extracts/rasterizes pages or slide images from an existing PDF, DOCX, or PPTX file.
  /// Returns the ordered list of extracted JPEG/PNG image file paths.
  static Future<List<String>> extractPagesFromDocument(String filePath) async {
    final type = ConversionType.fromFileName(filePath);
    switch (type) {
      case ConversionType.pdf:
        return await extractPdfPagesToImages(filePath);
      case ConversionType.docs:
        return await _extractDocxImages(filePath);
      case ConversionType.ppt:
        return await _extractPptxImages(filePath);
    }
  }

  /// Extracts readable text pages/slides from an Office Open XML document.
  /// This keeps text-only DOCX/PPTX files previewable without an external app.
  static Future<List<String>> extractTextPagesFromDocument(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Office document does not exist: $filePath');
    }

    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final type = ConversionType.fromFileName(filePath);

    if (type == ConversionType.docs) {
      final document = archive.findFile('word/document.xml');
      if (document == null) {
        throw Exception('Word document content was not found.');
      }

      final text = _extractXmlText(
        utf8.decode(document.content as List<int>),
        paragraphTag: 'w:p',
        textTag: 'w:t',
      );
      if (text.trim().isEmpty) {
        throw Exception('No readable text found in this Word document.');
      }
      return [text];
    }

    final slideFiles = archive
        .where((entry) =>
            entry.isFile && RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(entry.name))
        .toList()
      ..sort((a, b) => _extractNumberFromMediaName(a.name)
          .compareTo(_extractNumberFromMediaName(b.name)));

    final slides = <String>[];
    for (final slide in slideFiles) {
      final text = _extractXmlText(
        utf8.decode(slide.content as List<int>),
        textTag: 'a:t',
      );
      slides.add(text.trim());
    }

    if (slides.isEmpty || slides.every((slide) => slide.isEmpty)) {
      throw Exception('No readable text found in this presentation.');
    }
    return slides;
  }

  static String _extractXmlText(
    String xml, {
    String? paragraphTag,
    required String textTag,
  }) {
    final paragraphs = paragraphTag == null
        ? [xml]
        : RegExp('<$paragraphTag\\b[^>]*>([\\s\\S]*?)</$paragraphTag>')
            .allMatches(xml)
            .map((match) => match.group(1) ?? '')
            .toList();
    final lines = <String>[];

    for (final paragraph in paragraphs) {
      final text = RegExp('<$textTag\\b[^>]*>([\\s\\S]*?)</$textTag>')
          .allMatches(paragraph)
          .map((match) => _decodeXmlEntities(match.group(1) ?? ''))
          .join();
      if (text.trim().isNotEmpty) {
        lines.add(text.trim());
      }
    }
    return lines.join('\n\n');
  }

  static String _decodeXmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
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
      '${tempDir.path}/edit_pdf_${DateTime.now().millisecondsSinceEpoch}',
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

  /// Extracts images from a .docx file's word/media directory
  static Future<List<String>> _extractDocxImages(String docxPath) async {
    final file = File(docxPath);
    if (!await file.exists()) {
      throw Exception('Word document does not exist: $docxPath');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final tempDir = await getTempDirectory();
    final sessionDir = Directory(
      '${tempDir.path}/edit_docx_${DateTime.now().millisecondsSinceEpoch}',
    );
    await sessionDir.create(recursive: true);

    final List<ArchiveFile> mediaFiles = [];
    for (final archiveFile in archive) {
      if (archiveFile.isFile &&
          archiveFile.name.startsWith('word/media/') &&
          (archiveFile.name.toLowerCase().endsWith('.jpeg') ||
              archiveFile.name.toLowerCase().endsWith('.jpg') ||
              archiveFile.name.toLowerCase().endsWith('.png'))) {
        mediaFiles.add(archiveFile);
      }
    }

    // Sort naturally by image number (e.g. image1, image2, image10)
    mediaFiles.sort((a, b) {
      final numA = _extractNumberFromMediaName(a.name);
      final numB = _extractNumberFromMediaName(b.name);
      return numA.compareTo(numB);
    });

    final List<String> extractedPaths = [];
    for (int i = 0; i < mediaFiles.length; i++) {
      final media = mediaFiles[i];
      final ext = media.name.split('.').last;
      final outPath = '${sessionDir.path}/page_${i + 1}.$ext';
      final outFile = File(outPath);
      await outFile.writeAsBytes(media.content as List<int>, flush: true);
      extractedPaths.add(outPath);
    }

    if (extractedPaths.isEmpty) {
      throw Exception('No editable image pages found in this Word document.');
    }

    return extractedPaths;
  }

  /// Extracts slide images from a .pptx file's ppt/media directory
  static Future<List<String>> _extractPptxImages(String pptxPath) async {
    final file = File(pptxPath);
    if (!await file.exists()) {
      throw Exception('PowerPoint presentation does not exist: $pptxPath');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final tempDir = await getTempDirectory();
    final sessionDir = Directory(
      '${tempDir.path}/edit_pptx_${DateTime.now().millisecondsSinceEpoch}',
    );
    await sessionDir.create(recursive: true);

    final List<ArchiveFile> mediaFiles = [];
    for (final archiveFile in archive) {
      if (archiveFile.isFile &&
          archiveFile.name.startsWith('ppt/media/') &&
          (archiveFile.name.toLowerCase().endsWith('.jpeg') ||
              archiveFile.name.toLowerCase().endsWith('.jpg') ||
              archiveFile.name.toLowerCase().endsWith('.png'))) {
        mediaFiles.add(archiveFile);
      }
    }

    // Sort naturally by slide/image number
    mediaFiles.sort((a, b) {
      final numA = _extractNumberFromMediaName(a.name);
      final numB = _extractNumberFromMediaName(b.name);
      return numA.compareTo(numB);
    });

    final List<String> extractedPaths = [];
    for (int i = 0; i < mediaFiles.length; i++) {
      final media = mediaFiles[i];
      final ext = media.name.split('.').last;
      final outPath = '${sessionDir.path}/slide_${i + 1}.$ext';
      final outFile = File(outPath);
      await outFile.writeAsBytes(media.content as List<int>, flush: true);
      extractedPaths.add(outPath);
    }

    if (extractedPaths.isEmpty) {
      throw Exception('No slide images found in this PowerPoint presentation.');
    }

    return extractedPaths;
  }

  static int _extractNumberFromMediaName(String name) {
    final match = RegExp(r'(\d+)').firstMatch(name);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
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
  static Future<String> generatePdfFileName([ConversionType type = ConversionType.pdf]) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'DocVault_$timestamp.${type.extension}';
  }

  // Get full PDF file path
  static Future<String> getFullPdfPath(String fileName) async {
    final directory = await getAppDocumentsDirectory();
    final type = ConversionType.fromFileName(fileName);
    final normalized = normalizeFileName(fileName, type);
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

  // Get all saved PDFs/DOCS/PPTs
  static Future<List<File>> getAllSavedPdfs() async {
    try {
      final directory = await getAppDocumentsDirectory();
      final List<File> files = [];

      if (await directory.exists()) {
        final entities = directory.listSync();
        for (var entity in entities) {
          if (entity is File) {
            final pathLower = entity.path.toLowerCase();
            if (pathLower.endsWith('.pdf') ||
                pathLower.endsWith('.docx') ||
                pathLower.endsWith('.pptx')) {
              files.add(entity);
            }
          }
        }
      }

      return files;
    } catch (e) {
      return [];
    }
  }

  // Delete file
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

  // Get file size in MB
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

  // Get total storage used by saved documents
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
