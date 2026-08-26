import 'dart:convert';
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

  // ===========================================================================
  // FILE NAME UTILITIES
  // ===========================================================================

  static String normalizePdfFileName(String name) {
    return normalizeFileName(
      name,
      ConversionType.pdf,
    );
  }

  static String normalizeFileName(
    String name,
    ConversionType type,
  ) {
    var clean = name.trim();

    final extension = type.extension;
    final defaultName = 'DocVault_Document.$extension';

    if (clean.isEmpty) {
      return defaultName;
    }

    // Remove invalid filesystem characters.
    clean = clean.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    // Remove existing supported extensions.
    clean = clean.replaceAll(
      RegExp(
        r'(\.(pdf|docx|pptx|doc|ppt))+$',
        caseSensitive: false,
      ),
      '',
    ).trim();

    if (clean.isEmpty) {
      clean = 'DocVault_Document';
    }

    return '$clean.$extension';
  }

  // ===========================================================================
  // DOCUMENT PAGE EXTRACTION
  // ===========================================================================

  /// Extracts preview pages from PDF, DOCX or PPTX.
  ///
  /// PDF:
  ///   Renders every real PDF page.
  ///
  /// DOCX:
  ///   Creates page-like previews from embedded images.
  ///
  /// PPTX:
  ///   Creates slide-like previews from embedded images.
  ///
  /// IMPORTANT:
  /// Dart does not contain Microsoft's Word/PowerPoint rendering engine.
  /// Therefore DOCX/PPTX cannot be rendered 100% identically to Microsoft
  /// Office using ZIP/XML parsing alone.
  static Future<List<String>> extractPagesFromDocument(
    String filePath,
  ) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception(
        'Document file does not exist:\n$filePath',
      );
    }

    final type = ConversionType.fromFileName(
      filePath,
    );

    switch (type) {
      case ConversionType.pdf:
        return extractPdfPagesToImages(
          filePath,
        );

      case ConversionType.docs:
        return _extractDocxPreviewPages(
          filePath,
        );

      case ConversionType.ppt:
        return _extractPptxPreviewSlides(
          filePath,
        );
    }
  }

  // ===========================================================================
  // TEXT EXTRACTION
  // ===========================================================================

  /// Extracts readable text from DOCX/PPTX.
  ///
  /// DOCX:
  ///   Returns one text page containing document paragraphs.
  ///
  /// PPTX:
  ///   Returns one text page per slide.
  static Future<List<String>>
      extractTextPagesFromDocument(
    String filePath,
  ) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception(
        'Office document does not exist:\n$filePath',
      );
    }

    final archive = ZipDecoder().decodeBytes(
      await file.readAsBytes(),
    );

    final type = ConversionType.fromFileName(
      filePath,
    );

    // -------------------------------------------------------------------------
    // DOCX
    // -------------------------------------------------------------------------

    if (type == ConversionType.docs) {
      final documentFile = archive.findFile(
        'word/document.xml',
      );

      if (documentFile == null) {
        throw Exception(
          'Word document content was not found.',
        );
      }

      final xml = utf8.decode(
        documentFile.content,
      );

      final text = _extractXmlText(
        xml,
        paragraphTag: 'w:p',
        textTag: 'w:t',
      );

      if (text.trim().isEmpty) {
        throw Exception(
          'No readable text found in this Word document.',
        );
      }

      return [text];
    }

    // -------------------------------------------------------------------------
    // PPTX
    // -------------------------------------------------------------------------

    final slideFiles = archive
        .where(
          (entry) =>
              entry.isFile &&
              RegExp(
                r'^ppt/slides/slide\d+\.xml$',
                caseSensitive: false,
              ).hasMatch(entry.name),
        )
        .toList();

    slideFiles.sort(
      (a, b) => _extractNumberFromMediaName(
        a.name,
      ).compareTo(
        _extractNumberFromMediaName(
          b.name,
        ),
      ),
    );

    final slides = <String>[];

    for (final slide in slideFiles) {
      final xml = utf8.decode(
        slide.content,
      );

      final text = _extractXmlText(
        xml,
        textTag: 'a:t',
      );

      slides.add(
        text.trim(),
      );
    }

    if (slides.isEmpty ||
        slides.every(
          (slide) => slide.isEmpty,
        )) {
      throw Exception(
        'No readable text found in this presentation.',
      );
    }

    return slides;
  }

  static String _extractXmlText(
    String xml, {
    String? paragraphTag,
    required String textTag,
  }) {
    final List<String> paragraphs;

    if (paragraphTag == null) {
      paragraphs = [xml];
    } else {
      paragraphs = RegExp(
        '<$paragraphTag\\b[^>]*>([\\s\\S]*?)'
        '</$paragraphTag>',
      )
          .allMatches(xml)
          .map(
            (match) => match.group(1) ?? '',
          )
          .toList();
    }

    final lines = <String>[];

    for (final paragraph in paragraphs) {
      final text = RegExp(
        '<$textTag\\b[^>]*>([\\s\\S]*?)'
        '</$textTag>',
      )
          .allMatches(paragraph)
          .map(
            (match) => _decodeXmlEntities(
              match.group(1) ?? '',
            ),
          )
          .join();

      if (text.trim().isNotEmpty) {
        lines.add(
          text.trim(),
        );
      }
    }

    return lines.join('\n\n');
  }

  static String _decodeXmlEntities(
    String text,
  ) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  // ===========================================================================
  // PDF → IMAGES
  // ===========================================================================

  /// Renders every PDF page into a high-resolution JPEG image.
  static Future<List<String>>
      extractPdfPagesToImages(
    String pdfPath,
  ) async {
    final file = File(pdfPath);

    if (!await file.exists()) {
      throw Exception(
        'PDF file does not exist on disk:\n$pdfPath',
      );
    }

    final document = await pdfx.PdfDocument.openFile(
      pdfPath,
    );

    final tempDir = await getTempDirectory();

    final sessionDir = Directory(
      '${tempDir.path}/preview_pdf_'
      '${DateTime.now().millisecondsSinceEpoch}',
    );

    await sessionDir.create(
      recursive: true,
    );

    final extractedPaths = <String>[];

    try {
      for (
        int pageNumber = 1;
        pageNumber <= document.pagesCount;
        pageNumber++
      ) {
        final page = await document.getPage(
          pageNumber,
        );

        try {
          final width = page.width * 2;
          final height = page.height * 2;

          final pageImage = await page.render(
            width: width,
            height: height,
            format:
                pdfx.PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
          );

          if (pageImage != null &&
              pageImage.bytes.isNotEmpty) {
            final outputPath =
                '${sessionDir.path}/page_'
                '$pageNumber.jpg';

            final outputFile = File(
              outputPath,
            );

            await outputFile.writeAsBytes(
              pageImage.bytes,
              flush: true,
            );

            extractedPaths.add(
              outputPath,
            );
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
        'Failed to render PDF: '
        'no readable pages found.',
      );
    }

    return extractedPaths;
  }

  // ===========================================================================
  // DOCX PREVIEW
  // ===========================================================================

  static Future<List<String>>
      _extractDocxPreviewPages(
    String docxPath,
  ) async {
    final file = File(docxPath);

    if (!await file.exists()) {
      throw Exception(
        'Word document does not exist:\n$docxPath',
      );
    }

    final bytes = await file.readAsBytes();

    final archive = ZipDecoder().decodeBytes(
      bytes,
    );

    final tempDir = await getTempDirectory();

    final sessionDir = Directory(
      '${tempDir.path}/preview_docx_'
      '${DateTime.now().millisecondsSinceEpoch}',
    );

    await sessionDir.create(
      recursive: true,
    );

    final pageSize = _readDocxPageSize(
      archive,
    );

    final pageWidthPx =
        pageSize.widthPx;

    final pageHeightPx =
        pageSize.heightPx;

    final mediaFiles = <ArchiveFile>[];

    for (final archiveFile in archive) {
      if (!archiveFile.isFile) {
        continue;
      }

      final lowerName =
          archiveFile.name.toLowerCase();

      if (!lowerName.startsWith(
        'word/media/',
      )) {
        continue;
      }

      if (_isSupportedImage(
        lowerName,
      )) {
        mediaFiles.add(
          archiveFile,
        );
      }
    }

    mediaFiles.sort(
      (a, b) {
        final aNumber =
            _extractNumberFromMediaName(
          a.name,
        );

        final bNumber =
            _extractNumberFromMediaName(
          b.name,
        );

        if (aNumber != bNumber) {
          return aNumber.compareTo(
            bNumber,
          );
        }

        return a.name.compareTo(
          b.name,
        );
      },
    );

    // -------------------------------------------------------------------------
    // No embedded images
    // -------------------------------------------------------------------------

    if (mediaFiles.isEmpty) {
      final blankPath =
          await _createBlankPreviewPage(
        sessionDir: sessionDir,
        width: pageWidthPx,
        height: pageHeightPx,
      );

      return [blankPath];
    }

    final outputPaths = <String>[];

    for (
      int i = 0;
      i < mediaFiles.length;
      i++
    ) {
      final media = mediaFiles[i];

      final mediaBytes =
          Uint8List.fromList(
        media.content,
      );

      final decoded =
          img.decodeImage(
        mediaBytes,
      );

      if (decoded == null) {
        continue;
      }

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

      // Approximate Word margins.
      const int margin = 96;

      final availableWidth =
          pageWidthPx -
          (margin * 2);

      final availableHeight =
          pageHeightPx -
          (margin * 2);

      final fitted = _fitImage(
        source: decoded,
        maxWidth: availableWidth,
        maxHeight: availableHeight,
      );

      final x =
          ((pageWidthPx -
                      fitted.width) /
                  2)
              .round();

      final y =
          ((pageHeightPx -
                      fitted.height) /
                  2)
              .round();

      img.compositeImage(
        pageCanvas,
        fitted,
        dstX: x,
        dstY: y,
      );

      final outputPath =
          '${sessionDir.path}/page_'
          '${i + 1}.jpg';

      final outputFile = File(
        outputPath,
      );

      final jpgBytes =
          img.encodeJpg(
        pageCanvas,
        quality: 92,
      );

      await outputFile.writeAsBytes(
        jpgBytes,
        flush: true,
      );

      outputPaths.add(
        outputPath,
      );
    }

    if (outputPaths.isEmpty) {
      throw Exception(
        'Failed to create Word preview pages.',
      );
    }

    return outputPaths;
  }

  // ===========================================================================
  // PPTX PREVIEW
  // ===========================================================================

  static Future<List<String>>
      _extractPptxPreviewSlides(
    String pptxPath,
  ) async {
    final file = File(pptxPath);

    if (!await file.exists()) {
      throw Exception(
        'PowerPoint presentation does not exist:\n'
        '$pptxPath',
      );
    }

    final bytes = await file.readAsBytes();

    final archive = ZipDecoder().decodeBytes(
      bytes,
    );

    final tempDir = await getTempDirectory();

    final sessionDir = Directory(
      '${tempDir.path}/preview_pptx_'
      '${DateTime.now().millisecondsSinceEpoch}',
    );

    await sessionDir.create(
      recursive: true,
    );

    final slideSize =
        _readPptxSlideSize(
      archive,
    );

    final slideWidthPx =
        slideSize.widthPx;

    final slideHeightPx =
        slideSize.heightPx;

    // -------------------------------------------------------------------------
    // Find slides
    // -------------------------------------------------------------------------

    final slideFiles = <ArchiveFile>[];

    for (final archiveFile in archive) {
      if (!archiveFile.isFile) {
        continue;
      }

      if (RegExp(
        r'^ppt/slides/slide\d+\.xml$',
        caseSensitive: false,
      ).hasMatch(
        archiveFile.name,
      )) {
        slideFiles.add(
          archiveFile,
        );
      }
    }

    slideFiles.sort(
      (a, b) {
        final aNumber =
            _extractNumberFromMediaName(
          a.name,
        );

        final bNumber =
            _extractNumberFromMediaName(
          b.name,
        );

        return aNumber.compareTo(
          bNumber,
        );
      },
    );

    if (slideFiles.isEmpty) {
      throw Exception(
        'No PowerPoint slides found in presentation.',
      );
    }

    // -------------------------------------------------------------------------
    // Find slide media
    // -------------------------------------------------------------------------

    final mediaFiles = <ArchiveFile>[];

    for (final archiveFile in archive) {
      if (!archiveFile.isFile) {
        continue;
      }

      final lowerName =
          archiveFile.name.toLowerCase();

      if (!lowerName.startsWith(
        'ppt/media/',
      )) {
        continue;
      }

      if (_isSupportedImage(
        lowerName,
      )) {
        mediaFiles.add(
          archiveFile,
        );
      }
    }

    mediaFiles.sort(
      (a, b) {
        final aNumber =
            _extractNumberFromMediaName(
          a.name,
        );

        final bNumber =
            _extractNumberFromMediaName(
          b.name,
        );

        if (aNumber != bNumber) {
          return aNumber.compareTo(
            bNumber,
          );
        }

        return a.name.compareTo(
          b.name,
        );
      },
    );

    final outputPaths = <String>[];

    for (
      int i = 0;
      i < slideFiles.length;
      i++
    ) {
      final slideCanvas = img.Image(
        width: slideWidthPx,
        height: slideHeightPx,
      );

      // White PowerPoint background.
      img.fill(
        slideCanvas,
        color: img.ColorRgb8(
          255,
          255,
          255,
        ),
      );

      // -----------------------------------------------------------------------
      // Add available slide image
      // -----------------------------------------------------------------------

      if (i < mediaFiles.length) {
        final media =
            mediaFiles[i];

        final mediaBytes =
            Uint8List.fromList(
          media.content,
        );

        final decoded =
            img.decodeImage(
          mediaBytes,
        );

        if (decoded != null) {
          final fitted =
              _fitImage(
            source: decoded,
            maxWidth: slideWidthPx,
            maxHeight: slideHeightPx,
          );

          final x =
              ((slideWidthPx -
                          fitted.width) /
                      2)
                  .round();

          final y =
              ((slideHeightPx -
                          fitted.height) /
                      2)
                  .round();

          img.compositeImage(
            slideCanvas,
            fitted,
            dstX: x,
            dstY: y,
          );
        }
      }

      final outputPath =
          '${sessionDir.path}/slide_'
          '${i + 1}.jpg';

      final outputFile = File(
        outputPath,
      );

      final jpgBytes =
          img.encodeJpg(
        slideCanvas,
        quality: 92,
      );

      await outputFile.writeAsBytes(
        jpgBytes,
        flush: true,
      );

      outputPaths.add(
        outputPath,
      );
    }

    return outputPaths;
  }

  // ===========================================================================
  // DOCX PAGE SIZE
  // ===========================================================================

  static _DocumentPageSize
      _readDocxPageSize(
    Archive archive,
  ) {
    const defaultWidthTwips =
        12240;

    const defaultHeightTwips =
        15840;

    try {
      final documentFile =
          archive.findFile(
        'word/document.xml',
      );

      if (documentFile == null) {
        return _DocumentPageSize.fromTwips(
          defaultWidthTwips,
          defaultHeightTwips,
        );
      }

      final xml =
          String.fromCharCodes(
        documentFile.content,
      );

      final match = RegExp(
        r'<w:pgSz\b[^>]*'
        r'w:w="(\d+)"[^>]*'
        r'w:h="(\d+)"',
      ).firstMatch(xml);

      if (match == null) {
        return _DocumentPageSize.fromTwips(
          defaultWidthTwips,
          defaultHeightTwips,
        );
      }

      final widthTwips =
          int.tryParse(
                match.group(1)!,
              ) ??
              defaultWidthTwips;

      final heightTwips =
          int.tryParse(
                match.group(2)!,
              ) ??
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

  // ===========================================================================
  // PPTX SLIDE SIZE
  // ===========================================================================

  static _DocumentPageSize
      _readPptxSlideSize(
    Archive archive,
  ) {
    // Default 16:9 PowerPoint.
    const defaultWidthEmu =
        12192000;

    const defaultHeightEmu =
        6858000;

    try {
      final presentationFile =
          archive.findFile(
        'ppt/presentation.xml',
      );

      if (presentationFile == null) {
        return _DocumentPageSize.fromEmu(
          defaultWidthEmu,
          defaultHeightEmu,
        );
      }

      final xml =
          String.fromCharCodes(
        presentationFile.content,
      );

      final match = RegExp(
        r'<p:sldSz\b[^>]*'
        r'cx="(\d+)"[^>]*'
        r'cy="(\d+)"',
      ).firstMatch(xml);

      if (match == null) {
        return _DocumentPageSize.fromEmu(
          defaultWidthEmu,
          defaultHeightEmu,
        );
      }

      final widthEmu =
          int.tryParse(
                match.group(1)!,
              ) ??
              defaultWidthEmu;

      final heightEmu =
          int.tryParse(
                match.group(2)!,
              ) ??
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

  // ===========================================================================
  // IMAGE HELPERS
  // ===========================================================================

  static bool _isSupportedImage(
    String path,
  ) {
    final lower =
        path.toLowerCase();

    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
  }

  static int
      _extractNumberFromMediaName(
    String name,
  ) {
    final matches =
        RegExp(r'(\d+)').allMatches(
      name,
    );

    if (matches.isEmpty) {
      return 0;
    }

    final lastMatch =
        matches.last;

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

    final scale =
        widthRatio < heightRatio
            ? widthRatio
            : heightRatio;

    final targetWidth =
        (source.width * scale)
            .round();

    final targetHeight =
        (source.height * scale)
            .round();

    return img.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation:
          img.Interpolation.cubic,
    );
  }

  static Future<String>
      _createBlankPreviewPage({
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

    final outputFile =
        File(outputPath);

    await outputFile.writeAsBytes(
      img.encodeJpg(
        page,
        quality: 92,
      ),
      flush: true,
    );

    return outputPath;
  }

  // ===========================================================================
  // STORAGE
  // ===========================================================================

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

  // ===========================================================================
  // FILE NAME / PATH
  // ===========================================================================

  static Future<String>
      generatePdfFileName([
    ConversionType type =
        ConversionType.pdf,
  ]) async {
    final timestamp =
        DateTime.now()
            .millisecondsSinceEpoch;

    return 'DocVault_$timestamp.'
        '${type.extension}';
  }

  static Future<String>
      getFullPdfPath(
    String fileName,
  ) async {
    final directory =
        await getAppDocumentsDirectory();

    final type =
        ConversionType.fromFileName(
      fileName,
    );

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

  // ===========================================================================
  // SAVED DOCUMENTS
  // ===========================================================================

  static Future<List<File>>
      getAllSavedPdfs() async {
    try {
      final directory =
          await getAppDocumentsDirectory();

      final files = <File>[];

      if (await directory.exists()) {
        final entities =
            directory.listSync();

        for (final entity in entities) {
          if (entity is! File) {
            continue;
          }

          final pathLower =
              entity.path.toLowerCase();

          if (pathLower.endsWith(
                '.pdf',
              ) ||
              pathLower.endsWith(
                '.docx',
              ) ||
              pathLower.endsWith(
                '.pptx',
              )) {
            files.add(entity);
          }
        }
      }

      return files;
    } catch (_) {
      return [];
    }
  }

  // ===========================================================================
  // DELETE
  // ===========================================================================

  static Future<bool> deletePdfFile(
    String filePath,
  ) async {
    try {
      final file =
          File(filePath);

      if (await file.exists()) {
        await file.delete();
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // FILE SIZE
  // ===========================================================================

  static Future<double>
      getPdfFileSizeInMB(
    String filePath,
  ) async {
    try {
      final file =
          File(filePath);

      if (await file.exists()) {
        final size =
            await file.length();

        return size /
            (1024 * 1024);
      }

      return 0;
    } catch (_) {
      return 0;
    }
  }

  // ===========================================================================
  // TEMP / CACHE CLEANUP
  // ===========================================================================

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
      // Ignore cleanup errors.
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
      // Ignore cleanup errors.
    }
  }

  // ===========================================================================
  // TOTAL STORAGE
  // ===========================================================================

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

  // ===========================================================================
  // TWIPS → PIXELS
  // ===========================================================================

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
      widthPx:
          widthPx.clamp(
        1,
        5000,
      ),
      heightPx:
          heightPx.clamp(
        1,
        5000,
      ),
    );
  }

  // ===========================================================================
  // EMU → PIXELS
  // ===========================================================================

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
      widthPx:
          widthPx.clamp(
        1,
        5000,
      ),
      heightPx:
          heightPx.clamp(
        1,
        5000,
      ),
    );
  }
}