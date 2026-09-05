import 'dart:convert';
import 'dart:io';

import 'package:doc_vault/core/services/external_pdf_service.dart';
import 'package:doc_vault/core/utils/file_utils.dart';
import 'package:doc_vault/models/conversion_type.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileUtils.normalizePdfFileName Tests', () {
    test('appends .pdf to base name without extension', () {
      expect(FileUtils.normalizePdfFileName('My Birthday Photos'), 'My Birthday Photos.pdf');
    });

    test('preserves single .pdf extension', () {
      expect(FileUtils.normalizePdfFileName('My Birthday Photos.pdf'), 'My Birthday Photos.pdf');
    });

    test('handles uppercase .PDF extension properly', () {
      expect(FileUtils.normalizePdfFileName('Document.PDF'), 'Document.pdf');
    });

    test('removes duplicate .pdf extensions', () {
      expect(FileUtils.normalizePdfFileName('My Document.pdf.pdf'), 'My Document.pdf');
      expect(FileUtils.normalizePdfFileName('Report.PDF.pdf.PDF'), 'Report.pdf');
    });

    test('sanitizes illegal platform filesystem characters', () {
      expect(
        FileUtils.normalizePdfFileName('Invoice/2026:Final*Draft?.pdf'),
        'Invoice_2026_Final_Draft_.pdf',
      );
      expect(
        FileUtils.normalizePdfFileName(r'C:\Test<Doc>|File".pdf'),
        'C__Test_Doc__File_.pdf',
      );
    });

    test('trims whitespace and handles empty strings', () {
      expect(FileUtils.normalizePdfFileName('   Vacation 2026   '), 'Vacation 2026.pdf');
      expect(FileUtils.normalizePdfFileName(''), 'DocScanner_Document.pdf');
      expect(FileUtils.normalizePdfFileName('   '), 'DocScanner_Document.pdf');
    });

    test('preserves spaces and valid characters', () {
      expect(
        FileUtils.normalizePdfFileName('Final Exam Notes - Math 101 (v2)'),
        'Final Exam Notes - Math 101 (v2).pdf',
      );
    });
  });

  group('FileUtils.normalizeFileName Multi-Format Tests', () {
    test('normalizes DOCX filenames', () {
      expect(
        FileUtils.normalizeFileName('My Report', ConversionType.docs),
        'My Report.docx',
      );
      expect(
        FileUtils.normalizeFileName('My Report.docx.docx', ConversionType.docs),
        'My Report.docx',
      );
      expect(
        FileUtils.normalizeFileName('My Report.pdf', ConversionType.docs),
        'My Report.docx',
      );
    });

    test('normalizes PPTX filenames', () {
      expect(
        FileUtils.normalizeFileName('Presentation 2026', ConversionType.ppt),
        'Presentation 2026.pptx',
      );
      expect(
        FileUtils.normalizeFileName('Slides.pptx.pptx', ConversionType.ppt),
        'Slides.pptx',
      );
      expect(
        FileUtils.normalizeFileName('Slides.pdf', ConversionType.ppt),
        'Slides.pptx',
      );
    });
  });

  group('External document import flow', () {
    test('imports a supported DOCX or PPTX via the generic document bridge', () async {
      final tempDir = await Directory.systemTemp.createTemp('docvault_import_test');
      addTearDown(() async {
        try {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        } catch (_) {}
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          return tempDir.path;
        },
      );

      const channel = MethodChannel('docvault/pdf_intent');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'readDocument') {
          final bytes = utf8.encode('docx-bytes');
          return {
            'bytes': bytes,
            'fileName': 'Quarterly_Pitch.pptx',
          };
        }
        throw MissingPluginException();
      });

      final result = await ExternalPdfService.importDocumentFromUri('content://example/Quarterly_Pitch.pptx');

      expect(result['fileName'], 'Quarterly_Pitch.pptx');
      expect(result['filePath'], isNotEmpty);
      expect(File(result['filePath'] as String).existsSync(), isTrue);
    });

    test('uses native cached filePath directly without redundant byte copy', () async {
      final tempDir = await Directory.systemTemp.createTemp('docvault_native_test');
      addTearDown(() async {
        try {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        } catch (_) {}
      });

      final nativeCachedFile = File('${tempDir.path}/Streamed_Doc.docx');
      await nativeCachedFile.writeAsString('native-streamed-docx-content');

      const channel = MethodChannel('docvault/pdf_intent');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'readDocument') {
          return {
            'filePath': nativeCachedFile.path,
            'fileName': 'Streamed_Doc.docx',
            'fileSize': await nativeCachedFile.length(),
            'mimeType': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          };
        }
        throw MissingPluginException();
      });

      final result = await ExternalPdfService.importDocumentFromUri('content://example/Streamed_Doc.docx');

      expect(result['fileName'], 'Streamed_Doc.docx');
      expect(result['filePath'], nativeCachedFile.path);
      expect(result['type'], ConversionType.docs);
    });
  });

  group('Legacy Office Document Detection & Handling Tests', () {
    test('detects OLE2 binary header for legacy .doc and .ppt', () {
      final ole2Bytes = Uint8List.fromList([
        0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1,
        0x00, 0x00, 0x00, 0x00,
      ]);
      expect(FileUtils.isLegacyOfficeDocument(ole2Bytes), isTrue);

      final zipBytes = Uint8List.fromList([
        0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x06, 0x00,
      ]);
      expect(FileUtils.isLegacyOfficeDocument(zipBytes), isFalse);

      final pdfBytes = Uint8List.fromList([
        0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x35,
      ]);
      expect(FileUtils.isLegacyOfficeDocument(pdfBytes), isFalse);
    });

    test('extracts fallback preview pages for legacy binary document without crashing', () async {
      final tempDir = await Directory.systemTemp.createTemp('docvault_legacy_test');
      addTearDown(() async {
        try {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        } catch (_) {}
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          return tempDir.path;
        },
      );

      // Create a mock legacy .doc file with OLE2 header and embedded ASCII text
      final legacyFile = File('${tempDir.path}/OldResume.doc');
      final bytes = <int>[
        0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1,
        ...utf8.encode('John Doe Software Engineer Profile Summary and Experience Details'),
      ];
      await legacyFile.writeAsBytes(bytes);

      final pages = await FileUtils.extractPagesFromDocument(legacyFile.path);

      expect(pages, isNotEmpty);
      expect(File(pages.first).existsSync(), isTrue);
      expect(File(pages.first).lengthSync(), greaterThan(0));
    });
  });
}

