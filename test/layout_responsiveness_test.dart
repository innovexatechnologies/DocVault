import 'dart:io';
import 'package:doc_vault/core/providers/image_selection_provider.dart';
import 'package:doc_vault/core/providers/pdf_manager_provider.dart';
import 'package:doc_vault/core/services/pdf_storage_service.dart';
import 'package:doc_vault/features/home/home_screen.dart';
import 'package:doc_vault/features/home/main_navigation_screen.dart';
import 'package:doc_vault/features/home/source_selection_screen.dart';
import 'package:doc_vault/features/image_editing/image_editor_screen.dart';
import 'package:doc_vault/features/pdf_generation/preview_screen.dart';
import 'package:doc_vault/features/pdf_generation/review_screen.dart';
import 'package:doc_vault/models/pdf_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

class MockPdfStorageService extends PdfStorageService {
  @override
  Future<List<PdfDocument>> loadAllDocuments() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dummyImagePath;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('layout_test');
    dummyImagePath = '${tempDir.path}/test_img.jpg';
    final sampleImg = img.Image(width: 200, height: 200);
    await File(dummyImagePath).writeAsBytes(img.encodeJpg(sampleImg));
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  final List<Size> testScreenSizes = [
    const Size(320, 568), // Smallest mobile (iPhone SE 1st gen)
    const Size(360, 640), // Standard Android
    const Size(390, 844), // iPhone 14
    const Size(768, 1024), // Tablet portrait
    const Size(844, 390), // Landscape mobile
  ];

  Widget buildTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final p = ImageSelectionProvider();
          p.addImages([dummyImagePath], 'gallery');
          return p;
        }),
        ChangeNotifierProvider(
          create: (_) => PdfManagerProvider(storageService: MockPdfStorageService()),
        ),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  for (final size in testScreenSizes) {
    testWidgets('HomeScreen renders without overflow at ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const HomeScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('SourceSelectionScreen renders without overflow at ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const SourceSelectionScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('ReviewScreen renders without overflow at ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const ReviewScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('PreviewScreen renders without overflow at ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const PreviewScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('ImageEditorScreen renders without overflow at ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestableWidget(
          ImageEditorScreen(
            imageId: 'test-id',
            imagePath: dummyImagePath,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('MainNavigationScreen renders without overflow at ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const MainNavigationScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
