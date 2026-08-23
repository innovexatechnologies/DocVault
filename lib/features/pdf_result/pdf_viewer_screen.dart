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
      _errorMessage = 'Document file not found on device';
      _isLoading = false;
      return;
    }

    _initializeViewer();
  }

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
          setState(() {
            _errorMessage = 'Failed to preview ${_docType.shortName}: $e';
            _isLoading = false;
          });
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

  Future<void> _shareDocument() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Share.shareXFiles(
        [XFile(widget.filePath)],
        text: 'Sharing ${widget.fileName} from DocVault',
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to share document'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _exportDocument() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final provider = context.read<PdfManagerProvider>();
      final doc = provider.documents.firstWhere(
        (d) => d.filePath == widget.filePath || d.fileName == widget.fileName,
        orElse: () => model.PdfDocument(
          id: '',
          fileName: widget.fileName,
          filePath: widget.filePath,
          fileSizeBytes: 0,
          pageCount: _actualPageCount > 0 ? _actualPageCount : 1,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      );

      final exportedPath = await provider.exportPdf(doc.id);
      if (exportedPath != null && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Saved to $exportedPath'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.successColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _editDocument() async {
    final provider = context.read<PdfManagerProvider>();
    final doc = provider.documents.firstWhere(
      (d) => d.filePath == widget.filePath || d.fileName == widget.fileName,
      orElse: () => model.PdfDocument(
        id: '',
        fileName: widget.fileName,
        filePath: widget.filePath,
        fileSizeBytes: 0,
        pageCount: _actualPageCount > 0 ? _actualPageCount : 1,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      ),
    );

    if (doc.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save document to DocVault before editing.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Loading document for editing...',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final imagePaths = await FileUtils.extractPagesFromDocument(doc.filePath);
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      final imageSelectionProvider = context.read<ImageSelectionProvider>();
      imageSelectionProvider.clearAllImages();
      imageSelectionProvider.addImages(imagePaths, 'existing_doc', markUnsaved: false);

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ReviewScreen(
            existingDocument: doc,
            conversionType: _docType,
          ),
        ),
      );

      if (result == true && mounted) {
        Navigator.of(context).pop(); // Close viewer to reload updated document
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load document: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _openWithExternalApp() async {
    try {
      await OpenFile.open(widget.filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveToDocVaultLibrary() async {
    if (_isSavingToDocVault) return;
    setState(() => _isSavingToDocVault = true);

    final messenger = ScaffoldMessenger.of(context);
    try {
      final srcFile = File(widget.filePath);
      if (!await srcFile.exists()) {
        throw Exception('Source file not found');
      }

      final destPath = await FileUtils.getFullPdfPath(widget.fileName);
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);
      await srcFile.copy(destPath);

      if (!mounted) return;
      final provider = context.read<PdfManagerProvider>();
      await provider.registerGeneratedPdf(
        filePath: destPath,
        fileName: widget.fileName,
        pageCount: _actualPageCount > 0 ? _actualPageCount : 1,
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Saved "${widget.fileName}" to DocVault'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save to DocVault: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingToDocVault = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final itemUnit = _docType == ConversionType.ppt ? 'Slide' : 'Page';

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : const Color(0xFFE8ECEB),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
        backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              overflow: TextOverflow.ellipsis,
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
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        actions: [
          if (!widget.isExternal)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: _editDocument,
              tooltip: 'Edit Document',
            ),
          if (widget.isExternal)
            IconButton(
              icon: _isSavingToDocVault
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : const Icon(Icons.bookmark_add_outlined),
              onPressed: _saveToDocVaultLibrary,
              tooltip: 'Save to DocVault',
            ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: _openWithExternalApp,
            tooltip: 'Open in External App',
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareDocument,
            tooltip: 'Share Document',
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _exportDocument,
            tooltip: 'Save to Device',
          ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openWithExternalApp,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open in System App'),
                    ),
                  ],
                ),
              ),
            )
          : _docType == ConversionType.pdf
              ? Stack(
                  children: [
                    if (_pdfController != null)
                      PdfViewPinch(
                        controller: _pdfController!,
                        onDocumentLoaded: (document) {
                          if (mounted) {
                            setState(() {
                              _actualPageCount = document.pagesCount;
                              _isLoading = false;
                            });
                          }
                        },
                        onPageChanged: (page) {
                          if (mounted) {
                            setState(() {
                              _currentPage = page;
                            });
                          }
                        },
                        onDocumentError: (error) {
                          if (mounted) {
                            setState(() {
                              _errorMessage = 'Failed to display PDF: $error';
                              _isLoading = false;
                            });
                          }
                        },
                      ),
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                  ],
                )
              : _buildNonPdfViewer(isDark),
    );
  }

  Widget _buildNonPdfViewer(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
        ),
      );
    }

    final isPpt = _docType == ConversionType.ppt;
    final aspectRatio = isPpt ? (16 / 9) : (1 / 1.414);

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _extractedPagePaths.length,
            onPageChanged: (idx) {
              setState(() => _currentPage = idx + 1);
            },
            itemBuilder: (context, index) {
              final path = _extractedPagePaths[index];
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: Container(
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
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(path),
                            fit: BoxFit.contain,
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
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
        if (_extractedPagePaths.length > 1)
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _extractedPagePaths.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final isSelected = idx == _currentPage - 1;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      idx,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: isPpt ? 60 : 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? _docType.badgeColor
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.file(
                      File(_extractedPagePaths[idx]),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

typedef DocumentViewerScreen = PdfViewerScreen;