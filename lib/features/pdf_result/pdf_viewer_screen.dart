import 'dart:io';

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
import '../../models/pdf_document.dart' as model;
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
  final PageController _pageController = PageController();

  List<String> _extractedPagePaths = [];
  List<String> _extractedTextPages = [];
  int _actualPageCount = 0;
  int _currentPage = 1;

  bool _isLoading = true;
  bool _isSavingToDocVault = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _docType = ConversionType.fromFileName(widget.fileName);

    final file = File(widget.filePath);

    if (!file.existsSync()) {
      _errorMessage = 'Document file not found on device.';
      _isLoading = false;
      return;
    }

    _initializeViewer();
  }

  // ============================================================
  // INITIALIZE VIEWER
  // ============================================================

  Future<void> _initializeViewer() async {
    if (_docType == ConversionType.pdf) {
      try {
        _pdfController = PdfControllerPinch(
          document: PdfDocument.openFile(widget.filePath),
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load PDF: $e';
            _isLoading = false;
          });
        }
      }
    } else {
      // For DOCX and PPTX, extract page/slide images
      try {
        final pages = await FileUtils.extractPagesFromDocument(widget.filePath);
        if (mounted) {
          setState(() {
            _extractedPagePaths = pages;
            _actualPageCount = pages.length;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          try {
            final textPages =
                await FileUtils.extractTextPagesFromDocument(widget.filePath);
            if (mounted) {
              setState(() {
                _extractedTextPages = textPages;
                _actualPageCount = textPages.length;
                _isLoading = false;
              });
            }
          } catch (textError) {
            if (mounted) {
              setState(() {
                _errorMessage =
                    'Failed to preview ${_docType.shortName}: $textError';
                _isLoading = false;
              });
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _shareDocument() async {
    try {
      await Share.shareXFiles(
        [
          XFile(widget.filePath),
        ],
        text: 'Sharing ${widget.fileName} from DocVault',
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Failed to share document',
        isError: true,
      );
    }
  }

  // ============================================================
  // EXPORT
  // ============================================================

  Future<void> _exportDocument() async {
    try {
      final provider = context.read<PdfManagerProvider>();

      final doc = provider.documents.firstWhere(
        (d) =>
            d.filePath == widget.filePath ||
            d.fileName == widget.fileName,
        orElse: () => model.PdfDocument(
          id: '',
          fileName: widget.fileName,
          filePath: widget.filePath,
          fileSizeBytes: 0,
          pageCount:
              _actualPageCount > 0 ? _actualPageCount : 1,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      );

      final exportedPath = await provider.exportPdf(doc.id);

      if (!mounted) return;

      if (exportedPath != null) {
        _showSnackBar(
          'Saved to $exportedPath',
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
  // EDIT DOCUMENT
  // ============================================================

  Future<void> _editDocument() async {
    final provider = context.read<PdfManagerProvider>();

    final doc = provider.documents.firstWhere(
      (d) =>
          d.filePath == widget.filePath ||
          d.fileName == widget.fileName,
      orElse: () => model.PdfDocument(
        id: '',
        fileName: widget.fileName,
        filePath: widget.filePath,
        fileSizeBytes: 0,
        pageCount:
            _actualPageCount > 0 ? _actualPageCount : 1,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      ),
    );

    if (doc.id.isEmpty) {
      _showSnackBar(
        'Please save document to DocVault before editing.',
        isError: true,
      );
      return;
    }

    // Show loading dialog.
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
                    CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading document for editing...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
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

      final imageSelectionProvider =
          context.read<ImageSelectionProvider>();

      imageSelectionProvider.clearAllImages();

      imageSelectionProvider.addImages(
        imagePaths,
        'existing_doc',
        markUnsaved: false,
      );

      final result =
          await Navigator.of(context).push<bool>(
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
  // OPEN WITH EXTERNAL APP
  // ============================================================

  Future<void> _openWithExternalApp() async {
    try {
      final result = await OpenFile.open(
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

  Future<void> _saveToDocVaultLibrary() async {
    if (_isSavingToDocVault) return;

    setState(() {
      _isSavingToDocVault = true;
    });

    try {
      final sourceFile = File(widget.filePath);

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

      // Avoid copying a file onto itself.
      if (sourceFile.path != destinationFile.path) {
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
        pageCount:
            _actualPageCount > 0
                ? _actualPageCount
                : 1,
      );

      if (!mounted) return;

      _showSnackBar(
        'Saved "${widget.fileName}" to DocVault',
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Failed to save to DocVault: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingToDocVault = false;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? AppTheme.errorColor
            : AppTheme.successColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark =
        theme.brightness == Brightness.dark;

    final itemUnit =
        _docType == ConversionType.ppt
            ? 'Slide'
            : 'Page';

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.bgDark
          : const Color(0xFFE8ECEB),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          tooltip: 'Back',
        ),

        backgroundColor: isDark
            ? AppTheme.surfaceDark
            : AppTheme.surfaceLight,

        foregroundColor:
            colorScheme.onSurface,

        elevation: 0,

        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            if (_actualPageCount > 0)
              Text(
                '$itemUnit $_currentPage of $_actualPageCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
          ],
        ),

        actions: [
          // Edit only for internal documents.
          if (!widget.isExternal)
            IconButton(
              icon: const Icon(
                Icons.tune_rounded,
              ),
              onPressed: _editDocument,
              tooltip: 'Edit Document',
            ),

          // Save external document to DocVault.
          if (widget.isExternal)
            IconButton(
              icon: _isSavingToDocVault
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                            AppTheme.primaryColor,
                      ),
                    )
                  : const Icon(
                      Icons.bookmark_add_outlined,
                    ),
              onPressed:
                  _isSavingToDocVault
                      ? null
                      : _saveToDocVaultLibrary,
              tooltip:
                  'Save to DocVault',
            ),

          // Open with system application.
          IconButton(
            icon: const Icon(
              Icons.open_in_new_rounded,
            ),
            onPressed:
                _openWithExternalApp,
            tooltip:
                'Open in External App',
          ),

          // Share.
          IconButton(
            icon: const Icon(
              Icons.share_outlined,
            ),
            onPressed: _shareDocument,
            tooltip:
                'Share Document',
          ),

          // Export / save.
          IconButton(
            icon: const Icon(
              Icons.download_rounded,
            ),
            onPressed:
                _exportDocument,
            tooltip:
                'Save to Device',
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: _buildBody(
        colorScheme,
        isDark,
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody(
    ColorScheme colorScheme,
    bool isDark,
  ) {
    // Error state.
    if (_errorMessage != null) {
      return _buildErrorState(
        colorScheme,
      );
    }

    // PDF.
    if (_docType == ConversionType.pdf) {
      return _buildPdfViewer();
    }

    // DOCX / PPTX.
    return _buildNonPdfViewer(
      isDark,
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: AppTheme.errorColor,
            ),

            const SizedBox(height: 16),

            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color:
                    colorScheme.onSurface,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed:
                  _openWithExternalApp,
              icon: const Icon(
                Icons.open_in_new_rounded,
              ),
              label: const Text(
                'Open in System App',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PDF VIEWER
  // ============================================================

  Widget _buildPdfViewer() {
    if (_pdfController == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
        ),
      );
    }

    return Stack(
      children: [
        PdfViewPinch(
          controller: _pdfController!,

          onDocumentLoaded: (document) {
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
          const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          ),
      ],
    );
  }

  // ============================================================
  // DOCX / PPTX VIEWER
  // ============================================================

  Widget _buildNonPdfViewer(
    bool isDark,
  ) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
        ),
      );
    }

    if (_extractedTextPages.isNotEmpty) {
      return _buildTextViewer(isDark);
    }

    final isPpt = _docType == ConversionType.ppt;
    final aspectRatio = isPpt ? (16 / 9) : (1 / 1.414);

    return Column(
      children: [
        // ======================================================
        // MAIN PAGE VIEW
        // ======================================================

        Expanded(
          child: PageView.builder(
            controller:
                _pageController,
            itemCount:
                _extractedPagePaths.length,

            onPageChanged: (index) {
              if (!mounted) return;

              setState(() {
                _currentPage =
                    index + 1;
              });
            },

            itemBuilder:
                (context, index) {
              final path =
                  _extractedPagePaths[
                      index];

              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),

                  child: AspectRatio(
                    aspectRatio:
                        pageAspectRatio,

                    child: Container(
                      width:
                          double.infinity,

                      decoration:
                          BoxDecoration(
                        color:
                            Colors.white,

                        borderRadius:
                            BorderRadius.circular(
                          isPpt ? 12 : 8,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(
                              alpha: 0.15,
                            ),
                            blurRadius: 16,
                            offset:
                                const Offset(
                              0,
                              4,
                            ),
                          ),
                        ],
                      ),

                      clipBehavior:
                          Clip.antiAlias,

                      child: Stack(
                        fit:
                            StackFit.expand,

                        children: [
                          // ------------------------------------
                          // DOCUMENT PAGE
                          // ------------------------------------

                          Image.file(
                            File(path),
                            fit:
                                BoxFit.contain,
                            errorBuilder:
                                (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return const Center(
                                child: Icon(
                                  Icons
                                      .broken_image_outlined,
                                  size: 48,
                                  color: Colors
                                      .grey,
                                ),
                              );
                            },
                          ),

                          // ------------------------------------
                          // PAGE NUMBER
                          // ------------------------------------

                          Positioned(
                            bottom: 8,
                            right: 8,
                            child:
                                Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),

                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.black54,
                                borderRadius:
                                    BorderRadius.circular(
                                  6,
                                ),
                              ),

                              child: Text(
                                '${index + 1}',
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize:
                                      11,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ======================================================
        // THUMBNAILS
        // ======================================================

        if (_extractedPagePaths.length > 1)
          Container(
            height: 68,
            padding:
                const EdgeInsets.symmetric(
              vertical: 8,
            ),

            color: isDark
                ? AppTheme.surfaceDark
                : AppTheme.surfaceLight,

            child:
                ListView.separated(
              scrollDirection:
                  Axis.horizontal,

              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
              ),

              itemCount:
                  _extractedPagePaths
                      .length,

              separatorBuilder:
                  (context, index) =>
                      const SizedBox(
                    width: 8,
                  ),

              itemBuilder:
                  (context, index) {
                final isSelected =
                    index ==
                        _currentPage - 1;

                return GestureDetector(
                  onTap: () {
                    _pageController
                        .animateToPage(
                      index,
                      duration:
                          const Duration(
                        milliseconds: 300,
                      ),
                      curve:
                          Curves.easeInOut,
                    );
                  },

                  child: AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 200,
                    ),

                    width:
                        isPpt ? 72 : 52,

                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(
                        6,
                      ),

                      border:
                          Border.all(
                        color: isSelected
                            ? _docType
                                .badgeColor
                            : Colors
                                .transparent,
                        width: 2,
                      ),
                    ),

                    clipBehavior:
                        Clip.antiAlias,

                    child: Image.file(
                      File(
                        _extractedPagePaths[
                            index],
                      ),
                      fit:
                          BoxFit.cover,
                      errorBuilder:
                          (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return const Icon(
                          Icons
                              .broken_image_outlined,
                          color:
                              Colors.grey,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTextViewer(bool isDark) {
    final isPpt = _docType == ConversionType.ppt;
    final aspectRatio = isPpt ? (16 / 9) : (1 / 1.414);

    return PageView.builder(
      controller: _pageController,
      itemCount: _extractedTextPages.length,
      onPageChanged: (idx) => setState(() => _currentPage = idx + 1),
      itemBuilder: (context, index) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isPpt ? 12 : 8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _extractedTextPages[index],
                    style: TextStyle(
                      color: isDark ? Colors.black87 : Colors.black87,
                      fontSize: isPpt ? 20 : 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

typedef DocumentViewerScreen = PdfViewerScreen;