import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/image_selection_provider.dart';
import '../../core/providers/pdf_manager_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_utils.dart';
import '../../models/conversion_type.dart';
import '../pdf_generation/review_screen.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final bool isExternal;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.isExternal = false,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final ConversionType _docType;

  PdfControllerPinch? _pdfController;
  WebViewController? _webViewController;
  late final PageController _pageController;

  int _actualPageCount = 0;
  int _currentPage = 1;

  bool _isLoading = true;
  bool _isSavingToDocScanner = false;

  final List<String> _fallbackImagePaths = [];
  bool _usingFallbackView = false;
  Timer? _renderTimeoutTimer;

  String? _errorMessage;

  // View management state
  double _zoomScale = 1.0;
  int _rotationQuarterTurns = 0;
  bool _isFitWidth = true;
  String _docxViewMode = 'page'; // 'page' or 'reflow'
  String _pptxSlideMode = 'slide'; // 'slide' or 'list'
  final bool _showControlsBar = true;

  bool get _isPdf => _docType == ConversionType.pdf;

  bool get _isPpt => _docType == ConversionType.ppt;

  String get _itemUnit => _isPpt ? 'Slide' : 'Page';

  Color get _accentColor => _docType.badgeColor;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _docType = ConversionType.fromFileName(
      widget.fileName,
    );

    _pageController = PageController();

    final file = File(widget.filePath);

    if (!file.existsSync()) {
      _errorMessage =
          'Document file not found on device.';
      _isLoading = false;
      return;
    }

    _initializeViewer();
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initializeViewer() async {
    try {
      if (_isPdf) {
        _pdfController = PdfControllerPinch(
          document: PdfDocument.openFile(
            widget.filePath,
          ),
        );

        if (mounted) {
          setState(() {
            _isLoading = true;
          });
        }

        return;
      }

      // DOCX / PPTX -> WebView-based rendering with native extraction fallback
      _renderTimeoutTimer?.cancel();
      _renderTimeoutTimer = Timer(const Duration(seconds: 25), () {
        if (mounted && _isLoading && !_usingFallbackView) {
          debugPrint(
            'WebView render timed out for ${widget.fileName}. Falling back to native page extraction...',
          );
          _tryFallbackNativeRendering(
            error: 'WebView preview took longer than usual. Switched to slide/page view.',
          );
        }
      });

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          'DocumentBridge',
          onMessageReceived: _handleBridgeMessage,
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) => _renderOfficeDocument(),
            onWebResourceError: (error) {
              debugPrint('WebView web resource error: ${error.description}');
            },
          ),
        )
        ..loadFlutterAsset('assets/webview/index.html');

      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    } catch (e) {
      debugPrint('WebView initialization error: $e. Attempting fallback...');
      await _tryFallbackNativeRendering(error: e.toString());
    }
  }

  // ============================================================
  // RENDER DOCX/PPTX INSIDE WEBVIEW
  // ============================================================

  Future<void> _renderOfficeDocument() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: ${widget.filePath}');
      }

      if (!mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      await _webViewController?.runJavaScript(
        "setTheme('${isDark ? 'dark' : 'light'}');",
      );

      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);

      if (base64Data.length > 400000) {
        // Transfer in safe 350KB chunks to prevent Android evaluateJavascript IPC buffer limit
        const chunkSize = 350000;
        for (int i = 0; i < base64Data.length; i += chunkSize) {
          final end = (i + chunkSize < base64Data.length) ? i + chunkSize : base64Data.length;
          final chunk = base64Data.substring(i, end);
          final isFirst = i == 0;
          final isLast = end == base64Data.length;
          await _webViewController!.runJavaScript(
            "receiveDocChunk('$chunk', $isFirst, $isLast, $_isPpt);",
          );
        }
      } else {
        final jsFunction = _isPpt ? 'renderPptx' : 'renderDocx';
        await _webViewController!.runJavaScript(
          "$jsFunction('$base64Data');",
        );
      }
    } catch (e) {
      debugPrint('WebView script error: $e. Attempting native fallback...');
      await _tryFallbackNativeRendering(error: e.toString());
    }
  }

  // ============================================================
  // WEBVIEW <-> FLUTTER BRIDGE
  // ============================================================

  void _handleBridgeMessage(JavaScriptMessage message) {
    if (!mounted) return;

    final data = message.message;

    if (data == 'success') {
      _renderTimeoutTimer?.cancel();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } else if (data.startsWith('error:')) {
      _renderTimeoutTimer?.cancel();
      debugPrint('DocumentBridge error: ${data.substring(6)}. Trying native extraction...');
      _tryFallbackNativeRendering(error: data.substring(6));
    } else if (data.startsWith('pagecount:')) {
      final count = int.tryParse(data.substring(10)) ?? 0;
      if (count > 0) {
        setState(() {
          _actualPageCount = count;
        });
      }
    } else if (data.startsWith('slidechanged:')) {
      final parts = data.substring(13).split(':');
      if (parts.length >= 2) {
        final curr = int.tryParse(parts[0]) ?? 1;
        final total = int.tryParse(parts[1]) ?? _actualPageCount;
        setState(() {
          _currentPage = curr;
          if (total > 0) _actualPageCount = total;
        });
      }
    }
  }

  // ============================================================
  // FALLBACK NATIVE IMAGE RENDERING FOR DOCX / PPTX
  // ============================================================

  Future<void> _tryFallbackNativeRendering({String? error}) async {
    _renderTimeoutTimer?.cancel();
    try {
      final pages = await FileUtils.extractPagesFromDocument(widget.filePath);
      if (pages.isNotEmpty && mounted) {
        setState(() {
          _fallbackImagePaths.clear();
          _fallbackImagePaths.addAll(pages);
          _actualPageCount = pages.length;
          _currentPage = 1;
          _usingFallbackView = true;
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }
    } catch (e) {
      debugPrint('Fallback native page extraction failed: $e');
    }

    if (!mounted) return;

    setState(() {
      _errorMessage =
          'Failed to render ${widget.fileName}:\n${error ?? 'Unsupported document format'}';
      _isLoading = false;
    });
  }

  // ============================================================
  // VIEW & PAGE MANAGEMENT CONTROLS
  // ============================================================

  void _zoomIn() {
    setState(() {
      _zoomScale = (_zoomScale + 0.2).clamp(0.6, 3.0);
    });
    _webViewController?.runJavaScript("setZoom($_zoomScale);");
  }

  void _zoomOut() {
    setState(() {
      _zoomScale = (_zoomScale - 0.2).clamp(0.6, 3.0);
    });
    _webViewController?.runJavaScript("setZoom($_zoomScale);");
  }

  void _resetZoom() {
    setState(() {
      _zoomScale = 1.0;
    });
    _webViewController?.runJavaScript("setZoom(1.0);");
  }

  void _rotateDocument() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _toggleDocxViewMode() {
    setState(() {
      _docxViewMode = _docxViewMode == 'page' ? 'reflow' : 'page';
    });
    _webViewController?.runJavaScript("setViewMode('$_docxViewMode');");
  }

  void _togglePptxSlideMode() {
    setState(() {
      _pptxSlideMode = _pptxSlideMode == 'slide' ? 'list' : 'slide';
    });
    _webViewController?.runJavaScript("setSlideMode('$_pptxSlideMode');");
  }

  void _nextPageOrSlide() {
    if (_isPdf && _pdfController != null) {
      _pdfController!.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else if (_isPpt && !_usingFallbackView) {
      _webViewController?.runJavaScript("nextSlide();");
    } else if (_usingFallbackView && _pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPageOrSlide() {
    if (_isPdf && _pdfController != null) {
      _pdfController!.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else if (_isPpt && !_usingFallbackView) {
      _webViewController?.runJavaScript("prevSlide();");
    } else if (_usingFallbackView && _pageController.hasClients) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPage(int targetPage) {
    if (targetPage < 1 || targetPage > _actualPageCount) return;
    setState(() => _currentPage = targetPage);

    if (_isPdf && _pdfController != null) {
      _pdfController!.animateToPage(
        pageNumber: targetPage,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else if (_isPpt && !_usingFallbackView) {
      _webViewController?.runJavaScript("goToSlide(${targetPage - 1});");
    } else if (_usingFallbackView && _pageController.hasClients) {
      _pageController.jumpToPage(targetPage - 1);
    }
  }

  void _showJumpToPageDialog() {
    if (_actualPageCount <= 1) return;
    int target = _currentPage;
    final textController = TextEditingController(text: '$_currentPage');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_isPpt ? Icons.slideshow_rounded : Icons.menu_book_rounded, color: _accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Jump to $_itemUnit',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Choose a $_itemUnit between 1 and $_actualPageCount:',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: target > 1
                            ? () {
                                setDialogState(() {
                                  target--;
                                  textController.text = '$target';
                                });
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        color: _accentColor,
                      ),
                      Container(
                        width: 76,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextField(
                          controller: textController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed >= 1 && parsed <= _actualPageCount) {
                              setDialogState(() => target = parsed);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: target < _actualPageCount
                            ? () {
                                setDialogState(() {
                                  target++;
                                  textController.text = '$target';
                                });
                              }
                            : null,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        color: _accentColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _accentColor,
                      thumbColor: _accentColor,
                      overlayColor: _accentColor.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: target.toDouble().clamp(1.0, _actualPageCount.toDouble()),
                      min: 1.0,
                      max: _actualPageCount.toDouble(),
                      divisions: _actualPageCount > 1 ? _actualPageCount - 1 : 1,
                      label: '$target',
                      onChanged: (val) {
                        setDialogState(() {
                          target = val.round();
                          textController.text = '$target';
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _goToPage(target);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Go', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BACK / CLOSE VIEWER
  // ============================================================

  Future<void> _closeViewer() async {
    if (!mounted) return;

    final navigator = Navigator.of(context);

    // External document was opened using pushReplacement.
    // So safely return to home instead of popping into
    // an empty route stack.
    if (widget.isExternal) {
      navigator.pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );
      return;
    }

    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _shareDocument() async {
    try {
      final file = File(widget.filePath);

      if (!await file.exists()) {
        throw Exception('Document file not found.');
      }

      await Share.shareXFiles(
        [
          XFile(widget.filePath),
        ],
        text:
            'Sharing ${widget.fileName} from DocScanner',
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Failed to share document: $e',
        isError: true,
      );
    }
  }

  // ============================================================
  // EXPORT / SAVE TO DEVICE
  // ============================================================

  Future<void> _exportDocument() async {
    try {
      final sourceFile = File(widget.filePath);

      if (!await sourceFile.exists()) {
        throw Exception(
          'Document file not found.',
        );
      }

      // ==========================================================
      // EXTERNAL DOCUMENT
      //
      // External files may not exist in PdfManagerProvider yet.
      // Use system sharing/save flow instead of provider export.
      // ==========================================================

      if (widget.isExternal) {
        await Share.shareXFiles(
          [
            XFile(widget.filePath),
          ],
          text: 'Save ${widget.fileName}',
        );

        return;
      }

      // ==========================================================
      // INTERNAL DOCVAULT DOCUMENT
      // ==========================================================

      if (!mounted) return;

      final provider =
          context.read<PdfManagerProvider>();

      final matchingDocuments =
          provider.documents.where(
        (d) =>
            d.filePath == widget.filePath ||
            d.fileName == widget.fileName,
      );

      if (matchingDocuments.isEmpty) {
        // Fallback for files not registered in provider.
        await Share.shareXFiles(
          [
            XFile(widget.filePath),
          ],
          text: 'Save ${widget.fileName}',
        );

        return;
      }

      final doc =
          matchingDocuments.first;

      if (doc.id.isEmpty) {
        await Share.shareXFiles(
          [
            XFile(widget.filePath),
          ],
          text: 'Save ${widget.fileName}',
        );

        return;
      }

      final exportedPath =
          await provider.exportPdf(doc.id);

      if (!mounted) return;

      if (exportedPath != null &&
          exportedPath.isNotEmpty) {
        _showSnackBar(
          'Saved successfully',
        );
      } else {
        _showSnackBar(
          'Unable to export document',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Export failed: $e',
        isError: true,
      );
    }
  }

  // ============================================================
  // EDIT
  // ============================================================

  Future<void> _editDocument() async {
    final provider =
        context.read<PdfManagerProvider>();

    final matchingDocuments =
        provider.documents.where(
      (d) =>
          d.filePath == widget.filePath ||
          d.fileName == widget.fileName,
    );

    if (matchingDocuments.isEmpty) {
      _showSnackBar(
        'Please save document to DocScanner before editing.',
        isError: true,
      );
      return;
    }

    final doc =
        matchingDocuments.first;

    if (doc.id.isEmpty) {
      _showSnackBar(
        'Please save document to DocScanner before editing.',
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading document for editing...',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      final imagePaths =
          await FileUtils.extractPagesFromDocument(
        doc.filePath,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      final imageProvider =
          context.read<ImageSelectionProvider>();

      imageProvider.clearAllImages();

      imageProvider.addImages(
        imagePaths,
        'existing_doc',
        markUnsaved: false,
      );

      final result =
          await Navigator.of(context)
              .push<bool>(
        MaterialPageRoute(
          builder: (_) => ReviewScreen(
            existingDocument: doc,
            conversionType: _docType,
          ),
        ),
      );

      if (result == true && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      _showSnackBar(
        'Failed to load document: $e',
        isError: true,
      );
    }
  }

  // ============================================================
  // OPEN EXTERNAL APP
  // ============================================================

  Future<void> _openWithExternalApp() async {
    try {
      final file = File(widget.filePath);

      if (!await file.exists()) {
        throw Exception(
          'Document file not found.',
        );
      }

      final result =
          await OpenFile.open(
        widget.filePath,
      );

      if (!mounted) return;

      if (result.type != ResultType.done) {
        _showSnackBar(
          result.message.isNotEmpty
              ? result.message
              : 'Unable to open file.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Failed to open file: $e',
        isError: true,
      );
    }
  }

  // ============================================================
  // SAVE EXTERNAL DOCUMENT TO DOCVAULT
  // ============================================================

  Future<void> _saveToDocScannerLibrary() async {
    if (_isSavingToDocScanner) {
      return;
    }

    setState(() {
      _isSavingToDocScanner = true;
    });

    try {
      final sourceFile =
          File(widget.filePath);

      if (!await sourceFile.exists()) {
        throw Exception(
          'Source file not found.',
        );
      }

      final destinationPath =
          await FileUtils.getFullPdfPath(
        widget.fileName,
      );

      final destinationFile =
          File(destinationPath);

      await destinationFile.parent.create(
        recursive: true,
      );

      if (sourceFile.path !=
          destinationFile.path) {
        await sourceFile.copy(
          destinationPath,
        );
      }

      if (!mounted) return;

      final provider =
          context.read<PdfManagerProvider>();

      await provider.registerGeneratedPdf(
        filePath: destinationPath,
        fileName: widget.fileName,
        pageCount: _actualPageCount > 0
            ? _actualPageCount
            : 1,
      );

      if (!mounted) return;

      _showSnackBar(
        '"${widget.fileName}" saved to DocScanner',
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Failed to save to DocScanner: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingToDocScanner = false;
        });
      }
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons
                      .check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        behavior:
            SnackBarBehavior.floating,
        backgroundColor: isError
            ? AppTheme.errorColor
            : AppTheme.successColor,
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _renderTimeoutTimer?.cancel();
    _pdfController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final isDark =
        theme.brightness ==
            Brightness.dark;

    return PopScope(
      canPop: !widget.isExternal,
      onPopInvokedWithResult: (
        didPop,
        result,
      ) {
        if (didPop) return;

        _closeViewer();
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF070A16)
            : const Color(0xFFF5F7FB),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(isDark),

              if (_showControlsBar && !_isLoading && _errorMessage == null)
                _buildViewControlsBar(isDark),

              Expanded(
                child: _buildBody(isDark),
              ),

              if (!_isLoading && _errorMessage == null)
                _buildPageNavigationBar(isDark),

              _buildBottomToolbar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar(bool isDark) {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        10,
        14,
        12,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0D1122)
            : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(
                    alpha: 0.06,
                  )
                : Colors.black.withValues(
                    alpha: 0.06,
                  ),
          ),
        ),
      ),
      child: Row(
        children: [
          _buildTopIcon(
            icon:
                Icons.arrow_back_rounded,
            onTap: _closeViewer,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fileName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w800,
                    color: isDark
                        ? Colors.white
                        : const Color(
                            0xFF151823,
                          ),
                  ),
                ),

                const SizedBox(height: 3),

                Row(
                  children: [
                    _buildTypeBadge(),

                    const SizedBox(width: 7),

                    if (_actualPageCount >
                        0)
                      Text(
                        '$_itemUnit $_currentPage of $_actualPageCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w600,
                          color: isDark
                              ? Colors.white60
                              : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          if (!widget.isExternal)
            _buildTopIcon(
              icon: Icons.edit_rounded,
              onTap: _editDocument,
            ),

          const SizedBox(width: 6),

          _buildTopIcon(
            icon:
                Icons.more_horiz_rounded,
            onTap: () =>
                _showMoreOptions(isDark),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TYPE BADGE
  // ============================================================

  Widget _buildTypeBadge() {
    String label;

    if (_isPdf) {
      label = 'PDF';
    } else if (_isPpt) {
      label = 'PPT';
    } else {
      label = 'DOC';
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: _accentColor.withValues(
          alpha: 0.12,
        ),
        borderRadius:
            BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _accentColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // TOP ICON
  // ============================================================

  Widget _buildTopIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(13),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(13),
            color: Theme.of(context)
                        .brightness ==
                    Brightness.dark
                ? Colors.white.withValues(
                    alpha: 0.06,
                  )
                : Colors.black.withValues(
                    alpha: 0.035,
                  ),
          ),
          child: Icon(
            icon,
            size: 21,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // VIEW CONTROLS BAR (Fit Width, Zoom, Mode, Rotate)
  // ============================================================

  Widget _buildViewControlsBar(bool isDark) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1428) : const Color(0xFFFAFBFC),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // Fit Width / Fit Page toggle
          _buildPillButton(
            icon: _isFitWidth ? Icons.fit_screen_rounded : Icons.aspect_ratio_rounded,
            label: _isFitWidth ? 'Fit Width' : 'Full Page',
            isActive: _isFitWidth,
            isDark: isDark,
            onTap: () {
              setState(() {
                _isFitWidth = !_isFitWidth;
                _resetZoom();
              });
            },
          ),
          const SizedBox(width: 8),

          // DOCX Mode toggle (Page Mode vs Reflow Reader View)
          if (!_isPdf && !_isPpt)
            _buildPillButton(
              icon: _docxViewMode == 'page' ? Icons.pages_rounded : Icons.article_rounded,
              label: _docxViewMode == 'page' ? 'Page View' : 'Reader View',
              isActive: _docxViewMode == 'page',
              isDark: isDark,
              onTap: _toggleDocxViewMode,
            ),

          // PPTX Mode toggle (Single Slide vs All Slides List)
          if (_isPpt)
            _buildPillButton(
              icon: _pptxSlideMode == 'slide' ? Icons.slideshow_rounded : Icons.view_agenda_rounded,
              label: _pptxSlideMode == 'slide' ? 'Slide Show' : 'All Slides',
              isActive: _pptxSlideMode == 'slide',
              isDark: isDark,
              onTap: _togglePptxSlideMode,
            ),

          const Spacer(),

          // Zoom Out
          _buildSmallToolIcon(
            icon: Icons.remove_rounded,
            isDark: isDark,
            onTap: _zoomOut,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '${(_zoomScale * 100).round()}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          // Zoom In
          _buildSmallToolIcon(
            icon: Icons.add_rounded,
            isDark: isDark,
            onTap: _zoomIn,
          ),

          const SizedBox(width: 6),

          // Rotate 90
          _buildSmallToolIcon(
            icon: Icons.rotate_right_rounded,
            isDark: isDark,
            onTap: _rotateDocument,
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? _accentColor.withValues(alpha: 0.14)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? _accentColor.withValues(alpha: 0.4)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive
                    ? _accentColor
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? _accentColor
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallToolIcon({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PAGE NAVIGATION BAR
  // ============================================================

  Widget _buildPageNavigationBar(bool isDark) {
    if (_actualPageCount <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1122) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          IconButton(
            onPressed: _currentPage > 1 ? _prevPageOrSlide : null,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          // Page indicator chip - tap to jump to page!
          InkWell(
            onTap: _showJumpToPageDialog,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isPpt ? Icons.slideshow_rounded : Icons.menu_book_rounded,
                    size: 15,
                    color: _accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_itemUnit $_currentPage of $_actualPageCount',
                    style: TextStyle(
                      color: _accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _accentColor),
                ],
              ),
            ),
          ),
          // Next button
          IconButton(
            onPressed: _currentPage < _actualPageCount ? _nextPageOrSlide : null,
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody(bool isDark) {
    if (_errorMessage != null) {
      return _buildErrorState(isDark);
    }

    Widget content;
    if (_isPdf) {
      content = _buildPdfViewer(isDark);
    } else if (_usingFallbackView && _fallbackImagePaths.isNotEmpty) {
      content = _buildFallbackImageViewer(isDark);
    } else {
      content = _buildOfficeWebViewer(isDark);
    }

    if (_rotationQuarterTurns != 0) {
      return RotatedBox(
        quarterTurns: _rotationQuarterTurns,
        child: content,
      );
    }

    return content;
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF111627)
                : Colors.white,
            borderRadius:
                BorderRadius.circular(26),
            border: Border.all(
              color:
                  AppTheme.errorColor.withValues(
                alpha: 0.15,
              ),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.errorColor
                      .withValues(
                    alpha: 0.10,
                  ),
                ),
                child: const Icon(
                  Icons
                      .error_outline_rounded,
                  size: 42,
                  color:
                      AppTheme.errorColor,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Unable to open document',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w800,
                  color: isDark
                      ? Colors.white
                      : const Color(
                          0xFF171A25,
                        ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                _errorMessage!,
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark
                      ? Colors.white60
                      : Colors.black54,
                ),
              ),

              const SizedBox(height: 24),

              if (!_isPdf && _fallbackImagePaths.isEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                      _tryFallbackNativeRendering();
                    },
                    icon: const Icon(Icons.slideshow_rounded),
                    label: Text('View as $_itemUnit Images'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accentColor,
                      side: BorderSide(
                        color: _accentColor.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              SizedBox(
                width: double.infinity,
                height: 50,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _openWithExternalApp,
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                  ),
                  label: const Text(
                    'Open in System App',
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        _accentColor,
                    foregroundColor:
                        Colors.white,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              TextButton(
                onPressed: _closeViewer,
                child: const Text(
                  'Go to Home',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FALLBACK IMAGE VIEWER (DOCX / PPTX native slides)
  // ============================================================

  Widget _buildFallbackImageViewer(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF070A16) : const Color(0xFFF4F6FA),
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _fallbackImagePaths.length,
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() {
                _currentPage = index + 1;
              });
            },
            itemBuilder: (context, index) {
              final imageFile = File(_fallbackImagePaths[index]);
              return Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        'Unable to load $_itemUnit ${index + 1}',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_fallbackImagePaths.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_itemUnit $_currentPage of ${_fallbackImagePaths.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // PDF VIEWER
  // ============================================================

  Widget _buildPdfViewer(bool isDark) {
    if (_pdfController == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      color: isDark ? const Color(0xFF070A16) : const Color(0xFFF4F6FA),
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          PdfViewPinch(
            controller: _pdfController!,

            onDocumentLoaded: (
              document,
            ) {
              if (!mounted) return;

              setState(() {
                _actualPageCount =
                    document.pagesCount;
                _currentPage = 1;
                _isLoading = false;
              });
            },

            onPageChanged: (page) {
              if (!mounted) return;

              setState(() {
                _currentPage = page;
              });
            },

            onDocumentError: (error) {
              if (!mounted) return;

              setState(() {
                _errorMessage =
                    'Failed to display PDF: $error';
                _isLoading = false;
              });
            },
          ),

          if (_isLoading)
            Container(
              color: isDark
                  ? const Color(0xFF070A16)
                  : const Color(
                      0xFFF4F6FA,
                    ),
              child: Center(
                child:
                    _buildLoadingState(isDark),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // OFFICE VIEWER (WebView based — DOCX/PPTX)
  // ============================================================

  Widget _buildOfficeWebViewer(bool isDark) {
    if (_webViewController == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      color: isDark ? const Color(0xFF070A16) : const Color(0xFFF4F6FA),
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          WebViewWidget(controller: _webViewController!),

          if (_isLoading)
            Container(
              color: isDark
                  ? const Color(0xFF070A16)
                  : const Color(0xFFF4F6FA),
              child: Center(
                child: _buildLoadingState(isDark),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration:
                BoxDecoration(
              color:
                  _accentColor.withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(22),
            ),
            child: Center(
              child:
                  CircularProgressIndicator(
                color: _accentColor,
                strokeWidth: 3,
              ),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Loading document...',
            style: TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w700,
              color: isDark
                  ? Colors.white
                  : const Color(
                      0xFF171A25,
                    ),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Preparing your ${_itemUnit.toLowerCase()}',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? Colors.white54
                  : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM TOOLBAR
  // ============================================================

  Widget _buildBottomToolbar(bool isDark) {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        10,
        14,
        12,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0D1122)
            : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(
                    alpha: 0.06,
                  )
                : Colors.black.withValues(
                    alpha: 0.06,
                  ),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildBottomAction(
              icon:
                  Icons.open_in_new_rounded,
              label: 'Open',
              onTap:
                  _openWithExternalApp,
              isDark: isDark,
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: _buildBottomAction(
              icon:
                  Icons.share_outlined,
              label: 'Share',
              onTap: _shareDocument,
              isDark: isDark,
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: _buildBottomAction(
              icon:
                  Icons.download_rounded,
              label: 'Save',
              onTap: _exportDocument,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM ACTION
  // ============================================================

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(15),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(
                    alpha: 0.055,
                  )
                : const Color(
                    0xFFF5F6FA,
                  ),
            borderRadius:
                BorderRadius.circular(15),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(
                      alpha: 0.06,
                    )
                  : Colors.black.withValues(
                      alpha: 0.05,
                    ),
            ),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: isDark
                    ? Colors.white
                    : const Color(
                        0xFF252936,
                      ),
              ),

              const SizedBox(height: 2),

              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w700,
                  color: isDark
                      ? Colors.white70
                      : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MORE OPTIONS
  // ============================================================

  void _showMoreOptions(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            24,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF111627)
                : Colors.white,
            borderRadius:
                const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color: isDark
                        ? Colors.white24
                        : Colors.black12,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                _buildSheetItem(
                  icon:
                      Icons.open_in_new_rounded,
                  title:
                      'Open with another app',
                  subtitle:
                      'Use an installed document app',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );
                    _openWithExternalApp();
                  },
                ),

                if (widget.isExternal)
                  _buildSheetItem(
                    icon:
                        Icons
                            .bookmark_add_outlined,
                    title:
                        'Save to DocScanner',
                    subtitle:
                        'Keep this document in your library',
                    onTap:
                        _isSavingToDocScanner
                            ? null
                            : () {
                                Navigator.pop(
                                  sheetContext,
                                );
                                _saveToDocScannerLibrary();
                              },
                  ),

                _buildSheetItem(
                  icon:
                      Icons.share_outlined,
                  title:
                      'Share document',
                  subtitle:
                      'Send this file to another app',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );
                    _shareDocument();
                  },
                ),

                _buildSheetItem(
                  icon:
                      Icons.download_rounded,
                  title:
                      'Save to device',
                  subtitle:
                      'Export a copy of this document',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );
                    _exportDocument();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SHEET ITEM
  // ============================================================

  Widget _buildSheetItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      enabled: onTap != null,
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color:
              _accentColor.withValues(
            alpha: 0.10,
          ),
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: _accentColor,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
      ),
      onTap: onTap,
    );
  }
}

// ================================================================
// BACKWARD COMPATIBILITY
// ================================================================

typedef DocumentViewerScreen =
    PdfViewerScreen;