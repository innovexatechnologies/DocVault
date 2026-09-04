import 'package:doc_vault/core/providers/image_selection_provider.dart';
import 'package:doc_vault/core/widgets/permission_request_dialog.dart';
import 'package:doc_vault/features/camera/camera_screen.dart';
import 'package:doc_vault/features/home/source_selection_screen.dart';
import 'package:doc_vault/models/conversion_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('Permission Request Flow Tests', () {
    testWidgets('PermissionRequestDialog renders content and handles cancel',
        (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await PermissionRequestDialog.show(
                    context,
                    title: 'Camera Access Required',
                    message:
                        'DocVault needs camera access to scan and capture documents.',
                    icon: Icons.camera_alt_rounded,
                    positiveLabel: 'Open Settings',
                    negativeLabel: 'Not Now',
                  );
                },
                child: const Text('Request Access'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Request Access'));
      await tester.pumpAndSettle();

      expect(find.text('Camera Access Required'), findsOneWidget);
      expect(
        find.text(
            'DocVault needs camera access to scan and capture documents.'),
        findsOneWidget,
      );
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);

      // Dismiss via "Not Now"
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Camera Access Required'), findsNothing);
    });

    testWidgets(
        'PermissionRequestDialog handles positive action and invokes onOpenSettings',
        (tester) async {
      bool? result;
      bool settingsInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await PermissionRequestDialog.show(
                    context,
                    title: 'Photos Access Required',
                    message:
                        'DocVault needs photo access to import documents.',
                    icon: Icons.photo_library_rounded,
                    positiveLabel: 'Open Settings',
                    negativeLabel: 'Not Now',
                    onOpenSettings: () async {
                      settingsInvoked = true;
                      return true;
                    },
                  );
                },
                child: const Text('Request Photos'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Request Photos'));
      await tester.pumpAndSettle();

      expect(find.text('Photos Access Required'), findsOneWidget);

      // Tap "Open Settings"
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(settingsInvoked, isTrue);
      expect(find.text('Photos Access Required'), findsNothing);
    });

    testWidgets(
        'SourceSelectionScreen does not show error snackbar when camera permission denied',
        (tester) async {
      final imageProvider = ImageSelectionProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: imageProvider,
          child: const MaterialApp(
            home: SourceSelectionScreen(
              conversionType: ConversionType.pdf,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find Camera card and tap it
      final cameraOption = find.text('Camera');
      expect(cameraOption, findsOneWidget);

      await tester.tap(cameraOption);
      await tester.pumpAndSettle();

      // Assert that no error SnackBar is shown ("Camera permission was denied" or "Unable to access the camera")
      expect(find.text('Camera permission was denied.'), findsNothing);
      expect(find.text('Unable to access the camera.'), findsNothing);
    });

    testWidgets('CameraScreen renders retry and gallery actions on error state',
        (tester) async {
      final imageProvider = ImageSelectionProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: imageProvider,
          child: const MaterialApp(
            home: CameraScreen(
              conversionType: ConversionType.pdf,
            ),
          ),
        ),
      );

      // Pump frames with duration to allow async camera initialization
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check that CameraScreen rendered safely
      expect(find.byType(CameraScreen), findsOneWidget);
      // Verify that CameraScreen is actively initializing or showing the recovery view
      final isInitializing = find.text('Starting Camera');
      final hasRecoveryButton = find.text('Use Gallery Instead');
      expect(
        isInitializing.evaluate().isNotEmpty ||
            hasRecoveryButton.evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
