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
  // PDF / DOCUMENT INTENT CHANNEL
  // ============================================================

  static const MethodChannel _channel =
      MethodChannel('docvault/pdf_intent');

  // ============================================================
  // EXTERNAL DOCUMENT STATE
  // ============================================================

  bool _checkingInitialDocument = true;

  String? _initialExternalUri;

  bool _isOpeningExternalDocument = false;

  String? _lastProcessedUri;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      _channel.setMethodCallHandler(_handleNativeCall);

      _checkForInitialDocument();
    } else {
      _checkingInitialDocument = false;
    }
  }

  // ============================================================
  // CHECK INITIAL EXTERNAL DOCUMENT
  // ============================================================

  Future<void> _checkForInitialDocument() async {
    try {
      debugPrint(
        'Checking for initial external document...',
      );

      final result =
          await _channel.invokeMethod('getInitialDocument');

      if (result != null) {
        final data =
            Map<Object?, Object?>.from(result);

        final uri =
            data['uri']?.toString();

        if (uri != null && uri.isNotEmpty) {
          debugPrint(
            'Initial external document found: $uri',
          );

          if (mounted) {
            setState(() {
              _initialExternalUri = uri;
              _checkingInitialDocument = false;
            });
          }

          return;
        }
      }

      debugPrint(
        'No initial external document found.',
      );
    } catch (e) {
      debugPrint(
        'Initial document check error: $e',
      );
    }

    if (mounted) {
      setState(() {
        _checkingInitialDocument = false;
      });
    }
  }

  // ============================================================
  // HANDLE NEW DOCUMENT WHILE APP IS RUNNING
  // ============================================================

  Future<void> _handleNativeCall(
    MethodCall call,
  ) async {
    if (kIsWeb) {
      return;
    }

    if (call.method != 'newDocument' &&
        call.method != 'newPdf') {
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
        debugPrint(
          'New document URI is empty.',
        );
        return;
      }

      debugPrint(
        'New external document received: $uri',
      );

      await _openIncomingDocument(uri);
    } catch (e) {
      debugPrint(
        'New document handling error: $e',
      );
    }
  }

  // ============================================================
  // OPEN EXTERNAL DOCUMENT
  // ============================================================

  Future<void> _openIncomingDocument(
    String uri,
  ) async {
    if (kIsWeb) {
      return;
    }

    if (_isOpeningExternalDocument) {
      debugPrint(
        'External document is already opening.',
      );
      return;
    }

    if (_lastProcessedUri == uri) {
      debugPrint(
        'External document already processed: $uri',
      );
      return;
    }

    _isOpeningExternalDocument = true;

    try {
      debugPrint(
        'Importing external document...',
      );

      final result =
          await ExternalPdfService.importDocumentFromUri(
        uri,
      );

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
          'Document file path is empty.',
        );
      }

      if (fileName == null ||
          fileName.isEmpty) {
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

      _lastProcessedUri = uri;

      final navigator =
          MyApp.navigatorKey.currentState;

      if (navigator == null) {
        throw Exception(
          'Navigator is not ready.',
        );
      }

      // ========================================================
      // IMPORTANT
      //
      // pushReplacement removes the current startup screen.
      // Therefore HomeScreen will NOT remain underneath.
      // ========================================================

      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            filePath: savedPath,
            fileName: fileName,
            isExternal: true,
          ),
        ),
      );

      debugPrint(
        'External document viewer opened.',
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
      _isOpeningExternalDocument = false;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ImageSelectionProvider(),
        ),

        ChangeNotifierProvider(
          create: (_) => PdfManagerProvider(),
        ),

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

            title: 'DocVault',

            debugShowCheckedModeBanner: false,

            theme: AppTheme.lightTheme(),

            darkTheme: AppTheme.darkTheme(),

            themeMode: themeProvider.themeMode,

            // ==================================================
            // STARTUP SCREEN
            // ==================================================

            home: _checkingInitialDocument
                ? const _ExternalDocumentCheckingScreen()
                : _initialExternalUri != null
                    ? _InitialExternalDocumentScreen(
                        uri: _initialExternalUri!,
                        onOpen: _openIncomingDocument,
                      )
                    : const SplashScreen(),

            // ==================================================
            // STATIC ROUTES
            // ==================================================

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

            // ==================================================
            // DYNAMIC ROUTES
            // ==================================================

            onGenerateRoute: (settings) {
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

              if (settings.name == '/all-files') {
                return MaterialPageRoute(
                  builder: (context) =>
                      const MainNavigationScreen(
                    initialIndex: 1,
                  ),
                );
              }

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
}

// ================================================================
// INITIAL DOCUMENT CHECKING SCREEN
// ================================================================
//
// This screen is shown only for a very short time while Flutter
// asks Android whether the app was launched with an external file.
//
// IMPORTANT:
// It does NOT navigate to HomeScreen.
//

class _ExternalDocumentCheckingScreen
    extends StatelessWidget {
  const _ExternalDocumentCheckingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// ================================================================
// INITIAL EXTERNAL DOCUMENT SCREEN
// ================================================================
//
// This screen is used ONLY when DocVault was launched by an
// external PDF/DOCX/PPTX file.
//
// It directly starts document import.
// HomeScreen is never shown.
//

class _InitialExternalDocumentScreen
    extends StatefulWidget {
  const _InitialExternalDocumentScreen({
    required this.uri,
    required this.onOpen,
  });

  final String uri;

  final Future<void> Function(
    String uri,
  ) onOpen;

  @override
  State<_InitialExternalDocumentScreen> createState() =>
      _InitialExternalDocumentScreenState();
}

class _InitialExternalDocumentScreenState
    extends State<_InitialExternalDocumentScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startOpening();
    });
  }

  Future<void> _startOpening() async {
    if (_started) {
      return;
    }

    _started = true;

    await widget.onOpen(widget.uri);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}