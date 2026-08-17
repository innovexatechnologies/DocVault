import 'package:doc_vault/features/pdf_result/pdf_viewer_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/image_selection_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/external_pdf_service.dart';

import 'features/splash/splash_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/source_selection_screen.dart';
import 'features/camera/camera_screen.dart';
import 'features/image_selection/gallery_screen.dart';
import 'features/pdf_generation/review_screen.dart';
import 'features/pdf_generation/pdf_generation_screen.dart';
import 'features/pdf_result/result_screen.dart';

import 'models/pdf_result.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const MethodChannel _channel =
      MethodChannel('docvault/pdf_intent');

  @override
  void initState() {
    super.initState();

    // ============================================================
    // ANDROID PDF INTENT HANDLING
    // ============================================================
    //
    // MethodChannel sirf Android par use hoga.
    // Chrome/Web par is code ko run nahi karna.
    //

    if (!kIsWeb) {
      _channel.setMethodCallHandler(_handleNativeCall);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForIncomingPdf();
      });
    }
  }

  // ============================================================
  // APP CLOSED → OPEN WITH DOCVAULT
  // ============================================================

  Future<void> _checkForIncomingPdf() async {
    // Safety check
    if (kIsWeb) {
      return;
    }

    try {
      final result = await _channel.invokeMethod(
        'getInitialPdf',
      );

      if (result == null) {
        return;
      }

      final data = Map<Object?, Object?>.from(result);

      final uri = data['uri']?.toString();

      if (uri == null || uri.isEmpty) {
        return;
      }

      debugPrint(
        'Incoming PDF URI: $uri',
      );

      // SplashScreen ko initialize hone ka time
      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) {
        return;
      }

      await _openIncomingPdf(uri);
    } catch (e) {
      debugPrint(
        'Error receiving external PDF: $e',
      );
    }
  }

  // ============================================================
  // APP ALREADY OPEN → NEW PDF
  // ============================================================

  Future<void> _handleNativeCall(
    MethodCall call,
  ) async {
    // Web par Android native calls ignore
    if (kIsWeb) {
      return;
    }

    if (call.method == 'newPdf') {
      try {
        final arguments =
            Map<Object?, Object?>.from(
          call.arguments as Map,
        );

        final uri =
            arguments['uri']?.toString();

        if (uri == null || uri.isEmpty) {
          return;
        }

        debugPrint(
          'New incoming PDF: $uri',
        );

        await _openIncomingPdf(uri);
      } catch (e) {
        debugPrint(
          'Error handling new PDF: $e',
        );
      }
    }
  }

  // ============================================================
  // IMPORT + SAVE + VIEW PDF
  // ============================================================

  Future<void> _openIncomingPdf(
    String uri,
  ) async {
    // Android only
    if (kIsWeb) {
      return;
    }

    try {
      debugPrint(
        'Importing PDF: $uri',
      );

      final result =
          await ExternalPdfService.importPdfFromUri(
        uri,
      );

      if (!mounted) {
        return;
      }

      final savedPath =
          result['filePath'] as String;

      final fileName =
          result['fileName'] as String;

      debugPrint(
        'PDF saved at: $savedPath',
      );

      debugPrint(
        'PDF file name: $fileName',
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            filePath: savedPath,
            fileName: fileName,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'External PDF import error: $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open PDF: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ========================================================
        // IMAGE SELECTION PROVIDER
        // ========================================================

        ChangeNotifierProvider(
          create: (_) => ImageSelectionProvider(),
        ),

        // ========================================================
        // THEME PROVIDER
        // ========================================================

        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
      ],

      child: Consumer<ThemeProvider>(
        builder: (
          context,
          themeProvider,
          child,
        ) {
          return MaterialApp(
            // ====================================================
            // APP INFORMATION
            // ====================================================

            title: 'DocVault',

            debugShowCheckedModeBanner: false,

            // ====================================================
            // LIGHT THEME
            // ====================================================

            theme: AppTheme.lightTheme(),

            // ====================================================
            // DARK THEME
            // ====================================================

            darkTheme: AppTheme.darkTheme(),

            // ====================================================
            // CURRENT THEME
            // ====================================================

            themeMode: themeProvider.themeMode,

            // ====================================================
            // INITIAL SCREEN
            // ====================================================

            home: const SplashScreen(),

            // ====================================================
            // ROUTES
            // ====================================================

            routes: {
              '/splash': (context) =>
                  const SplashScreen(),

              '/home': (context) =>
                  const HomeScreen(),

              '/source-selection': (context) =>
                  const SourceSelectionScreen(),

              '/camera': (context) =>
                  const CameraScreen(),

              '/gallery': (context) =>
                  const GalleryScreen(),

              '/review': (context) =>
                  const ReviewScreen(),

              '/pdf-generation': (context) =>
                  const PdfGenerationScreen(),
            },

            // ====================================================
            // DYNAMIC ROUTES
            // ====================================================

            onGenerateRoute: (settings) {
              if (settings.name == '/result') {
                final pdfResult =
                    settings.arguments as PdfResult;

                return MaterialPageRoute(
                  builder: (context) =>
                      ResultScreen(
                    pdfResult: pdfResult,
                  ),
                );
              }

              return null;
            },
          );
        },
      ),
    );
  }
}