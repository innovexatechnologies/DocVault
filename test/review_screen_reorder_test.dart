import 'dart:convert';
import 'dart:io';

import 'package:doc_vault/core/providers/image_selection_provider.dart';
import 'package:doc_vault/features/pdf_generation/review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('ReviewScreen reorder mode works without crashing', (
    tester,
  ) async {
    final tempDir = await Directory.systemTemp.createTemp('doc_vault_reorder_');
    final imageA = File('${tempDir.path}/a.png');
    final imageB = File('${tempDir.path}/b.png');
    final imageC = File('${tempDir.path}/c.png');

    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB4LqAAAAA1J0Uk5AAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYAAAAAIAAeIhvAAAAABJRU5ErkJggg==',
    );

    await imageA.writeAsBytes(png);
    await imageB.writeAsBytes(png);
    await imageC.writeAsBytes(png);

    final provider = ImageSelectionProvider();
    provider.addImages([imageA.path, imageB.path, imageC.path], 'gallery');

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

    expect(find.byType(ReorderableListView), findsOneWidget);

    final firstKey = ValueKey(provider.selectedImages[0].id);
    final secondKey = ValueKey(provider.selectedImages[1].id);

    await tester.longPress(find.byKey(firstKey));
    await tester.pump();
    await tester.drag(find.byKey(secondKey), const Offset(0, 120));
    await tester.pumpAndSettle();

    expect(provider.selectedImages.length, 3);
    expect(find.byType(ReorderableListView), findsOneWidget);
  });
}
