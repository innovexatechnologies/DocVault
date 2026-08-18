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
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // ============================================================
  // PDF INTENT CHANNEL
  // ============================================================

  static const MethodChannel _channel =
      MethodChannel('docvault/pdf_intent');

  // ============================================================
  // PDF OPENING STATE
  // ============================================================

  bool _isOpeningExternalPdf = false;

  String? _lastProcessedUri;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // Android only
    if (!kIsWeb) {
      _channel.setMethodCallHandler(
        _handleNativeCall,
      );

      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          _checkForIncomingPdf();
        },
      );
    }
  }

  // ============================================================
  // APP CLOSED → OPEN PDF
  // ============================================================

  Future<void> _checkForIncomingPdf() async {
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

      final data =
          Map<Object?, Object?>.from(result);

      final uri =
          data['uri']?.toString();

      if (uri == null || uri.isEmpty) {
        return;
      }

      debugPrint(
        'Initial external PDF: $uri',
      );

      // Give Flutter/Splash time to initialize.
      await Future.delayed(
        const Duration(
          milliseconds: 700,
        ),
      );

      if (!mounted) {
        return;
      }

      await _openIncomingPdf(uri);
    } catch (e) {
      debugPrint(
        'Initial PDF error: $e',
      );
    }
  }

  // ============================================================
  // APP ALREADY OPEN → NEW PDF
  // ============================================================

  Future<void> _handleNativeCall(
    MethodCall call,
  ) async {
    if (kIsWeb) {
      return;
    }

    if (call.method != 'newPdf') {
      return;
    }

    try {
      if (call.arguments == null) {
        return;
      }

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
        'New external PDF: $uri',
      );

      await _openIncomingPdf(uri);
    } catch (e) {
      debugPrint(
        'New PDF handling error: $e',
      );
    }
  }

  // ============================================================
  // IMPORT EXTERNAL PDF
  // ============================================================

  Future<void> _openIncomingPdf(
    String uri,
  ) async {
    if (kIsWeb) {
      return;
    }

    // Prevent duplicate processing.
    if (_isOpeningExternalPdf) {
      debugPrint(
        'PDF is already being opened.',
      );
      return;
    }

    if (_lastProcessedUri == uri) {
      debugPrint(
        'PDF already processed: $uri',
      );
      return;
    }

    _isOpeningExternalPdf = true;

    try {
      debugPrint(
        'Importing external PDF...',
      );

      final result =
          await ExternalPdfService
              .importPdfFromUri(uri);

      if (!mounted) {
        return;
      }

      final savedPath =
          result['filePath']?.toString();

      final fileName =
          result['fileName']?.toString();

      if (savedPath == null ||
          savedPath.isEmpty) {
        throw Exception(
          'PDF file path is empty.',
        );
      }

      if (fileName == null ||
          fileName.isEmpty) {
        throw Exception(
          'PDF file name is empty.',
        );
      }

      debugPrint(
        'Imported PDF path: $savedPath',
      );

      debugPrint(
        'Imported PDF name: $fileName',
      );

      _lastProcessedUri = uri;

      // ========================================================
      // OPEN PDF VIEWER
      // ========================================================

      await Navigator.of(context).push(
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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open PDF: $e',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } finally {
      _isOpeningExternalPdf = false;
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    if (!kIsWeb) {
      _channel.setMethodCallHandler(null);
    }

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ========================================================
        // IMAGE SELECTION
        // ========================================================

        ChangeNotifierProvider(
          create: (_) =>
              ImageSelectionProvider(),
        ),

        // ========================================================
        // THEME
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

            theme:
                AppTheme.lightTheme(),

            // ====================================================
            // DARK THEME
            // ====================================================

            darkTheme:
                AppTheme.darkTheme(),

            // ====================================================
            // THEME MODE
            // ====================================================

            themeMode:
                themeProvider.themeMode,

            // ====================================================
            // INITIAL SCREEN
            // ====================================================

            home:
                const SplashScreen(),

            // ====================================================
            // ROUTES
            // ====================================================

            routes: {
              '/splash': (context) =>
                  const SplashScreen(),

              '/home': (context) =>
                  const HomeScreen(),

              '/source-selection':
                  (context) =>
                      const SourceSelectionScreen(),

              '/camera': (context) =>
                  const CameraScreen(),

              '/gallery': (context) =>
                  const GalleryScreen(),

              '/review': (context) =>
                  const ReviewScreen(),

              '/pdf-generation':
                  (context) =>
                      const PdfGenerationScreen(),
            },

            // ====================================================
            // DYNAMIC ROUTES
            // ====================================================

            onGenerateRoute:
                (settings) {
              if (settings.name ==
                  '/result') {
                final pdfResult =
                    settings.arguments
                        as PdfResult;

                return MaterialPageRoute(
                  builder:
                      (context) =>
                          ResultScreen(
                    pdfResult:
                        pdfResult,
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