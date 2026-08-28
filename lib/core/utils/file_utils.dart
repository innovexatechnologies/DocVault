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

    if (clean.isEmpty) {
      clean = 'DocVault_Document';
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
      clean = 'DocVault_Document';
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

    final archive = ZipDecoder().decodeBytes(bytes);

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

      final archive = ZipDecoder().decodeBytes(
        bytes,
      );

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

        final pagePath =
            await _createTextPreviewPage(
          directory: cacheDir,
          fileName: 'page_0001.jpg',
          text: text,
          width: pageSize.widthPx,
          height: pageSize.heightPx,
        );

        outputPaths.add(pagePath);
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

      final archive = ZipDecoder().decodeBytes(
        bytes,
      );

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

        // Add image if available.
        if (i < mediaFiles.length) {
          final decoded = img.decodeImage(
            Uint8List.fromList(
              mediaFiles[i].content,
            ),
          );

          if (decoded != null) {
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
  // CREATE TEXT PREVIEW PAGE
  // ===========================================================================

  static Future<String> _createTextPreviewPage({
    required Directory directory,
    required String fileName,
    required String text,
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
        '${directory.path}/$fileName';

    await File(outputPath).writeAsBytes(
      img.encodeJpg(
        page,
        quality: 80,
      ),
      flush: true,
    );

    return outputPath;
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