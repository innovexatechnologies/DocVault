import 'dart:io';
import 'package:doc_vault/core/providers/image_selection_provider.dart';
import 'package:doc_vault/core/providers/pdf_manager_provider.dart';
import 'package:doc_vault/core/services/pdf_storage_service.dart';
import 'package:doc_vault/core/widgets/unsaved_changes_dialog.dart';
import 'package:doc_vault/features/pdf_generation/review_screen.dart';
import 'package:doc_vault/models/pdf_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

class MockPdfStorageService extends PdfStorageService {
  final List<PdfDocument> storedDocs = [];
  bool wasUpdateCalled = false;

  @override
  Future<List<PdfDocument>> loadAllDocuments() async => storedDocs;

  @override
  Future<PdfDocument> updateDocumentContent({
    required String id,
    required List<String> imagePaths,
  }) async {
    wasUpdateCalled = true;
    final index = storedDocs.indexWhere((d) => d.id == id);
    final existing = storedDocs[index];
    final updated = existing.copyWith(
      pageCount: imagePaths.length,
      modifiedAt: DateTime.now(),
    );
    storedDocs[index] = updated;
    return updated;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dummyImagePath;
  late String dummyImagePath2;
  late PdfDocument sampleDoc;
  late MockPdfStorageService mockStorageService;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('existing_pdf_test');
    dummyImagePath = '${tempDir.path}/page_1.jpg';
    dummyImagePath2 = '${tempDir.path}/page_2.jpg';

    final sampleImg = img.Image(width: 100, height: 100);
    await File(dummyImagePath).writeAsBytes(img.encodeJpg(sampleImg));
    await File(dummyImagePath2).writeAsBytes(img.encodeJpg(sampleImg));
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() {
    mockStorageService = MockPdfStorageService();
    sampleDoc = PdfDocument(
      id: 'doc-123',
      fileName: 'My Vacation 2026.pdf',
      filePath: '${tempDir.path}/My Vacation 2026.pdf',
      fileSizeBytes: 1024,
      pageCount: 2,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
    mockStorageService.storedDocs.add(sampleDoc);
  });

  Widget buildReviewScreen({
    required ImageSelectionProvider imageProvider,
    required PdfManagerProvider pdfProvider,
    PdfDocument? existingDocument,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ImageSelectionProvider>.value(value: imageProvider),
        ChangeNotifierProvider<PdfManagerProvider>.value(value: pdfProvider),
      ],
      child: MaterialApp(
        home: ReviewScreen(existingDocument: existingDocument),
      ),
    );
  }

  testWidgets('ReviewScreen in existing PDF edit mode displays title and Save Changes button', (tester) async {
    final imageProvider = ImageSelectionProvider();
    imageProvider.addImages([dummyImagePath, dummyImagePath2], 'existing_pdf', markUnsaved: false);

    final pdfProvider = PdfManagerProvider(storageService: mockStorageService);

    await tester.pumpWidget(
      buildReviewScreen(
        imageProvider: imageProvider,
        pdfProvider: pdfProvider,
        existingDocument: sampleDoc,
      ),
    );
    await tester.pumpAndSettle();

    // Verify document title displayed in AppBar
    expect(find.text('My Vacation 2026'), findsOneWidget);
    expect(find.text('2 pages'), findsOneWidget);

    // Verify Save Changes button
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.byIcon(Icons.save_rounded), findsOneWidget);
  });

  testWidgets('ReviewScreen saves changes and calls updateDocumentContent on existing PDF', (tester) async {
    final imageProvider = ImageSelectionProvider();
    imageProvider.addImages([dummyImagePath, dummyImagePath2], 'existing_pdf', markUnsaved: false);

    final pdfProvider = PdfManagerProvider(storageService: mockStorageService);

    await tester.pumpWidget(
      buildReviewScreen(
        imageProvider: imageProvider,
        pdfProvider: pdfProvider,
        existingDocument: sampleDoc,
      ),
    );
    await tester.pumpAndSettle();

    // Tap Save Changes
    final saveButton = find.text('Save Changes');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(mockStorageService.wasUpdateCalled, isTrue);
  });

  testWidgets('ReviewScreen pops directly on back when no unsaved changes were made to existing PDF', (tester) async {
    bool didPop = false;
    final imageProvider = ImageSelectionProvider();
    imageProvider.addImages([dummyImagePath], 'existing_pdf', markUnsaved: false);

    final pdfProvider = PdfManagerProvider(storageService: mockStorageService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ImageSelectionProvider>.value(value: imageProvider),
          ChangeNotifierProvider<PdfManagerProvider>.value(value: pdfProvider),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReviewScreen(existingDocument: sampleDoc),
                      ),
                    ).then((_) {
                      didPop = true;
                    });
                  },
                  child: const Text('Open Editor'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Editor'));
    await tester.pumpAndSettle();

    // Tap back button
    final backButton = find.byIcon(Icons.arrow_back_rounded);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // No dialog shown, popped directly
    expect(find.byType(UnsavedChangesDialog), findsNothing);
    expect(didPop, isTrue);
  });

  testWidgets('ReviewScreen shows UnsavedChangesDialog on back when changes were made and can discard', (tester) async {
    bool didPop = false;
    final imageProvider = ImageSelectionProvider();
    imageProvider.addImages([dummyImagePath], 'existing_pdf', markUnsaved: false);

    final pdfProvider = PdfManagerProvider(storageService: mockStorageService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ImageSelectionProvider>.value(value: imageProvider),
          ChangeNotifierProvider<PdfManagerProvider>.value(value: pdfProvider),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReviewScreen(existingDocument: sampleDoc),
                      ),
                    ).then((_) {
                      didPop = true;
                    });
                  },
                  child: const Text('Open Editor'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Editor'));
    await tester.pumpAndSettle();

    // Modify images (delete a page) to trigger unsaved changes
    imageProvider.removeImage(imageProvider.selectedImages.first.id);
    await tester.pumpAndSettle();

    // Tap back button
    final backButton = find.byIcon(Icons.arrow_back_rounded);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.byType(UnsavedChangesDialog), findsOneWidget);
    expect(find.text('Discard Changes?'), findsOneWidget);

    // Tap Discard Changes
    final discardButton = find.text('Discard Changes');
    await tester.tap(discardButton);
    await tester.pumpAndSettle();

    expect(didPop, isTrue);
    expect(mockStorageService.wasUpdateCalled, isFalse);
  });
}
