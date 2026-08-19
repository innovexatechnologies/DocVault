import 'package:doc_vault/core/providers/pdf_manager_provider.dart';
import 'package:doc_vault/core/services/pdf_storage_service.dart';
import 'package:doc_vault/features/all_files/all_files_screen.dart';
import 'package:doc_vault/models/pdf_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class MockPdfStorageService extends PdfStorageService {
  final List<PdfDocument> initialDocs;

  MockPdfStorageService([this.initialDocs = const []]);

  @override
  Future<List<PdfDocument>> loadAllDocuments() async {
    return List.from(initialDocs);
  }
}

void main() {
  testWidgets('AllFilesScreen shows empty state when no files exist', (tester) async {
    final provider = PdfManagerProvider(
      storageService: MockPdfStorageService([]),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<PdfManagerProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: AllFilesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('All Files'), findsOneWidget);
    expect(find.text('No PDFs saved yet'), findsOneWidget);
    expect(find.text('Create PDF'), findsOneWidget);
  });

  testWidgets('AllFilesScreen displays PDF document cards and triggers search', (tester) async {
    final sampleDocs = [
      PdfDocument(
        id: '1',
        fileName: 'Invoice_May.pdf',
        filePath: '/storage/Invoice_May.pdf',
        fileSizeBytes: 1024 * 1024,
        pageCount: 2,
        createdAt: DateTime(2026, 8, 19, 10, 0),
        modifiedAt: DateTime(2026, 8, 19, 10, 0),
      ),
      PdfDocument(
        id: '2',
        fileName: 'Resume_2026.pdf',
        filePath: '/storage/Resume_2026.pdf',
        fileSizeBytes: 512 * 1024,
        pageCount: 1,
        createdAt: DateTime(2026, 8, 18, 10, 0),
        modifiedAt: DateTime(2026, 8, 18, 10, 0),
      ),
    ];

    final provider = PdfManagerProvider(
      storageService: MockPdfStorageService(sampleDocs),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<PdfManagerProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: AllFilesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Invoice_May.pdf'), findsOneWidget);
    expect(find.text('Resume_2026.pdf'), findsOneWidget);

    // Tap search icon in app bar
    final searchIcon = find.byIcon(Icons.search_rounded);
    expect(searchIcon, findsOneWidget);
    await tester.tap(searchIcon);
    await tester.pumpAndSettle();

    // Type query
    await tester.enterText(find.byType(TextField), 'Resume');
    await tester.pumpAndSettle();

    expect(find.text('Resume_2026.pdf'), findsOneWidget);
    expect(find.text('Invoice_May.pdf'), findsNothing);
  });

  testWidgets('AllFilesScreen enters selection mode', (tester) async {
    final sampleDocs = [
      PdfDocument(
        id: '1',
        fileName: 'Doc1.pdf',
        filePath: '/storage/Doc1.pdf',
        fileSizeBytes: 1024,
        pageCount: 1,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      ),
    ];

    final provider = PdfManagerProvider(
      storageService: MockPdfStorageService(sampleDocs),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<PdfManagerProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: AllFilesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap checklist icon to enter selection mode
    final selectIcon = find.byIcon(Icons.checklist_rounded);
    expect(selectIcon, findsOneWidget);
    await tester.tap(selectIcon);
    await tester.pumpAndSettle();

    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('Select All'), findsOneWidget);
  });
}
