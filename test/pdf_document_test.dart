import 'package:doc_vault/models/pdf_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfDocument Model Tests', () {
    test('formats file size correctly', () {
      final doc1 = PdfDocument(
        id: '1',
        fileName: 'Test1.pdf',
        filePath: '/path/Test1.pdf',
        fileSizeBytes: 500,
        pageCount: 1,
        createdAt: DateTime(2026, 8, 19, 10, 30),
        modifiedAt: DateTime(2026, 8, 19, 10, 30),
      );
      expect(doc1.formattedFileSize, '500 B');

      final doc2 = doc1.copyWith(fileSizeBytes: 2048);
      expect(doc2.formattedFileSize, '2.0 KB');

      final doc3 = doc1.copyWith(fileSizeBytes: 2 * 1024 * 1024 + 512 * 1024);
      expect(doc3.formattedFileSize, '2.50 MB');
    });

    test('extracts base name without .pdf extension', () {
      final doc1 = PdfDocument(
        id: '1',
        fileName: 'Invoice_2026.pdf',
        filePath: '/path/Invoice_2026.pdf',
        fileSizeBytes: 1000,
        pageCount: 2,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );
      expect(doc1.baseName, 'Invoice_2026');

      final doc2 = doc1.copyWith(fileName: 'Invoice_2026');
      expect(doc2.baseName, 'Invoice_2026');
    });

    test('serializes to and from JSON correctly', () {
      final now = DateTime(2026, 8, 19, 10, 30, 0);
      final doc = PdfDocument(
        id: 'doc-uuid-123',
        fileName: 'Receipt.pdf',
        filePath: '/documents/Receipt.pdf',
        fileSizeBytes: 1048576,
        pageCount: 4,
        createdAt: now,
        modifiedAt: now,
      );

      final jsonStr = doc.toJson();
      final restored = PdfDocument.fromJson(jsonStr);

      expect(restored.id, doc.id);
      expect(restored.fileName, doc.fileName);
      expect(restored.filePath, doc.filePath);
      expect(restored.fileSizeBytes, doc.fileSizeBytes);
      expect(restored.pageCount, doc.pageCount);
      expect(restored.createdAt, doc.createdAt);
      expect(restored.modifiedAt, doc.modifiedAt);
    });

    test('formats created and modified dates properly', () {
      final dt = DateTime(2026, 8, 19, 14, 5);
      final doc = PdfDocument(
        id: '1',
        fileName: 'Doc.pdf',
        filePath: '/path/Doc.pdf',
        fileSizeBytes: 100,
        pageCount: 1,
        createdAt: dt,
        modifiedAt: dt,
      );

      expect(doc.formattedCreatedDate, 'Aug 19, 2026 • 2:05 PM');
    });
  });
}
