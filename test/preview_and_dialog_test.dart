import 'package:doc_vault/core/providers/image_selection_provider.dart';
import 'package:doc_vault/core/widgets/unsaved_changes_dialog.dart';
import 'package:doc_vault/features/pdf_generation/preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('UnsavedChangesDialog renders and handles actions', (tester) async {
    UnsavedChangesAction? actionTaken;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                actionTaken = await UnsavedChangesDialog.show(
                  context,
                  title: 'Test Title',
                  message: 'Test Message',
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Test Title'), findsOneWidget);
    expect(find.text('Test Message'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(actionTaken, UnsavedChangesAction.save);
  });

  testWidgets('PreviewScreen shows empty state when no images present', (tester) async {
    final provider = ImageSelectionProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: PreviewScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('No pages to preview'), findsOneWidget);
  });
}
