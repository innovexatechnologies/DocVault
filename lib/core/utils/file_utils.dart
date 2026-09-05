import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../../models/conversion_type.dart';

class FileUtils {
  static const String _pdfDirName = 'DocScanner/PDFs';
  static const String _tempDirName = 'DocScanner/Temp';
  static const String _cacheDirName = 'DocScanner/Cache';

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

    if (clean.isEmpty) {
      clean = 'DocScanner_Document';
    }

    clean = clean.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    clean = clean.replaceAll(
      RegExp(
        r'(\.(pdf|docx|pptx|doc|ppt))+$',
        caseSensitive: false,
      ),
      '',
    );

    clean = clean.trim();

    if (clean.isEmpty) {
      clean = 'DocScanner_Document';
    }

    return '$clean.${type.extension}';
  }

  // ===========================================================================
  // DOCUMENT PAGE EXTRACTION
  // ===========================================================================

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

    if (type == ConversionType.pdf) {
      return extractPdfPagesToImages(filePath);
    }

    final bytes = await file.readAsBytes();
    if (isLegacyOfficeDocument(bytes)) {
      return _extractLegacyOfficePreviewPages(filePath, bytes, type);
    }

    switch (type) {
      case ConversionType.pdf:
        return extractPdfPagesToImages(filePath);

      case ConversionType.docs:
        return _extractDocxPreviewPages(filePath);

      case ConversionType.ppt:
        return _extractPptxPreviewSlides(filePath);
    }
  }

  // ===========================================================================
  // TEXT EXTRACTION
  // ===========================================================================

  static Future<List<String>> extractTextPagesFromDocument(
    String filePath,
  ) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception(
        'Document file does not exist:\n$filePath',
      );
    }

    final type = ConversionType.fromFileName(filePath);

    if (type == ConversionType.pdf) {
      return [];
    }

    final bytes = await file.readAsBytes();

    if (isLegacyOfficeDocument(bytes)) {
      final legacyText = _extractTextFromLegacyOfficeBinary(bytes);
      return legacyText.trim().isNotEmpty ? [legacyText.trim()] : [''];
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      final legacyText = _extractTextFromLegacyOfficeBinary(bytes);
      return legacyText.trim().isNotEmpty ? [legacyText.trim()] : [''];
    }

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
        Uint8List.fromList(
          documentFile.content,
        ),
        allowMalformed: true,
      );

      final text = _extractXmlText(
        xml,
        paragraphTag: 'w:p',
        textTag: 'w:t',
      );

      if (text.trim().isEmpty) {
        return [''];
      }

      return [text];
    }

    // -------------------------------------------------------------------------
    // PPTX
    // -------------------------------------------------------------------------

    if (type == ConversionType.ppt) {
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
          Uint8List.fromList(
            slide.content,
          ),
          allowMalformed: true,
        );

        final text = _extractXmlText(
          xml,
          textTag: 'a:t',
        );

        slides.add(text.trim());
      }

      if (slides.isEmpty) {
        return [''];
      }

      return slides;
    }

    return [''];
  }

  static String _extractXmlText(
    String xml, {
    String? paragraphTag,
    required String textTag,
  }) {
    final List<String> paragraphs = [];

    if (paragraphTag == null) {
      paragraphs.add(xml);
    } else {
      final paragraphRegex = RegExp(
        '<$paragraphTag\\b[^>]*>([\\s\\S]*?)</$paragraphTag>',
        caseSensitive: false,
      );

      for (final match in paragraphRegex.allMatches(xml)) {
        paragraphs.add(
          match.group(1) ?? '',
        );
      }
    }

    final lines = <String>[];

    for (final paragraph in paragraphs) {
      final textRegex = RegExp(
        '<$textTag\\b[^>]*>([\\s\\S]*?)</$textTag>',
        caseSensitive: false,
      );

      final text = textRegex
          .allMatches(paragraph)
          .map(
            (match) => _decodeXmlEntities(
              match.group(1) ?? '',
            ),
          )
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

  // ===========================================================================
  // PDF → IMAGES
  // ===========================================================================

  static Future<List<String>> extractPdfPagesToImages(
    String pdfPath,
  ) async {
    final file = File(pdfPath);

    if (!await file.exists()) {
      throw Exception(
        'PDF file does not exist:\n$pdfPath',
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
          // IMPORTANT:
          // pdfx render() requires double values.
          final double width = page.width * 2.0;
          final double height = page.height * 2.0;

          final pageImage = await page.render(
            width: width,
            height: height,
            format: pdfx.PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
          );

          if (pageImage != null &&
              pageImage.bytes.isNotEmpty) {
            final outputPath =
                '${sessionDir.path}/page_'
                '${pageNumber.toString().padLeft(4, '0')}.jpg';

            await File(outputPath).writeAsBytes(
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
        'Failed to render PDF pages.',
      );
    }

    return extractedPaths;
  }

  // ===========================================================================
  // OFFICE CACHE
  // ===========================================================================

  static Future<Directory> _getOfficePreviewCacheDirectory(
    String filePath,
  ) async {
    final cacheDir = await getCacheDirectory();

    final file = File(filePath);
    final stat = await file.stat();

    final rawKey =
        '${file.absolute.path}|'
        '${stat.size}|'
        '${stat.modified.millisecondsSinceEpoch}';

    final key = _fastHash(rawKey);

    final directory = Directory(
      '${cacheDir.path}/office_$key',
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive: true,
      );
    }

    return directory;
  }

  static String _fastHash(String input) {
    int hash = 0;

    for (final unit in utf8.encode(input)) {
      hash = ((hash << 5) - hash + unit) & 0x7FFFFFFF;
    }

    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Future<List<String>?> _getCachedOfficePages(
    String filePath,
    String prefix,
  ) async {
    try {
      final cacheDir =
          await _getOfficePreviewCacheDirectory(filePath);

      if (!await cacheDir.exists()) {
        return null;
      }

      final files = <File>[];

      await for (final entity in cacheDir.list()) {
        if (entity is! File) {
          continue;
        }

        final fileName =
            entity.uri.pathSegments.last.toLowerCase();

        if (!fileName.endsWith('.jpg')) {
          continue;
        }

        if (!fileName.startsWith(prefix.toLowerCase())) {
          continue;
        }

        if (await entity.length() <= 0) {
          continue;
        }

        files.add(entity);
      }

      if (files.isEmpty) {
        return null;
      }

      files.sort(
        (a, b) {
          final aNumber = _extractNumberFromMediaName(
            a.uri.pathSegments.last,
          );

          final bNumber = _extractNumberFromMediaName(
            b.uri.pathSegments.last,
          );

          return aNumber.compareTo(bNumber);
        },
      );

      for (int i = 0; i < files.length; i++) {
        final expected = i + 1;

        final actual = _extractNumberFromMediaName(
          files[i].uri.pathSegments.last,
        );

        if (actual != expected) {
          return null;
        }
      }

      return files.map((file) => file.path).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _deleteOfficeCache(
    Directory directory,
  ) async {
    try {
      if (await directory.exists()) {
        await directory.delete(
          recursive: true,
        );
      }
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  // ===========================================================================
  // DOCX PREVIEW
  // ===========================================================================

  static Future<List<String>> _extractDocxPreviewPages(
    String docxPath,
  ) async {
    final file = File(docxPath);

    if (!await file.exists()) {
      throw Exception(
        'Word document does not exist:\n$docxPath',
      );
    }

    final cacheDir =
        await _getOfficePreviewCacheDirectory(docxPath);

    final cachedPages =
        await _getCachedOfficePages(
      docxPath,
      'page_',
    );

    if (cachedPages != null &&
        cachedPages.isNotEmpty) {
      return cachedPages;
    }

    await _deleteOfficeCache(cacheDir);

    await cacheDir.create(
      recursive: true,
    );

    try {
      final bytes = await file.readAsBytes();

      if (isLegacyOfficeDocument(bytes)) {
        return _extractLegacyOfficePreviewPages(
          docxPath,
          bytes,
          ConversionType.docs,
        );
      }

      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (_) {
        return _extractLegacyOfficePreviewPages(
          docxPath,
          bytes,
          ConversionType.docs,
        );
      }

      final pageSize = _readDocxPageSize(
        archive,
      );

      final mediaFiles = <ArchiveFile>[];

      for (final archiveFile in archive) {
        if (!archiveFile.isFile) {
          continue;
        }

        final lowerName =
            archiveFile.name.toLowerCase();

        if (lowerName.startsWith('word/media/') &&
            _isSupportedImage(lowerName)) {
          mediaFiles.add(archiveFile);
        }
      }

      mediaFiles.sort(
        (a, b) => _extractNumberFromMediaName(
          a.name,
        ).compareTo(
          _extractNumberFromMediaName(
            b.name,
          ),
        ),
      );

      final outputPaths = <String>[];

      // -----------------------------------------------------------------------
      // DOCUMENT HAS IMAGES
      // -----------------------------------------------------------------------

      if (mediaFiles.isNotEmpty) {
        for (
          int i = 0;
          i < mediaFiles.length;
          i++
        ) {
          final decoded = img.decodeImage(
            Uint8List.fromList(
              mediaFiles[i].content,
            ),
          );

          if (decoded == null) {
            continue;
          }

          final pagePath =
              await _createImagePreviewPage(
            directory: cacheDir,
            fileName:
                'page_${(i + 1).toString().padLeft(4, '0')}.jpg',
            sourceImage: decoded,
            width: pageSize.widthPx,
            height: pageSize.heightPx,
            margin: 80,
          );

          outputPaths.add(pagePath);
        }
      }

      // -----------------------------------------------------------------------
      // TEXT ONLY DOCUMENT
      // -----------------------------------------------------------------------

      if (outputPaths.isEmpty) {
        final documentFile = archive.findFile(
          'word/document.xml',
        );

        String text = '';

        if (documentFile != null) {
          final xml = utf8.decode(
            Uint8List.fromList(
              documentFile.content,
            ),
            allowMalformed: true,
          );

          text = _extractXmlText(
            xml,
            paragraphTag: 'w:p',
            textTag: 'w:t',
          );
        }

        final pagePaths = await _createTextPreviewPages(
          directory: cacheDir,
          text: text,
          width: pageSize.widthPx,
          height: pageSize.heightPx,
        );

        outputPaths.addAll(pagePaths);
      }

      if (outputPaths.isEmpty) {
        throw Exception(
          'Failed to create Word preview.',
        );
      }

      return outputPaths;
    } catch (e) {
      await _deleteOfficeCache(cacheDir);
      rethrow;
    }
  }

  // ===========================================================================
  // PPTX PREVIEW
  // ===========================================================================

  static Future<List<String>> _extractPptxPreviewSlides(
    String pptxPath,
  ) async {
    final file = File(pptxPath);

    if (!await file.exists()) {
      throw Exception(
        'PowerPoint presentation does not exist:\n$pptxPath',
      );
    }

    final cacheDir =
        await _getOfficePreviewCacheDirectory(pptxPath);

    final cachedSlides =
        await _getCachedOfficePages(
      pptxPath,
      'slide_',
    );

    if (cachedSlides != null &&
        cachedSlides.isNotEmpty) {
      return cachedSlides;
    }

    await _deleteOfficeCache(cacheDir);

    await cacheDir.create(
      recursive: true,
    );

    try {
      final bytes = await file.readAsBytes();

      if (isLegacyOfficeDocument(bytes)) {
        return _extractLegacyOfficePreviewPages(
          pptxPath,
          bytes,
          ConversionType.ppt,
        );
      }

      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (_) {
        return _extractLegacyOfficePreviewPages(
          pptxPath,
          bytes,
          ConversionType.ppt,
        );
      }

      final slideSize =
          _readPptxSlideSize(archive);

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

      if (slideFiles.isEmpty) {
        throw Exception(
          'No PowerPoint slides found.',
        );
      }

      final mediaFiles = <ArchiveFile>[];

      for (final archiveFile in archive) {
        if (!archiveFile.isFile) {
          continue;
        }

        final lowerName =
            archiveFile.name.toLowerCase();

        if (lowerName.startsWith('ppt/media/') &&
            _isSupportedImage(lowerName)) {
          mediaFiles.add(archiveFile);
        }
      }

      mediaFiles.sort(
        (a, b) => _extractNumberFromMediaName(
          a.name,
        ).compareTo(
          _extractNumberFromMediaName(
            b.name,
          ),
        ),
      );

      final outputPaths = <String>[];

      for (
        int i = 0;
        i < slideFiles.length;
        i++
      ) {
        final slideCanvas = img.Image(
          width: slideSize.widthPx,
          height: slideSize.heightPx,
        );

        img.fill(
          slideCanvas,
          color: img.ColorRgb8(
            255,
            255,
            255,
          ),
        );

        // Extract slide XML text if present
        String slideText = '';
        try {
          final slideXml = utf8.decode(
            Uint8List.fromList(slideFiles[i].content),
            allowMalformed: true,
          );
          slideText = _extractXmlText(slideXml, textTag: 'a:t');
        } catch (_) {}

        // Add image if available.
        bool hasImage = false;
        if (i < mediaFiles.length) {
          final decoded = img.decodeImage(
            Uint8List.fromList(
              mediaFiles[i].content,
            ),
          );

          if (decoded != null) {
            hasImage = true;
            final fitted = _fitImage(
              source: decoded,
              maxWidth: slideSize.widthPx,
              maxHeight: slideSize.heightPx,
            );

            final x =
                ((slideSize.widthPx - fitted.width) / 2)
                    .round();

            final y =
                ((slideSize.heightPx - fitted.height) / 2)
                    .round();

            img.compositeImage(
              slideCanvas,
              fitted,
              dstX: x,
              dstY: y,
            );
          }
        }

        // When no image is present, render a styled slide presentation card
        if (!hasImage) {
          _drawSlideCard(
            slideCanvas: slideCanvas,
            slideText: slideText,
            slideNumber: i + 1,
            totalSlides: slideFiles.length,
            width: slideSize.widthPx,
            height: slideSize.heightPx,
          );
        }

        final outputPath =
            '${cacheDir.path}/slide_'
            '${(i + 1).toString().padLeft(4, '0')}.jpg';

        await File(outputPath).writeAsBytes(
          img.encodeJpg(
            slideCanvas,
            quality: 80,
          ),
          flush: true,
        );

        outputPaths.add(outputPath);
      }

      return outputPaths;
    } catch (e) {
      await _deleteOfficeCache(cacheDir);
      rethrow;
    }
  }

  // ===========================================================================
  // CREATE IMAGE PREVIEW PAGE
  // ===========================================================================

  static Future<String> _createImagePreviewPage({
    required Directory directory,
    required String fileName,
    required img.Image sourceImage,
    required int width,
    required int height,
    required int margin,
  }) async {
    final canvas = img.Image(
      width: width,
      height: height,
    );

    img.fill(
      canvas,
      color: img.ColorRgb8(
        255,
        255,
        255,
      ),
    );

    final fitted = _fitImage(
      source: sourceImage,
      maxWidth: width - (margin * 2),
      maxHeight: height - (margin * 2),
    );

    final x =
        ((width - fitted.width) / 2).round();

    final y =
        ((height - fitted.height) / 2).round();

    img.compositeImage(
      canvas,
      fitted,
      dstX: x,
      dstY: y,
    );

    final outputPath =
        '${directory.path}/$fileName';

    await File(outputPath).writeAsBytes(
      img.encodeJpg(
        canvas,
        quality: 80,
      ),
      flush: true,
    );

    return outputPath;
  }

  // ===========================================================================
  // CREATE TEXT PREVIEW PAGES (PAGINATED WITH REAL TEXT RENDERING)
  // ===========================================================================

  static Future<List<String>> _createTextPreviewPages({
    required Directory directory,
    required String text,
    required int width,
    required int height,
    bool isLegacy = false,
  }) async {
    final cleanText = text.trim();
    final List<String> paragraphs = cleanText.isEmpty
        ? ['Document is empty or contains non-text media.']
        : cleanText.split('\n');

    final int marginX = (width * 0.08).round().clamp(40, 90);
    final int contentWidth = width - (marginX * 2);
    final int maxCharsPerLine = (contentWidth ~/ 9).clamp(25, 110);
    const int lineHeight = 22;
    final int startY = isLegacy ? 100 : 70;
    final int availableHeight = height - startY - 60;
    final int maxLinesPerPage = (availableHeight ~/ lineHeight).clamp(15, 60);

    final allLines = <String>[];
    for (final p in paragraphs) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) {
        allLines.add('');
      } else {
        allLines.addAll(_wrapText(trimmed, maxCharsPerLine));
      }
    }

    if (allLines.isEmpty) {
      allLines.add('Document contains no readable text.');
    }

    final pagesList = <List<String>>[];
    for (int i = 0; i < allLines.length; i += maxLinesPerPage) {
      final end = (i + maxLinesPerPage < allLines.length)
          ? i + maxLinesPerPage
          : allLines.length;
      pagesList.add(allLines.sublist(i, end));
    }

    final outputPaths = <String>[];
    final totalPages = pagesList.length;

    for (int pageIdx = 0; pageIdx < totalPages; pageIdx++) {
      final page = img.Image(
        width: width,
        height: height,
      );

      img.fill(
        page,
        color: img.ColorRgb8(255, 255, 255),
      );

      // Top decorative bar
      final topBarColor = isLegacy
          ? img.ColorRgb8(25, 118, 210) // Word blue
          : img.ColorRgb8(33, 150, 243);
      img.fillRect(
        page,
        x1: 0,
        y1: 0,
        x2: width,
        y2: 6,
        color: topBarColor,
      );

      if (isLegacy) {
        img.drawString(
          page,
          'MICROSOFT WORD (LEGACY 97-2003)',
          font: img.arial14,
          x: marginX,
          y: 20,
          color: img.ColorRgb8(100, 116, 139),
        );
        img.drawString(
          page,
          'Extracted text preview - For full formatting, open in Office app',
          font: img.arial14,
          x: marginX,
          y: 42,
          color: img.ColorRgb8(148, 163, 184),
        );
        img.fillRect(
          page,
          x1: marginX,
          y1: 65,
          x2: width - marginX,
          y2: 66,
          color: img.ColorRgb8(226, 232, 240),
        );
      }

      int y = startY;
      final linesOnThisPage = pagesList[pageIdx];
      for (final line in linesOnThisPage) {
        if (line.isNotEmpty) {
          img.drawString(
            page,
            line,
            font: img.arial14,
            x: marginX,
            y: y,
            color: img.ColorRgb8(30, 41, 59),
          );
        }
        y += lineHeight;
      }

      // Page footer
      img.drawString(
        page,
        'Page ${pageIdx + 1} of $totalPages',
        font: img.arial14,
        x: (width / 2 - 40).round(),
        y: height - 40,
        color: img.ColorRgb8(148, 163, 184),
      );

      final fileName = 'page_${(pageIdx + 1).toString().padLeft(4, '0')}.jpg';
      final pagePath = '${directory.path}/$fileName';

      await File(pagePath).writeAsBytes(
        img.encodeJpg(page, quality: 85),
        flush: true,
      );

      outputPaths.add(pagePath);
    }

    return outputPaths;
  }

  // ===========================================================================
  // SLIDE CARD RENDERING (FOR TEXT-ONLY PPTX SLIDES & FALLBACK)
  // ===========================================================================

  static void _drawSlideCard({
    required img.Image slideCanvas,
    required String slideText,
    required int slideNumber,
    required int totalSlides,
    required int width,
    required int height,
    bool isLegacy = false,
  }) {
    img.fill(
      slideCanvas,
      color: img.ColorRgb8(250, 251, 253),
    );

    // Modern PowerPoint orange accent header bar
    final barColor = isLegacy
        ? img.ColorRgb8(180, 80, 20)
        : img.ColorRgb8(230, 81, 0);
    img.fillRect(
      slideCanvas,
      x1: 0,
      y1: 0,
      x2: width,
      y2: 10,
      color: barColor,
    );

    // Header badge
    final headerText = isLegacy
        ? 'PPT (LEGACY 97-2003) | SLIDE $slideNumber OF $totalSlides'
        : 'POWERPOINT PRESENTATION | SLIDE $slideNumber OF $totalSlides';
    img.drawString(
      slideCanvas,
      headerText,
      font: img.arial14,
      x: 40,
      y: 28,
      color: img.ColorRgb8(120, 120, 120),
    );

    img.fillRect(
      slideCanvas,
      x1: 40,
      y1: 52,
      x2: width - 40,
      y2: 54,
      color: img.ColorRgb8(225, 228, 232),
    );

    final cleanText = slideText.trim();
    if (cleanText.isEmpty) {
      final centerText = 'Slide $slideNumber';
      final font = width > 800 ? img.arial48 : img.arial24;
      img.drawString(
        slideCanvas,
        centerText,
        font: font,
        x: (width / 2 - 80).round().clamp(40, width - 100),
        y: (height / 2 - 20).round(),
        color: img.ColorRgb8(140, 140, 140),
      );
      return;
    }

    final rawLines = cleanText
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (rawLines.isEmpty) return;

    int currentY = 75;
    final titleFont = width >= 800 ? img.arial48 : img.arial24;
    final bodyFont = img.arial24;
    final smallFont = img.arial14;

    // First line: Title
    final titleText = rawLines.first.trim();
    final titleLines = _wrapText(titleText, (width - 80) ~/ 16);
    for (final tLine in titleLines.take(2)) {
      img.drawString(
        slideCanvas,
        tLine,
        font: titleFont,
        x: 40,
        y: currentY,
        color: img.ColorRgb8(33, 33, 33),
      );
      currentY += (titleFont == img.arial48 ? 54 : 32);
    }
    currentY += 16;

    // Remaining lines: Bullet points
    final contentLines = rawLines.skip(1).toList();
    final maxChars = (width - 100) ~/ 13;

    for (final rawItem in contentLines) {
      if (currentY > height - 60) break;
      final wrapped = _wrapText(rawItem.trim(), maxChars);
      bool isFirstLineOfBullet = true;
      for (final wLine in wrapped) {
        if (currentY > height - 60) break;
        final lineStr = isFirstLineOfBullet ? '- $wLine' : '   $wLine';
        img.drawString(
          slideCanvas,
          lineStr,
          font: bodyFont,
          x: 50,
          y: currentY,
          color: img.ColorRgb8(55, 65, 81),
        );
        currentY += 28;
        isFirstLineOfBullet = false;
      }
      currentY += 8;
    }

    // Bottom slide footer
    final footerY = height - 32;
    img.drawString(
      slideCanvas,
      '$slideNumber / $totalSlides',
      font: smallFont,
      x: width - 80,
      y: footerY,
      color: img.ColorRgb8(150, 150, 150),
    );
  }

  // ===========================================================================
  // TEXT WRAPPING HELPER
  // ===========================================================================

  static List<String> _wrapText(String text, int maxCharsPerLine) {
    if (text.length <= maxCharsPerLine) return [text];
    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      if (word.isEmpty) continue;
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if (currentLine.length + 1 + word.length <= maxCharsPerLine) {
        currentLine = '$currentLine $word';
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    return lines.isEmpty ? [text] : lines;
  }

  // ===========================================================================
  // LEGACY OFFICE BINARY FORMAT DETECTION & PARSING (.DOC / .PPT 97-2003)
  // ===========================================================================

  /// Checks if file bytes match the Microsoft OLE2 Compound Document binary header.
  static bool isLegacyOfficeDocument(Uint8List bytes) {
    if (bytes.length < 8) return false;
    return bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0 &&
        bytes[4] == 0xA1 &&
        bytes[5] == 0xB1 &&
        bytes[6] == 0x1A &&
        bytes[7] == 0xE1;
  }

  static bool _isOfficeInternalMetadata(String text) {
    final lower = text.toLowerCase();
    return lower == 'root entry' ||
        lower == 'worddocument' ||
        lower == '1table' ||
        lower == '0table' ||
        lower == 'summaryinformation' ||
        lower == 'documentsummaryinformation' ||
        lower == 'current user' ||
        lower == 'compobj' ||
        lower == 'powerpoint document' ||
        lower.startsWith('microsoft ') ||
        lower.startsWith('msworddoc') ||
        lower.contains('times new roman') ||
        lower.contains('calibri');
  }

  static String _extractTextFromLegacyOfficeBinary(Uint8List bytes) {
    final lines = <String>{};

    // 1. Scan for UTF-16LE strings
    final utf16Run = <int>[];
    for (int i = 0; i < bytes.length - 1; i += 2) {
      final b0 = bytes[i];
      final b1 = bytes[i + 1];
      if (b1 == 0 &&
          ((b0 >= 32 && b0 <= 126) || b0 == 10 || b0 == 13 || b0 == 9)) {
        utf16Run.add(b0);
      } else {
        if (utf16Run.length >= 4) {
          final str = String.fromCharCodes(utf16Run).trim();
          if (str.length >= 4 && !_isOfficeInternalMetadata(str)) {
            lines.add(str);
          }
        }
        utf16Run.clear();
      }
    }
    if (utf16Run.length >= 4) {
      final str = String.fromCharCodes(utf16Run).trim();
      if (str.length >= 4 && !_isOfficeInternalMetadata(str)) {
        lines.add(str);
      }
    }

    // 2. Scan for ASCII strings
    final asciiRun = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      if ((b >= 32 && b <= 126) || b == 10 || b == 13 || b == 9) {
        asciiRun.add(b);
      } else {
        if (asciiRun.length >= 5) {
          final str = String.fromCharCodes(asciiRun).trim();
          if (str.length >= 5 && !_isOfficeInternalMetadata(str)) {
            lines.add(str);
          }
        }
        asciiRun.clear();
      }
    }
    if (asciiRun.length >= 5) {
      final str = String.fromCharCodes(asciiRun).trim();
      if (str.length >= 5 && !_isOfficeInternalMetadata(str)) {
        lines.add(str);
      }
    }

    return lines.join('\n\n');
  }

  static Future<List<String>> _extractLegacyOfficePreviewPages(
    String filePath,
    Uint8List bytes,
    ConversionType type,
  ) async {
    final cacheDir = await _getOfficePreviewCacheDirectory(filePath);
    final prefix = type == ConversionType.ppt ? 'slide_' : 'page_';
    final cached = await _getCachedOfficePages(filePath, prefix);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    await _deleteOfficeCache(cacheDir);
    await cacheDir.create(recursive: true);

    final extractedText = _extractTextFromLegacyOfficeBinary(bytes);

    if (type == ConversionType.ppt) {
      final slideSize = _DocumentPageSize.fromEmu(12192000, 6858000);
      final paragraphs = extractedText
          .split('\n\n')
          .where((p) => p.trim().isNotEmpty)
          .toList();
      final totalSlides =
          paragraphs.isEmpty ? 1 : paragraphs.length.clamp(1, 30);
      final outputPaths = <String>[];

      for (int i = 0; i < totalSlides; i++) {
        final slideCanvas = img.Image(
          width: slideSize.widthPx,
          height: slideSize.heightPx,
        );
        final slideText =
            paragraphs.isNotEmpty ? paragraphs[i] : '';
        _drawSlideCard(
          slideCanvas: slideCanvas,
          slideText: slideText,
          slideNumber: i + 1,
          totalSlides: totalSlides,
          width: slideSize.widthPx,
          height: slideSize.heightPx,
          isLegacy: true,
        );

        final outputPath =
            '${cacheDir.path}/slide_${(i + 1).toString().padLeft(4, '0')}.jpg';
        await File(outputPath).writeAsBytes(
          img.encodeJpg(slideCanvas, quality: 80),
          flush: true,
        );
        outputPaths.add(outputPath);
      }
      return outputPaths;
    } else {
      const pageSize = _DocumentPageSize(widthPx: 816, heightPx: 1056);
      return _createTextPreviewPages(
        directory: cacheDir,
        text: extractedText,
        width: pageSize.widthPx,
        height: pageSize.heightPx,
        isLegacy: true,
      );
    }
  }

  // ===========================================================================
  // DOCUMENT PAGE SIZE
  // ===========================================================================

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

      final xml = utf8.decode(
        Uint8List.fromList(
          documentFile.content,
        ),
        allowMalformed: true,
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
          int.tryParse(match.group(1) ?? '') ??
              defaultWidthTwips;

      final heightTwips =
          int.tryParse(match.group(2) ?? '') ??
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

  static _DocumentPageSize _readPptxSlideSize(
    Archive archive,
  ) {
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

      final xml = utf8.decode(
        Uint8List.fromList(
          presentationFile.content,
        ),
        allowMalformed: true,
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
          int.tryParse(match.group(1) ?? '') ??
              defaultWidthEmu;

      final heightEmu =
          int.tryParse(match.group(2) ?? '') ??
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
    final lower = path.toLowerCase();

    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
  }

  static int _extractNumberFromMediaName(
    String name,
  ) {
    final matches =
        RegExp(r'(\d+)').allMatches(name);

    if (matches.isEmpty) {
      return 0;
    }

    return int.tryParse(
          matches.last.group(1) ?? '',
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
            .round()
            .clamp(1, maxWidth)
            .toInt();

    final targetHeight =
        (source.height * scale)
            .round()
            .clamp(1, maxHeight)
            .toInt();

    return img.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );
  }

  // ===========================================================================
  // STORAGE
  // ===========================================================================

  static Future<Directory> getAppDocumentsDirectory() async {
    final directory =
        await getApplicationDocumentsDirectory();

    final documentDir = Directory(
      '${directory.path}/$_pdfDirName',
    );

    if (!await documentDir.exists()) {
      await documentDir.create(
        recursive: true,
      );
    }

    return documentDir;
  }

  static Future<Directory> getTempDirectory() async {
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

  static Future<Directory> getCacheDirectory() async {
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

  static Future<String> generatePdfFileName([
    ConversionType type = ConversionType.pdf,
  ]) async {
    final timestamp =
        DateTime.now().millisecondsSinceEpoch;

    return 'DocScanner_$timestamp.${type.extension}';
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

  // ===========================================================================
  // SAVED DOCUMENTS
  // ===========================================================================

  static Future<List<File>> getAllSavedPdfs() async {
    try {
      final directory =
          await getAppDocumentsDirectory();

      final files = <File>[];

      if (!await directory.exists()) {
        return files;
      }

      await for (final entity in directory.list()) {
        if (entity is! File) {
          continue;
        }

        final lowerPath =
            entity.path.toLowerCase();

        if (lowerPath.endsWith('.pdf') ||
            lowerPath.endsWith('.docx') ||
            lowerPath.endsWith('.pptx')) {
          files.add(entity);
        }
      }

      files.sort(
        (a, b) =>
            b.lastModifiedSync().compareTo(
          a.lastModifiedSync(),
        ),
      );

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

  // ===========================================================================
  // FILE SIZE
  // ===========================================================================

  static Future<double> getPdfFileSizeInMB(
    String filePath,
  ) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        return 0;
      }

      final size = await file.length();

      return size / (1024 * 1024);
    } catch (_) {
      return 0;
    }
  }

  // ===========================================================================
  // TEMP / CACHE CLEANUP
  // ===========================================================================

  static Future<void> clearTempDirectory() async {
    try {
      final directory =
          await getTempDirectory();

      if (await directory.exists()) {
        await directory.delete(
          recursive: true,
        );
      }

      await directory.create(
        recursive: true,
      );
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  static Future<void> clearCacheDirectory() async {
    try {
      final directory =
          await getCacheDirectory();

      if (await directory.exists()) {
        await directory.delete(
          recursive: true,
        );
      }

      await directory.create(
        recursive: true,
      );
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  // ===========================================================================
  // TOTAL STORAGE
  // ===========================================================================

  static Future<double> getTotalStorageUsedInMB() async {
    try {
      final files =
          await getAllSavedPdfs();

      double totalSize = 0;

      for (final file in files) {
        totalSize += await file.length();
      }

      return totalSize / (1024 * 1024);
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
    final widthPx =
        (widthTwips / 1440 * 96).round();

    final heightPx =
        (heightTwips / 1440 * 96).round();

    return _DocumentPageSize(
      widthPx: widthPx.clamp(1, 5000),
      heightPx: heightPx.clamp(1, 5000),
    );
  }

  // ===========================================================================
  // EMU → PIXELS
  // ===========================================================================

  factory _DocumentPageSize.fromEmu(
    int widthEmu,
    int heightEmu,
  ) {
    final widthPx =
        (widthEmu / 914400 * 96).round();

    final heightPx =
        (heightEmu / 914400 * 96).round();

    return _DocumentPageSize(
      widthPx: widthPx.clamp(1, 5000),
      heightPx: heightPx.clamp(1, 5000),
    );
  }
}