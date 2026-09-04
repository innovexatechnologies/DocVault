import 'dart:io';
import 'package:doc_vault/core/providers/pdf_manager_provider.dart';
import 'package:doc_vault/core/services/docx_generation_service.dart';
import 'package:doc_vault/core/services/pdf_storage_service.dart';
import 'package:doc_vault/core/services/pptx_generation_service.dart';
import 'package:doc_vault/core/utils/file_utils.dart';
import 'package:doc_vault/models/conversion_type.dart';
import 'package:doc_vault/models/pdf_document.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late List<String> testImagePaths;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('docvault_test_');
    testImagePaths = [];

    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });

    // Create 2 synthetic test images
    for (int i = 1; i <= 2; i++) {
      final image = img.Image(width: 400, height: 300);
      img.fill(image, color: img.ColorRgba8(i * 50, 100, 200, 255));
      final jpgBytes = img.encodeJpg(image);
      final file = File('${tempDir.path}/test_img_$i.jpg');
      await file.writeAsBytes(jpgBytes);
      testImagePaths.add(file.path);
    }
  });

  tearDownAll(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('ConversionType Model Tests', () {
    test('resolves ConversionType from filenames correctly', () {
      expect(ConversionType.fromFileName('doc.pdf'), ConversionType.pdf);
      expect(ConversionType.fromFileName('doc.PDF'), ConversionType.pdf);
      expect(ConversionType.fromFileName('doc.docx'), ConversionType.docs);
      expect(ConversionType.fromFileName('doc.DOCX'), ConversionType.docs);
      expect(ConversionType.fromFileName('doc.doc'), ConversionType.docs);
      expect(ConversionType.fromFileName('slides.pptx'), ConversionType.ppt);
      expect(ConversionType.fromFileName('slides.PPTX'), ConversionType.ppt);
      expect(ConversionType.fromFileName('slides.ppt'), ConversionType.ppt);
    });

    test('exposes correct extensions and labels', () {
      expect(ConversionType.pdf.extension, 'pdf');
      expect(ConversionType.docs.extension, 'docx');
      expect(ConversionType.ppt.extension, 'pptx');

      expect(ConversionType.pdf.shortName, 'PDF');
      expect(ConversionType.docs.shortName, 'DOCX');
      expect(ConversionType.ppt.shortName, 'PPT');
    });
  });

  group('DOCX & PPTX Generation & Extraction Tests', () {
    test('generates valid DOCX document and extracts pages', () async {
      final docxService = DocxGenerationService();
      final result = await docxService.generateDocxFromImages(testImagePaths);

      expect(result.pageCount, 2);
      expect(result.conversionType, ConversionType.docs);
      expect(File(result.filePath).existsSync(), isTrue);

      // Verify extraction
      final extracted = await FileUtils.extractPagesFromDocument(result.filePath);
      expect(extracted.length, 2);
      for (final path in extracted) {
        expect(File(path).existsSync(), isTrue);
      }
    });

    test('generates valid PPTX presentation and extracts slides', () async {
      final pptxService = PptxGenerationService();
      final result = await pptxService.generatePptxFromImages(testImagePaths);

      expect(result.pageCount, 2);
      expect(result.conversionType, ConversionType.ppt);
      expect(File(result.filePath).existsSync(), isTrue);

      // Verify extraction
      final extracted = await FileUtils.extractPagesFromDocument(result.filePath);
      expect(extracted.length, 2);
      for (final path in extracted) {
        expect(File(path).existsSync(), isTrue);
      }
    });
  });

  group('PdfManagerProvider Multi-Format Filter Tests', () {
    test('filters documents by ConversionType (PDF, DOCS, PPT)', () async {
      final fakeStorage = _FakeMultiFormatStorageService([
        PdfDocument(
          id: '1',
          fileName: 'Finance_Report.pdf',
          filePath: '/storage/Finance_Report.pdf',
          fileSizeBytes: 1024,
          pageCount: 3,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
        PdfDocument(
          id: '2',
          fileName: 'Meeting_Notes.docx',
          filePath: '/storage/Meeting_Notes.docx',
          fileSizeBytes: 2048,
          pageCount: 2,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
        PdfDocument(
          id: '3',
          fileName: 'Quarterly_Pitch.pptx',
          filePath: '/storage/Quarterly_Pitch.pptx',
          fileSizeBytes: 4096,
          pageCount: 10,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      ]);

      final provider = PdfManagerProvider(storageService: fakeStorage);
      await provider.loadDocuments();

      expect(provider.totalCount, 3);
      expect(provider.pdfCount, 1);
      expect(provider.docsCount, 1);
      expect(provider.pptCount, 1);

      // All filter
      provider.setTypeFilter(null);
      expect(provider.documents.length, 3);

      // PDF filter
      provider.setTypeFilter(ConversionType.pdf);
      expect(provider.documents.length, 1);
      expect(provider.documents.first.fileName, 'Finance_Report.pdf');

      // DOCS filter
      provider.setTypeFilter(ConversionType.docs);
      expect(provider.documents.length, 1);
      expect(provider.documents.first.fileName, 'Meeting_Notes.docx');

      // PPT filter
      provider.setTypeFilter(ConversionType.ppt);
      expect(provider.documents.length, 1);
      expect(provider.documents.first.fileName, 'Quarterly_Pitch.pptx');
    });
  });
}

class _FakeMultiFormatStorageService extends PdfStorageService {
  final List<PdfDocument> _docs;

  _FakeMultiFormatStorageService(this._docs);

  @override
  Future<List<PdfDocument>> loadAllDocuments() async {
    return List.from(_docs);
  }
}
