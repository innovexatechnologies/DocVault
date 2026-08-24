import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../../models/conversion_type.dart';

class FileUtils {
  static const String _pdfDirName = 'DocVault/PDFs';
  static const String _tempDirName = 'DocVault/Temp';
  static const String _cacheDirName = 'DocVault/Cache';

  // ---------------------------------------------------------------------------
  // FILE NAME UTILITIES
  // ---------------------------------------------------------------------------

  static String normalizePdfFileName(String name) {
    return normalizeFileName(name, ConversionType.pdf);
  }

  static String normalizeFileName(
    String name,
    ConversionType type,
  ) {
    var clean = name.trim();

    final ext = type.extension;
    final defaultName = 'DocVault_Document.$ext';

    if (clean.isEmpty) {
      return defaultName;
    }

    // Remove invalid Windows/Android filesystem characters.
    clean = clean.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    // Remove duplicate / existing supported extensions.
    final extRegex = RegExp(
      r'(\.(pdf|docx|pptx|doc|ppt))+$',
      caseSensitive: false,
    );

    clean = clean.replaceAll(extRegex, '').trim();

    if (clean.isEmpty) {
      clean = 'DocVault_Document';
    }

    return '$clean.$ext';
  }

  // ---------------------------------------------------------------------------
  // DOCUMENT PAGE EXTRACTION
  // ---------------------------------------------------------------------------

