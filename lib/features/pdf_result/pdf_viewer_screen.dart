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
  late final PageController _pageController;

  List<String> _documentPages = [];

  int _actualPageCount = 0;
  int _currentPage = 1;

  bool _isLoading = true;
  bool _isSavingToDocVault = false;

  String? _errorMessage;

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

      final pages =
          await FileUtils.extractPagesFromDocument(
        widget.filePath,
      );

      if (!mounted) return;

      if (pages.isEmpty) {
        throw Exception(
          'No pages/slides could be loaded from this document.',
        );
      }

      setState(() {
        _documentPages = pages;
        _actualPageCount = pages.length;
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Failed to open ${widget.fileName}:\n$e';
        _isLoading = false;
      });
    }
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
            'Sharing ${widget.fileName} from DocVault',
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
        'Please save document to DocVault before editing.',
        isError: true,
      );
      return;
    }

    final doc =
        matchingDocuments.first;

    if (doc.id.isEmpty) {
      _showSnackBar(
        'Please save document to DocVault before editing.',
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

  Future<void> _saveToDocVaultLibrary() async {
    if (_isSavingToDocVault) {
      return;
    }

    setState(() {
      _isSavingToDocVault = true;
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
        '"${widget.fileName}" saved to DocVault',
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

              Expanded(
                child: _buildBody(isDark),
              ),

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
  // BODY
  // ============================================================

  Widget _buildBody(bool isDark) {
    if (_errorMessage != null) {
      return _buildErrorState(isDark);
    }

    if (_isPdf) {
      return _buildPdfViewer(isDark);
    }

    return _buildOfficeViewer(isDark);
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
  // PDF VIEWER
  // ============================================================

  Widget _buildPdfViewer(bool isDark) {
    if (_pdfController == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        8,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF101526)
            : const Color(0xFFE9EDF4),
        borderRadius:
            BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
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
                  ? const Color(0xFF0A0D19)
                  : const Color(
                      0xFFF5F7FB,
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
  // OFFICE VIEWER
  // ============================================================

  Widget _buildOfficeViewer(bool isDark) {
    if (_isLoading) {
      return _buildLoadingState(isDark);
    }

    if (_documentPages.isEmpty) {
      return const Center(
        child: Text(
          'No pages/slides available.',
        ),
      );
    }

    final aspectRatio =
        _isPpt ? 16 / 9 : 1 / 1.414;

    final scrollDirection =
        _isPpt
            ? Axis.horizontal
            : Axis.vertical;

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            scrollDirection:
                scrollDirection,
            physics:
                const PageScrollPhysics(),
            itemCount:
                _documentPages.length,

            onPageChanged: (index) {
              if (!mounted) return;

              setState(() {
                _currentPage = index + 1;
              });
            },

            itemBuilder:
                (context, index) {
              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    14,
                    14,
                    14,
                    8,
                  ),
                  child: AspectRatio(
                    aspectRatio:
                        aspectRatio,
                    child:
                        _buildDocumentCard(
                      _documentPages[index],
                      index,
                      isDark,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        if (_documentPages.length > 1)
          _buildThumbnails(isDark),
      ],
    );
  }

  // ============================================================
  // DOCUMENT CARD
  // ============================================================
Widget _buildDocumentCard(
  String path,
  int index,
  bool isDark,
) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(
        _isPpt ? 16 : 12,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: isDark ? 0.30 : 0.12,
          ),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(path),
          fit: BoxFit.contain,

          // Important: avoid decoding huge original images.
          cacheWidth: screenWidth.toInt() * 2,
          cacheHeight: screenHeight.toInt() * 2,

          filterQuality: FilterQuality.medium,

          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: Colors.grey,
              ),
            );
          },
        ),

        Positioned(
          right: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(
                alpha: 0.65,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
  // ============================================================
  // THUMBNAILS
  // ============================================================

  Widget _buildThumbnails(bool isDark) {
    return Container(
      height: 92,
      margin:
          const EdgeInsets.fromLTRB(
        12,
        0,
        12,
        8,
      ),
      padding:
          const EdgeInsets.symmetric(
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF101526)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(18),
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
      child: ListView.separated(
        scrollDirection:
            Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
        ),
        itemCount:
            _documentPages.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: 8),

        itemBuilder:
            (context, index) {
          final selected =
              index == _currentPage - 1;

          return GestureDetector(
            onTap: () {
              _pageController
                  .animateToPage(
                index,
                duration:
                    const Duration(
                  milliseconds: 280,
                ),
                curve:
                    Curves.easeOutCubic,
              );
            },

            child: AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 180,
              ),
              width:
                  _isPpt ? 92 : 58,
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(9),
                border: Border.all(
                  color: selected
                      ? _accentColor
                      : Colors.transparent,
                  width: 2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _accentColor
                              .withValues(
                            alpha: 0.20,
                          ),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              clipBehavior:
                  Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
  File(
    _documentPages[index],
  ),
  fit: BoxFit.cover,
  cacheWidth: _isPpt ? 184 : 116,
  cacheHeight: 160,
  filterQuality: FilterQuality.low,
  errorBuilder: (
    context,
    error,
    stackTrace,
  ) {
    return const Icon(
      Icons.broken_image_outlined,
      color: Colors.grey,
    );
  },
),
                  Positioned(
                    left: 4,
                    top: 4,
                    child: Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.black54,
                        borderRadius:
                            BorderRadius.circular(
                          4,
                        ),
                      ),
                      child: Text(
                        '${index + 1}',
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
                        'Save to DocVault',
                    subtitle:
                        'Keep this document in your library',
                    onTap:
                        _isSavingToDocVault
                            ? null
                            : () {
                                Navigator.pop(
                                  sheetContext,
                                );
                                _saveToDocVaultLibrary();
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

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _pdfController?.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

// ================================================================
// BACKWARD COMPATIBILITY
// ================================================================

typedef DocumentViewerScreen =
    PdfViewerScreen;
 
