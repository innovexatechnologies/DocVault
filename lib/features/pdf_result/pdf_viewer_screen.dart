import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/pdf_manager_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_utils.dart';
import '../../models/pdf_document.dart' as model;

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
  late final PdfControllerPinch _pdfController;
  int _actualPageCount = 0;
  int _currentPage = 1;
  bool _isLoading = true;
  bool _isSavingToDocVault = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final file = File(widget.filePath);
    if (!file.existsSync()) {
      _errorMessage = 'PDF file not found on device';
      _isLoading = false;
      return;
    }

    _pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(widget.filePath),
    );
  }

  @override
  void dispose() {
    if (_errorMessage == null) {
      _pdfController.dispose();
    }
    super.dispose();
  }

  Future<void> _sharePdf() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Share.shareXFiles(
        [XFile(widget.filePath)],
        text: 'Sharing ${widget.fileName} from DocVault',
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to share PDF'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
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
          pageCount: _actualPageCount,
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

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : const Color(0xFFE8ECEB),
      appBar: AppBar(
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
                'Page $_currentPage of $_actualPageCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        actions: [
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
            icon: const Icon(Icons.share_outlined),
            onPressed: _sharePdf,
            tooltip: 'Share PDF',
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _exportPdf,
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
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                PdfViewPinch(
                  controller: _pdfController,
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
            ),
    );
  }
}