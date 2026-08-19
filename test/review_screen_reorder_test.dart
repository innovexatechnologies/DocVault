import 'dart:io';
import 'package:doc_vault/core/providers/image_selection_provider.dart';
import 'package:doc_vault/features/pdf_generation/review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String imgA;
  late String imgB;
  late String imgC;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('reorder_test');
    imgA = '${tempDir.path}/a.png';
    imgB = '${tempDir.path}/b.png';
    imgC = '${tempDir.path}/c.png';

    final sampleImg = img.Image(width: 50, height: 50);
    await File(imgA).writeAsBytes(img.encodePng(sampleImg));
    await File(imgB).writeAsBytes(img.encodePng(sampleImg));
    await File(imgC).writeAsBytes(img.encodePng(sampleImg));
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('ReviewScreen reorder mode toggles safely and displays drag handles', (tester) async {
    final provider = ImageSelectionProvider();
    provider.addImages([imgA, imgB, imgC], 'gallery');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ReviewScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reorder'), findsOneWidget);
    await tester.tap(find.text('Reorder'));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(3));

    // Reorder items programmatically via provider to simulate drag completion
    provider.reorderImages(0, 2);
    await tester.pumpAndSettle();

    expect(provider.selectedImages.map((e) => e.filePath).toList(), [
      imgB,
      imgA,
      imgC,
    ]);

    // Tap Done to exit reorder mode
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Reorder'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
  });
}
