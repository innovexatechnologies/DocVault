import 'package:doc_vault/core/providers/image_selection_provider.dart';
import 'package:doc_vault/features/pdf_generation/review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('ReviewScreen reorder mode toggles safely', (tester) async {
    final provider = ImageSelectionProvider();
    provider.addImages(['a.png', 'b.png', 'c.png'], 'gallery');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ReviewScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('Reorder'), findsOneWidget);
    await tester.tap(find.text('Reorder'));
    await tester.pump();

    expect(find.text('Done'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsWidgets);
    expect(find.byIcon(Icons.arrow_downward), findsWidgets);
  });
}
