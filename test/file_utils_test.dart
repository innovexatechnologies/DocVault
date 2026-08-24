import 'package:doc_vault/core/utils/file_utils.dart';
import 'package:doc_vault/models/conversion_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      expect(FileUtils.normalizePdfFileName(''), 'DocVault_Document.pdf');
      expect(FileUtils.normalizePdfFileName('   '), 'DocVault_Document.pdf');
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
}
