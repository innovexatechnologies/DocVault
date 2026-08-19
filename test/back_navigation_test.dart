import 'package:doc_vault/core/providers/image_selection_provider.dart';
import 'package:doc_vault/core/providers/pdf_manager_provider.dart';
import 'package:doc_vault/core/services/pdf_storage_service.dart';
import 'package:doc_vault/features/home/main_navigation_screen.dart';
import 'package:doc_vault/features/home/source_selection_screen.dart';
import 'package:doc_vault/features/image_selection/gallery_screen.dart';
import 'package:doc_vault/features/pdf_generation/review_screen.dart';
import 'package:doc_vault/features/pdf_result/result_screen.dart';
import 'package:doc_vault/models/pdf_document.dart';
import 'package:doc_vault/models/pdf_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class MockPdfStorageService extends PdfStorageService {
  @override
  Future<List<PdfDocument>> loadAllDocuments() async => [];
}

void main() {
  testWidgets('SourceSelectionScreen back button pops screen', (tester) async {
    bool didPop = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialAppPageRoute(
                      builder: (_) => const SourceSelectionScreen(),
                    ),
                  ).then((_) {
                    didPop = true;
                  });
                },
                child: const Text('Go to Source'),
              ),
            );
          },
        ),
      ),
    );

    // Navigate to SourceSelectionScreen
    await tester.tap(find.text('Go to Source'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Source'), findsOneWidget);

    // Tap back button
    final backButton = find.byIcon(Icons.arrow_back_rounded);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(didPop, isTrue);
  });

  testWidgets('GalleryScreen back button pops screen', (tester) async {
    bool didPop = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ImageSelectionProvider()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialAppPageRoute(
                        builder: (_) => const GalleryScreen(),
                      ),
                    ).then((_) {
                      didPop = true;
                    });
                  },
                  child: const Text('Go to Gallery'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go to Gallery'));
    await tester.pumpAndSettle();

    final backButton = find.byIcon(Icons.arrow_back_rounded);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(didPop, isTrue);
  });

  testWidgets('ReviewScreen back button pops screen when not reordering', (tester) async {
    bool didPop = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ImageSelectionProvider()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialAppPageRoute(
                        builder: (_) => const ReviewScreen(),
                      ),
                    ).then((_) {
                      didPop = true;
                    });
                  },
                  child: const Text('Go to Review'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go to Review'));
    await tester.pumpAndSettle();

    final backButton = find.byIcon(Icons.arrow_back_rounded);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(didPop, isTrue);
  });

  testWidgets('ResultScreen back button navigates to home', (tester) async {
    final pdfResult = PdfResult(
      filePath: '/storage/sample.pdf',
      fileName: 'sample.pdf',
      pageCount: 1,
      generatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ImageSelectionProvider()),
          ChangeNotifierProvider(create: (_) => PdfManagerProvider(storageService: MockPdfStorageService())),
        ],
        child: MaterialApp(
          routes: {
            '/home': (_) => const MainNavigationScreen(initialIndex: 0),
          },
          home: ResultScreen(pdfResult: pdfResult),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final backButton = find.byIcon(Icons.arrow_back_rounded);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.text('Your documents.'), findsOneWidget);
  });
}

class MaterialAppPageRoute<T> extends MaterialPageRoute<T> {
  MaterialAppPageRoute({required super.builder});
}
