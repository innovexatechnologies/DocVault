import 'package:doc_vault/core/utils/file_utils.dart';
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
}
