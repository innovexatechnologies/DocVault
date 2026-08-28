import 'package:doc_vault/features/pdf_result/pdf_viewer_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/providers/image_selection_provider.dart';
import 'core/providers/pdf_manager_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/external_pdf_service.dart';
import 'core/theme/app_theme.dart';

import 'features/camera/camera_screen.dart';
import 'features/home/main_navigation_screen.dart';
import 'features/home/source_selection_screen.dart';
import 'features/image_selection/gallery_screen.dart';
import 'features/pdf_generation/pdf_generation_screen.dart';
import 'features/pdf_generation/preview_screen.dart';
import 'features/pdf_generation/review_screen.dart';
import 'features/pdf_result/result_screen.dart';
import 'features/splash/splash_screen.dart';

import 'models/pdf_result.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

// ============================================================================
// MY APP
// ============================================================================

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

    static final GlobalKey<ScaffoldMessengerState>
      scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

// ============================================================================
// APP STATE
// ============================================================================

class _MyAppState extends State<MyApp> {
  // ==========================================================================
  // NATIVE CHANNEL
  // ==========================================================================

  static const MethodChannel _channel =
      MethodChannel('docvault/pdf_intent');

  // ==========================================================================
  // EXTERNAL DOCUMENT STATE
  // ==========================================================================

  bool _checkingInitialDocument = true;

  String? _initialExternalUri;

  bool _isOpeningExternalDocument = false;