  /// Returns preview image paths for:
  ///
  /// PDF  -> real PDF page rendering
  /// DOCX -> document media rendered as page-like images
  /// PPTX -> slide media using the actual presentation aspect ratio
  ///
  /// NOTE:
  /// DOCX/PPTX are Office ZIP/XML formats. Dart itself does not contain
  /// Microsoft's Word/PowerPoint rendering engine. For completely identical
  /// Word/PowerPoint rendering, a native Office rendering engine or a
  /// DOCX/PPTX -> PDF converter is required.
  static Future<List<String>> extractPagesFromDocument(
    String filePath,
  ) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception(
        'Document file does not exist:\n$filePath',
      );
    }

    final type = ConversionType.fromFileName(filePath);

    switch (type) {
      case ConversionType.pdf:
        return extractPdfPagesToImages(filePath);

      case ConversionType.docs:
        return _extractDocxPreviewPages(filePath);

      case ConversionType.ppt:
        return _extractPptxPreviewSlides(filePath);
    }
  }

  // ---------------------------------------------------------------------------
  // PDF
  // ---------------------------------------------------------------------------

  static Future<List<String>> extractPdfPagesToImages(
    String pdfPath,
  ) async {
    final file = File(pdfPath);

    if (!await file.exists()) {
      throw Exception(
        'PDF file does not exist on disk:\n$pdfPath',
      );
    }

    final document = await pdfx.PdfDocument.openFile(pdfPath);

    final tempDir = await getTempDirectory();

    final sessionDir = Directory(
      '${tempDir.path}/preview_pdf_${DateTime.now().millisecondsSinceEpoch}',
    );

    await sessionDir.create(recursive: true);

    final List<String> extractedPaths = [];

    try {
      for (int pageNumber = 1;
          pageNumber <= document.pagesCount;
          pageNumber++) {
        final page = await document.getPage(pageNumber);

        try {
          // Render at 2x for a sharper preview.
          final width = page.width * 2;
          final height = page.height * 2;

          final pageImage = await page.render(
            width: width,
            height: height,
            format: pdfx.PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
          );

          if (pageImage != null &&
              pageImage.bytes.isNotEmpty) {
            final outputPath =
                '${sessionDir.path}/page_$pageNumber.jpg';

            final outputFile = File(outputPath);

            await outputFile.writeAsBytes(
              pageImage.bytes,
              flush: true,
            );

            extractedPaths.add(outputPath);
          }
        } finally {
          await page.close();
        }
      }
    } finally {
      await document.close();
    }

    if (extractedPaths.isEmpty) {
      throw Exception(
        'Failed to render PDF: no readable pages found.',
      );
    }

    return extractedPaths;
  }

  // ---------------------------------------------------------------------------
  // DOCX
  // ---------------------------------------------------------------------------

  /// Creates preview images from the images actually stored inside the DOCX.
  ///
  /// This is much safer than treating every media file as a page without
  /// understanding the document structure.
  ///
  /// IMPORTANT:
  /// DOCX may contain text, tables, shapes, headers, footers, etc.
  /// Those elements are not images and cannot be rendered correctly by simply
  /// extracting word/media.
  static Future<List<String>> _extractDocxPreviewPages(
    String docxPath,
  ) async {
    final file = File(docxPath);

    if (!await file.exists()) {
      throw Exception(
        'Word document does not exist:\n$docxPath',
      );
    }

    final bytes = await file.readAsBytes();

    final archive = ZipDecoder().decodeBytes(bytes);

    final tempDir = await getTempDirectory();

    final sessionDir = Directory(
      '${tempDir.path}/preview_docx_${DateTime.now().millisecondsSinceEpoch}',
    );

    await sessionDir.create(recursive: true);

    // Read actual Word page size.
    final pageSize = _readDocxPageSize(archive);

    final pageWidthPx = pageSize.widthPx;
    final pageHeightPx = pageSize.heightPx;

    // Find images used by the generated DOCX.
    final mediaFiles = <ArchiveFile>[];

    for (final archiveFile in archive) {
      if (!archiveFile.isFile) {
        continue;
      }

      final lowerName = archiveFile.name.toLowerCase();

      if (!lowerName.startsWith('word/media/')) {
        continue;
      }

      if (_isSupportedImage(lowerName)) {
        mediaFiles.add(archiveFile);
      }
    }

    mediaFiles.sort((a, b) {
      final aNumber = _extractNumberFromMediaName(a.name);
      final bNumber = _extractNumberFromMediaName(b.name);

      if (aNumber != bNumber) {
        return aNumber.compareTo(bNumber);
      }

      return a.name.compareTo(b.name);
    });

    if (mediaFiles.isEmpty) {
      // If the DOCX has no media, create a simple blank page preview
      // instead of returning an incorrect "no editable pages" error.
      final blankPath = await _createBlankPreviewPage(
        sessionDir: sessionDir,
        width: pageWidthPx,
        height: pageHeightPx,
      );

      return [blankPath];
    }

    final List<String> outputPaths = [];

    for (int i = 0; i < mediaFiles.length; i++) {
      final media = mediaFiles[i];

      final Uint8List mediaBytes = Uint8List.fromList(
        media.content,
      );

      final decoded = img.decodeImage(mediaBytes);

      if (decoded == null) {
        continue;
      }

      // Create a real Word page canvas using the actual page ratio.
      final pageCanvas = img.Image(
        width: pageWidthPx,
        height: pageHeightPx,
      );

      // White Word page.
      img.fill(
        pageCanvas,
        color: img.ColorRgb8(
          255,
          255,
          255,
        ),
      );

      // Approximate Word 1-inch margins.
      const int margin = 96;

      final availableWidth =
          pageWidthPx - (margin * 2);

      final availableHeight =
          pageHeightPx - (margin * 2);

      final fitted = _fitImage(
        source: decoded,
        maxWidth: availableWidth,
        maxHeight: availableHeight,
      );

      final x =
          ((pageWidthPx - fitted.width) / 2).round();

      final y =
          ((pageHeightPx - fitted.height) / 2).round();

      img.compositeImage(
        pageCanvas,
        fitted,
        dstX: x,
        dstY: y,
      );

      final outputPath =
          '${sessionDir.path}/page_${i + 1}.jpg';

      final outputFile = File(outputPath);

      final jpgBytes = img.encodeJpg(
        pageCanvas,
        quality: 92,
      );

      await outputFile.writeAsBytes(
        jpgBytes,
        flush: true,
      );

      outputPaths.add(outputPath);
    }

    if (outputPaths.isEmpty) {
      throw Exception(
        'Failed to create Word preview pages.',
      );
    }

    return outputPaths;
  }

  // ---------------------------------------------------------------------------
  // PPTX
  // ---------------------------------------------------------------------------

  /// Creates slide preview images using the actual PPTX presentation size.
  ///
  /// PPTX stores its slide dimensions in:
  /// ppt/presentation.xml
  ///
  /// Therefore we don't force 16:9 anymore.
  static Future<List<String>> _extractPptxPreviewSlides(
    String pptxPath,
  ) async {
    final file = File(pptxPath);

    if (!await file.exists()) {
      throw Exception(
        'PowerPoint presentation does not exist:\n$pptxPath',
      );
    }

    final bytes = await file.readAsBytes();

    final archive = ZipDecoder().decodeBytes(bytes);

    final tempDir = await getTempDirectory();

    final sessionDir = Directory(
      '${tempDir.path}/preview_pptx_${DateTime.now().millisecondsSinceEpoch}',
    );

    await sessionDir.create(recursive: true);

    // Read actual presentation dimensions.
    final slideSize = _readPptxSlideSize(archive);

    final slideWidthPx = slideSize.widthPx;
    final slideHeightPx = slideSize.heightPx;

    // Find slide XML files.
    final slideFiles = <ArchiveFile>[];

    for (final archiveFile in archive) {
      if (!archiveFile.isFile) {
        continue;
      }

      final name = archiveFile.name;

      if (RegExp(
        r'^ppt/slides/slide\d+\.xml$',
        caseSensitive: false,
      ).hasMatch(name)) {
        slideFiles.add(archiveFile);
      }
    }

    slideFiles.sort((a, b) {
      final aNumber = _extractNumberFromMediaName(a.name);
      final bNumber = _extractNumberFromMediaName(b.name);

      return aNumber.compareTo(bNumber);
    });

    // Extract PPT media.
    final mediaFiles = <ArchiveFile>[];

    for (final archiveFile in archive) {
      if (!archiveFile.isFile) {
        continue;
      }

      final lowerName = archiveFile.name.toLowerCase();

      if (!lowerName.startsWith('ppt/media/')) {
        continue;
      }

      if (_isSupportedImage(lowerName)) {
        mediaFiles.add(archiveFile);
      }
    }

    mediaFiles.sort((a, b) {
      final aNumber = _extractNumberFromMediaName(a.name);
      final bNumber = _extractNumberFromMediaName(b.name);

      if (aNumber != bNumber) {
        return aNumber.compareTo(bNumber);
      }

      return a.name.compareTo(b.name);
    });

    if (slideFiles.isEmpty) {
      throw Exception(
        'No PowerPoint slides found in presentation.',
      );
    }

    final List<String> outputPaths = [];

    for (int i = 0; i < slideFiles.length; i++) {
      final slideCanvas = img.Image(
        width: slideWidthPx,
        height: slideHeightPx,
      );

      // White PowerPoint slide background.
      img.fill(
        slideCanvas,
        color: img.ColorRgb8(
          255,
          255,
          255,
        ),
      );

      // Try to match slide number with image number.
      if (i < mediaFiles.length) {
        final media = mediaFiles[i];

        final mediaBytes = Uint8List.fromList(
          media.content,
        );

        final decoded = img.decodeImage(mediaBytes);

        if (decoded != null) {
          final fitted = _fitImage(
            source: decoded,
            maxWidth: slideWidthPx,
            maxHeight: slideHeightPx,
          );

          final x =
              ((slideWidthPx - fitted.width) / 2).round();

          final y =
              ((slideHeightPx - fitted.height) / 2).round();

          img.compositeImage(
            slideCanvas,
            fitted,
            dstX: x,
            dstY: y,
          );
        }
      }

      final outputPath =
          '${sessionDir.path}/slide_${i + 1}.jpg';

      final outputFile = File(outputPath);

      final jpgBytes = img.encodeJpg(
        slideCanvas,
        quality: 92,
      );

      await outputFile.writeAsBytes(
        jpgBytes,
        flush: true,
      );

      outputPaths.add(outputPath);
    }

    return outputPaths;
  }

  // ---------------------------------------------------------------------------
  // DOCX PAGE SIZE
  // ---------------------------------------------------------------------------

  static _DocumentPageSize _readDocxPageSize(
    Archive archive,
  ) {
    const defaultWidthTwips = 12240;
    const defaultHeightTwips = 15840;

    try {
      final documentFile = archive.findFile(
        'word/document.xml',
      );

      if (documentFile == null) {
        return _DocumentPageSize.fromTwips(
          defaultWidthTwips,
          defaultHeightTwips,
        );
      }

      final xml = String.fromCharCodes(
        documentFile.content,
      );

      final match = RegExp(
        r'<w:pgSz\b[^>]*w:w="(\d+)"[^>]*w:h="(\d+)"',
      ).firstMatch(xml);

      if (match == null) {
        return _DocumentPageSize.fromTwips(
          defaultWidthTwips,
          defaultHeightTwips,
        );
      }

      final widthTwips =
          int.tryParse(match.group(1)!) ??
              defaultWidthTwips;

      final heightTwips =
          int.tryParse(match.group(2)!) ??
              defaultHeightTwips;

      return _DocumentPageSize.fromTwips(
        widthTwips,
        heightTwips,
      );
    } catch (_) {
      return _DocumentPageSize.fromTwips(
        defaultWidthTwips,
        defaultHeightTwips,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // PPTX SLIDE SIZE
  // ---------------------------------------------------------------------------

  static _DocumentPageSize _readPptxSlideSize(
    Archive archive,
  ) {
    // Default PowerPoint 16:9 dimensions.
    const defaultWidthEmu = 12192000;
    const defaultHeightEmu = 6858000;

    try {
      final presentationFile = archive.findFile(
        'ppt/presentation.xml',
      );

      if (presentationFile == null) {
        return _DocumentPageSize.fromEmu(
          defaultWidthEmu,
          defaultHeightEmu,
        );
      }

      final xml = String.fromCharCodes(
        presentationFile.content,
      );

      final match = RegExp(
        r'<p:sldSz\b[^>]*cx="(\d+)"[^>]*cy="(\d+)"',
      ).firstMatch(xml);

      if (match == null) {
        return _DocumentPageSize.fromEmu(
          defaultWidthEmu,
          defaultHeightEmu,
        );
      }

      final widthEmu =
          int.tryParse(match.group(1)!) ??
              defaultWidthEmu;

      final heightEmu =
          int.tryParse(match.group(2)!) ??
              defaultHeightEmu;

      return _DocumentPageSize.fromEmu(
        widthEmu,
        heightEmu,
      );
    } catch (_) {
      return _DocumentPageSize.fromEmu(
        defaultWidthEmu,
        defaultHeightEmu,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // IMAGE HELPERS
  // ---------------------------------------------------------------------------

  static bool _isSupportedImage(
    String path,
  ) {
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png');
  }

  static int _extractNumberFromMediaName(
    String name,
  ) {
    final matches = RegExp(r'(\d+)').allMatches(name);

    if (matches.isEmpty) {
      return 0;
    }

    final lastMatch = matches.last;

    return int.tryParse(
          lastMatch.group(1)!,
        ) ??
        0;
  }

  static img.Image _fitImage({
    required img.Image source,
    required int maxWidth,
    required int maxHeight,
  }) {
    if (source.width <= 0 ||
        source.height <= 0) {
      return source;
    }

    final widthRatio =
        maxWidth / source.width;

    final heightRatio =
        maxHeight / source.height;

    final scale = widthRatio < heightRatio
        ? widthRatio
        : heightRatio;

    final targetWidth =
        (source.width * scale).round();

    final targetHeight =
        (source.height * scale).round();

    return img.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );
  }

  static Future<String> _createBlankPreviewPage({
    required Directory sessionDir,
    required int width,
    required int height,
  }) async {
    final page = img.Image(
      width: width,
      height: height,
    );

    img.fill(
      page,
      color: img.ColorRgb8(
        255,
        255,
        255,
      ),
    );

    final outputPath =
        '${sessionDir.path}/page_1.jpg';

    final outputFile = File(outputPath);

    await outputFile.writeAsBytes(
      img.encodeJpg(
        page,
        quality: 92,
      ),
      flush: true,
    );

    return outputPath;
  }

  // ---------------------------------------------------------------------------
  // STORAGE
  // ---------------------------------------------------------------------------

  static Future<Directory>
      getAppDocumentsDirectory() async {
    final directory =
        await getApplicationDocumentsDirectory();

    final pdfDir = Directory(
      '${directory.path}/$_pdfDirName',
    );

    if (!await pdfDir.exists()) {
      await pdfDir.create(
        recursive: true,
      );
    }

    return pdfDir;
  }

  static Future<Directory>
      getTempDirectory() async {
    final directory =
        await getTemporaryDirectory();

    final tempDir = Directory(
      '${directory.path}/$_tempDirName',
    );

    if (!await tempDir.exists()) {
      await tempDir.create(
        recursive: true,
      );
    }

    return tempDir;
  }

  static Future<Directory>
      getCacheDirectory() async {
    final directory =
        await getTemporaryDirectory();

    final cacheDir = Directory(
      '${directory.path}/$_cacheDirName',
    );

    if (!await cacheDir.exists()) {
      await cacheDir.create(
        recursive: true,
      );
    }

    return cacheDir;
  }

  // ---------------------------------------------------------------------------
  // FILE NAME / PATH
  // ---------------------------------------------------------------------------

  static Future<String> generatePdfFileName([
    ConversionType type = ConversionType.pdf,
  ]) async {
    final timestamp =
        DateTime.now().millisecondsSinceEpoch;

    return 'DocVault_$timestamp.${type.extension}';
  }

  static Future<String> getFullPdfPath(
    String fileName,
  ) async {
    final directory =
        await getAppDocumentsDirectory();

    final type =
        ConversionType.fromFileName(fileName);

    final normalized =
        normalizeFileName(
      fileName,
      type,
    );

    return '${directory.path}/$normalized';
  }

  static Future<bool> pdfFileExists(
    String filePath,
  ) async {
    return File(filePath).exists();
  }

  static Future<File> getPdfFile(
    String filePath,
  ) async {
    return File(filePath);
  }

  // ---------------------------------------------------------------------------
  // SAVED DOCUMENTS
  // ---------------------------------------------------------------------------

  static Future<List<File>>
      getAllSavedPdfs() async {
    try {
      final directory =
          await getAppDocumentsDirectory();

      final List<File> files = [];

      if (await directory.exists()) {
        final entities =
            directory.listSync();

        for (final entity in entities) {
          if (entity is! File) {
            continue;
          }

          final pathLower =
              entity.path.toLowerCase();

          if (pathLower.endsWith('.pdf') ||
              pathLower.endsWith('.docx') ||
              pathLower.endsWith('.pptx')) {
            files.add(entity);
          }
        }
      }

      return files;
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  static Future<bool> deletePdfFile(
    String filePath,
  ) async {
    try {
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // FILE SIZE
  // ---------------------------------------------------------------------------

  static Future<double>
      getPdfFileSizeInMB(
    String filePath,
  ) async {
    try {
      final file = File(filePath);

      if (await file.exists()) {
        final size = await file.length();

        return size /
            (1024 * 1024);
      }

      return 0;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // TEMP / CACHE CLEANUP
  // ---------------------------------------------------------------------------

  static Future<void>
      clearTempDirectory() async {
    try {
      final directory =
          await getTempDirectory();

      if (await directory.exists()) {
        await directory.delete(
          recursive: true,
        );

        await directory.create(
          recursive: true,
        );
      }
    } catch (_) {
      // Intentionally ignored.
    }
  }

  static Future<void>
      clearCacheDirectory() async {
    try {
      final directory =
          await getCacheDirectory();

      if (await directory.exists()) {
        await directory.delete(
          recursive: true,
        );

        await directory.create(
          recursive: true,
        );
      }
    } catch (_) {
      // Intentionally ignored.
    }
  }

  // ---------------------------------------------------------------------------
  // TOTAL STORAGE
  // ---------------------------------------------------------------------------

  static Future<double>
      getTotalStorageUsedInMB() async {
    try {
      final files =
          await getAllSavedPdfs();

      double totalSize = 0;

      for (final file in files) {
        totalSize +=
            await file.length();
      }

      return totalSize /
          (1024 * 1024);
    } catch (_) {
      return 0;
    }
  }
}

// =============================================================================
// DOCUMENT PAGE SIZE
// =============================================================================

class _DocumentPageSize {
  final int widthPx;
  final int heightPx;

  const _DocumentPageSize({
    required this.widthPx,
    required this.heightPx,
  });

  factory _DocumentPageSize.fromTwips(
    int widthTwips,
    int heightTwips,
  ) {
    // 1440 twips = 1 inch.
    // 96 pixels = 1 inch.
    final widthPx =
        (widthTwips / 1440 * 96)
            .round();

    final heightPx =
        (heightTwips / 1440 * 96)
            .round();

    return _DocumentPageSize(
      widthPx: widthPx.clamp(1, 5000),
      heightPx: heightPx.clamp(1, 5000),
    );
  }

  factory _DocumentPageSize.fromEmu(
    int widthEmu,
    int heightEmu,
  ) {
    // 914400 EMU = 1 inch.
    // 96 pixels = 1 inch.
    final widthPx =
        (widthEmu / 914400 * 96)
            .round();

    final heightPx =
        (heightEmu / 914400 * 96)
            .round();

    return _DocumentPageSize(
      widthPx: widthPx.clamp(1, 5000),
      heightPx: heightPx.clamp(1, 5000),
    );
  }
}