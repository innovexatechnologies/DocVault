import 'package:doc_vault/features/pdf_result/pdf_viewer_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/image_selection_provider.dart';
import 'core/providers/pdf_manager_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/external_pdf_service.dart';

import 'features/splash/splash_screen.dart';
import 'features/home/main_navigation_screen.dart';
import 'features/home/source_selection_screen.dart';
import 'features/camera/camera_screen.dart';
import 'features/image_selection/gallery_screen.dart';
import 'features/pdf_generation/review_screen.dart';
import 'features/pdf_generation/preview_screen.dart';
import 'features/pdf_generation/pdf_generation_screen.dart';
import 'features/pdf_result/result_screen.dart';

import 'models/pdf_result.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

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
  // EXTERNAL PDF STATE
  // ============================================================

  bool _isOpeningExternalPdf = false;
  String? _lastProcessedUri;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      _channel.setMethodCallHandler(_handleNativeCall);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForIncomingPdf();
      });
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
      final result = await _channel.invokeMethod('getInitialDocument');
      final documentData = result ?? await _channel.invokeMethod('getInitialPdf');

      if (documentData == null) {
        debugPrint('No external document found.');
        return;
      }

      final data = Map<Object?, Object?>.from(documentData);

      final uri = data['uri']?.toString();

      if (uri == null || uri.isEmpty) {
        debugPrint('External document URI is empty.');
        return;
      }

      debugPrint('Initial external document: $uri');

      // ========================================================
      // IMPORTANT
      //
      // SplashScreen takes 2 seconds to finish.
      //
      // We wait slightly longer than the splash duration so that
      // SplashScreen cannot replace PdfViewerScreen with Home.
      // ========================================================

      await Future.delayed(
        const Duration(milliseconds: 2300),
      );

      if (!mounted) {
        return;
      }

      await _openIncomingPdf(uri);
    } catch (e) {
      debugPrint(
        'Initial document error: $e',
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

    final isSupportedDocumentIntent =
        call.method == 'newDocument' || call.method == 'newPdf';

    if (!isSupportedDocumentIntent) {
      return;
    }

    try {
      if (call.arguments == null) {
        return;
      }

      final arguments = Map<Object?, Object?>.from(
        call.arguments as Map,
      );

      final uri = arguments['uri']?.toString();

      if (uri == null || uri.isEmpty) {
        debugPrint('New document URI is empty.');
        return;
      }

      debugPrint(
        'New external document received: $uri',
      );

      // App is already running, so we don't need to wait for splash.
      await _openIncomingPdf(uri);
    } catch (e) {
      debugPrint(
        'New document handling error: $e',
      );
    }
  }

  // ============================================================
  // IMPORT AND OPEN EXTERNAL PDF
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
        'Importing external document...',
      );

      // ========================================================
      // READ DOCUMENT FROM ANDROID CONTENT URI
      // ========================================================

      final result =
          await ExternalPdfService.importDocumentFromUri(uri);

      if (!mounted) {
        return;
      }

      final savedPath =
          result['filePath']?.toString();

      final fileName =
          result['fileName']?.toString();

      if (savedPath == null || savedPath.isEmpty) {
        throw Exception(
          'Document file path is empty.',
        );
      }

      if (fileName == null || fileName.isEmpty) {
        throw Exception(
          'Document file name is empty.',
        );
      }

      debugPrint(
        'Imported document path: $savedPath',
      );

      debugPrint(
        'Imported document name: $fileName',
      );

      // Mark URI as processed.
      _lastProcessedUri = uri;

      // ========================================================
      // OPEN PDF VIEWER
      // ========================================================

      final navigator =
          MyApp.navigatorKey.currentState;

      if (navigator == null) {
        throw Exception(
          'Navigator is not ready.',
        );
      }

      navigator.push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            filePath: savedPath,
            fileName: fileName,
            isExternal: true,
          ),
        ),
      );

      debugPrint(
        'External document viewer opened successfully.',
      );
    } catch (e) {
      debugPrint(
        'External document import error: $e',
      );

      if (!mounted) {
        return;
      }

      final messenger =
          ScaffoldMessenger.maybeOf(context);

      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open document: $e',
          ),
          behavior: SnackBarBehavior.floating,
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
          create: (_) => ImageSelectionProvider(),
        ),

        // ========================================================
        // PDF MANAGER
        // ========================================================

        ChangeNotifierProvider(
          create: (_) => PdfManagerProvider(),
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
            navigatorKey: MyApp.navigatorKey,

            // ====================================================
            // APP INFORMATION
            // ====================================================

            title: 'DocVault',

            debugShowCheckedModeBanner: false,

            // ====================================================
            // THEMES
            // ====================================================

            theme: AppTheme.lightTheme(),

            darkTheme: AppTheme.darkTheme(),

            themeMode: themeProvider.themeMode,

            // ====================================================
            // INITIAL SCREEN
            // ====================================================

            home: const SplashScreen(),

            // ====================================================
            // STATIC ROUTES
            // ====================================================

            routes: {
              '/splash': (context) =>
                  const SplashScreen(),

              '/source-selection': (context) =>
                  const SourceSelectionScreen(),

              '/camera': (context) =>
                  const CameraScreen(),

              '/gallery': (context) =>
                  const GalleryScreen(),

              '/review': (context) =>
                  const ReviewScreen(),

              '/preview': (context) =>
                  const PreviewScreen(),

              '/pdf-generation': (context) =>
                  const PdfGenerationScreen(),
            },

            // ====================================================
            // DYNAMIC ROUTES
            // ====================================================

            onGenerateRoute: (settings) {
              // --------------------------------------------------
              // HOME
              // --------------------------------------------------

              if (settings.name == '/home') {
                int initialIndex = 0;

                if (settings.arguments is Map) {
                  final map =
                      settings.arguments as Map;

                  initialIndex =
                      (map['initialIndex'] as num?)
                              ?.toInt() ??
                          0;
                }

                return MaterialPageRoute(
                  builder: (context) =>
                      MainNavigationScreen(
                    initialIndex: initialIndex,
                  ),
                );
              }

              // --------------------------------------------------
              // ALL FILES
              // --------------------------------------------------

              if (settings.name == '/all-files') {
                return MaterialPageRoute(
                  builder: (context) =>
                      const MainNavigationScreen(
                    initialIndex: 1,
                  ),
                );
              }

              // --------------------------------------------------
              // RESULT
              // --------------------------------------------------

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