  String? _lastProcessedUri;

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _checkingInitialDocument = false;
      return;
    }

    _channel.setMethodCallHandler(_handleNativeCall);

    _checkForInitialDocument();
  }

  // ==========================================================================
  // INITIAL EXTERNAL DOCUMENT
  // ==========================================================================

  Future<void> _checkForInitialDocument() async {
    try {
      debugPrint(
        'DocVault: checking initial external document...',
      );

      final result =
          await _channel.invokeMethod('getInitialDocument');

      if (result != null) {
        final data = Map<Object?, Object?>.from(
          result as Map,
        );

        final uri = data['uri']?.toString();

        if (uri != null && uri.isNotEmpty) {
          debugPrint(
            'DocVault: external document found: $uri',
          );

          if (!mounted) return;

          setState(() {
            _initialExternalUri = uri;
            _checkingInitialDocument = false;
          });

          return;
        }
      }

      debugPrint(
        'DocVault: no external document found.',
      );
    } catch (e) {
      debugPrint(
        'DocVault: initial document error: $e',
      );
    }

    if (!mounted) return;

    setState(() {
      _checkingInitialDocument = false;
    });
  }

  // ==========================================================================
  // HANDLE NEW DOCUMENT WHILE APP IS RUNNING
  // ==========================================================================

  Future<void> _handleNativeCall(
    MethodCall call,
  ) async {
    if (kIsWeb) return;

    if (call.method != 'newDocument' &&
        call.method != 'newPdf') {
      return;
    }

    try {
      if (call.arguments == null) {
        debugPrint(
          'DocVault: native document arguments are null.',
        );
        return;
      }

      final arguments = Map<Object?, Object?>.from(
        call.arguments as Map,
      );

      final uri = arguments['uri']?.toString();

      if (uri == null || uri.isEmpty) {
        debugPrint(
          'DocVault: received empty document URI.',
        );
        return;
      }

      debugPrint(
        'DocVault: new external document received: $uri',
      );

      await _openIncomingDocument(uri);
    } catch (e) {
      debugPrint(
        'DocVault: new document handling error: $e',
      );
    }
  }

  // ==========================================================================
  // OPEN INCOMING DOCUMENT
  // ==========================================================================

  Future<void> _openIncomingDocument(
    String uri,
  ) async {
    if (kIsWeb) return;

    if (_isOpeningExternalDocument) {
      debugPrint(
        'DocVault: document is already opening.',
      );
      return;
    }

    if (_lastProcessedUri == uri) {
      debugPrint(
        'DocVault: document already processed.',
      );
      return;
    }

    _isOpeningExternalDocument = true;

    try {
      debugPrint(
        'DocVault: importing external document...',
      );

      final result =
          await ExternalPdfService.importDocumentFromUri(
        uri,
      );

      if (!mounted) return;

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
        'DocVault: imported path = $savedPath',
      );

      debugPrint(
        'DocVault: imported name = $fileName',
      );

      _lastProcessedUri = uri;

      final navigator =
          MyApp.navigatorKey.currentState;

      if (navigator == null) {
        throw Exception(
          'Navigator is not ready.',
        );
      }

      // ======================================================================
      // OPEN DOCUMENT VIEWER
      //
      // pushReplacement is intentional:
      // Home/Splash will not remain underneath the external document.
      // ======================================================================

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
        'DocVault: external document viewer opened.',
      );
    } catch (e) {
      debugPrint(
        'DocVault: external document import failed: $e',
      );

      MyApp.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open document: $e',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.errorColor,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      _isOpeningExternalDocument = false;
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

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

            scaffoldMessengerKey:
              MyApp.scaffoldMessengerKey,

            title: 'DocVault',

            debugShowCheckedModeBanner: false,

            // =================================================================
            // THEMES
            // =================================================================

            theme: AppTheme.lightTheme(),

            darkTheme: AppTheme.darkTheme(),

            themeMode:
                themeProvider.themeMode,

            // =================================================================
            // STARTUP
            // =================================================================

            home: _buildStartupScreen(),

            // =================================================================
            // STATIC ROUTES
            // =================================================================

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

            // =================================================================
            // DYNAMIC ROUTES
            // =================================================================

            onGenerateRoute: _generateRoute,
          );
        },
      ),
    );
  }

  // ==========================================================================
  // STARTUP SCREEN
  // ==========================================================================

  Widget _buildStartupScreen() {
    if (_checkingInitialDocument) {
      return const _ExternalDocumentCheckingScreen();
    }

    if (_initialExternalUri != null) {
      return _InitialExternalDocumentScreen(
        uri: _initialExternalUri!,
        onOpen: _openIncomingDocument,
      );
    }

    return const SplashScreen();
  }

  // ==========================================================================
  // ROUTES
  // ==========================================================================

  Route<dynamic>? _generateRoute(
    RouteSettings settings,
  ) {
    // ========================================================================
    // HOME
    // ========================================================================

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
        builder: (_) => MainNavigationScreen(
          initialIndex: initialIndex,
        ),
      );
    }

    // ========================================================================
    // ALL FILES
    // ========================================================================

    if (settings.name == '/all-files') {
      return MaterialPageRoute(
        builder: (_) => const MainNavigationScreen(
          initialIndex: 1,
        ),
      );
    }

    // ========================================================================
    // RESULT
    // ========================================================================

    if (settings.name == '/result') {
      if (settings.arguments is! PdfResult) {
        return MaterialPageRoute(
          builder: (_) => const _RouteErrorScreen(
            message:
                'Invalid document result.',
          ),
        );
      }

      final pdfResult =
          settings.arguments as PdfResult;

      return MaterialPageRoute(
        builder: (_) => ResultScreen(
          pdfResult: pdfResult,
        ),
      );
    }

    return MaterialPageRoute(
      builder: (_) => const _RouteErrorScreen(
        message: 'Page not found.',
      ),
    );
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    if (!kIsWeb) {
      _channel.setMethodCallHandler(null);
    }

    super.dispose();
  }
}

// ============================================================================
// EXTERNAL DOCUMENT CHECKING SCREEN
// ============================================================================

class _ExternalDocumentCheckingScreen
    extends StatelessWidget {
  const _ExternalDocumentCheckingScreen();

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.bgDark
          : AppTheme.bgWhite,

      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,

              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius:
                    BorderRadius.circular(22),
              ),

              child: const Icon(
                Icons.description_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),

            const SizedBox(height: 20),

            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INITIAL EXTERNAL DOCUMENT SCREEN
// ============================================================================

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

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _startOpening();
      },
    );
  }

  Future<void> _startOpening() async {
    if (_started) return;

    _started = true;

    await widget.onOpen(
      widget.uri,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.bgDark
          : AppTheme.bgWhite,

      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,

              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius:
                    BorderRadius.circular(22),
              ),

              child: const Icon(
                Icons.description_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Opening document...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface,
              ),
            ),

            const SizedBox(height: 14),

            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ROUTE ERROR
// ============================================================================

class _RouteErrorScreen
    extends StatelessWidget {
  const _RouteErrorScreen({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DocVault'),
      ),

      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: AppTheme.errorColor,
              ),

              const SizedBox(height: 16),

              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil(
                    '/home',
                    (route) => false,
                  );
                },

                icon: const Icon(
                  Icons.home_rounded,
                ),

                label: const Text(
                  'Go Home',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}