import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doc_vault/core/services/external_pdf_service.dart';
import 'package:doc_vault/models/conversion_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExternalPdfService External Document Import Tests', () {
    const channel = MethodChannel('docvault/pdf_intent');
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('docvault_ext_test');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          return tempDir.path;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        final args = methodCall.arguments as Map?;
        final uri = args?['uri'] as String? ?? '';

        if (uri.contains('invalid_empty')) {
          return {
            'bytes': <int>[],
            'fileName': 'empty.pdf',
            'mimeType': 'application/pdf',
          };
        }

        if (uri.contains('unsupported_exe')) {
          return {
            'bytes': [1, 2, 3, 4],
            'fileName': 'program.exe',
            'mimeType': 'application/octet-stream',
          };
        }

        if (uri.contains('sample_docx_no_ext')) {
          return {
            'bytes': [80, 75, 3, 4, 0, 0], // PK zip header for docx
            'fileName': 'ExternalDocReport',
            'mimeType':
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document; charset=UTF-8',
          };
        }

        if (uri.contains('sample_pptx_no_ext')) {
          return {
            'bytes': [80, 75, 3, 4, 1, 1], // PK zip header for pptx
            'fileName': 'PitchDeck_Final',
            'mimeType':
                'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          };
        }

        if (uri.contains('sample_pdf')) {
          return {
            'bytes': [37, 80, 68, 70, 45, 49, 46, 53], // %PDF-1.5
            'fileName': 'Contract_2026.pdf',
            'mimeType': 'application/pdf',
          };
        }

        return {
          'bytes': [1, 2, 3],
          'fileName': 'unknown_file',
          'mimeType': 'application/octet-stream',
        };
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('Successfully imports external PDF', () async {
      final result = await ExternalPdfService.importDocumentFromUri(
        'content://com.android.providers.downloads/sample_pdf',
      );

      expect(result['filePath'], isNotNull);
      expect(result['fileName'], endsWith('.pdf'));
      expect(result['type'], equals(ConversionType.pdf));

      final file = File(result['filePath'] as String);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));
    });

    test('Successfully imports external DOCX without extension via MIME type',
        () async {
      final result = await ExternalPdfService.importDocumentFromUri(
        'content://com.google.android.apps.docs.storage/sample_docx_no_ext',
      );

      expect(result['filePath'], isNotNull);
      expect(result['fileName'], endsWith('.docx'));
      expect(result['type'], equals(ConversionType.docs));

      final file = File(result['filePath'] as String);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));
    });

    test('Successfully imports external PPTX without extension via MIME type',
        () async {
      final result = await ExternalPdfService.importDocumentFromUri(
        'content://org.telegram.messenger.provider/sample_pptx_no_ext',
      );

      expect(result['filePath'], isNotNull);
      expect(result['fileName'], endsWith('.pptx'));
      expect(result['type'], equals(ConversionType.ppt));

      final file = File(result['filePath'] as String);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));
    });

    test('Throws exception when external document is empty', () async {
      expect(
        () => ExternalPdfService.importDocumentFromUri(
          'content://downloads/invalid_empty',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Throws exception when external document has unsupported format',
        () async {
      expect(
        () => ExternalPdfService.importDocumentFromUri(
          'content://downloads/unsupported_exe',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
