import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/image_selection_provider.dart';
import '../../core/providers/pdf_manager_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/conversion_type.dart';
import '../../models/pdf_document.dart';
import '../../models/pdf_result.dart';
import '../all_files/widgets/rename_pdf_dialog.dart';
import 'pdf_viewer_screen.dart';

class ResultScreen extends StatefulWidget {
  final DocumentResult pdfResult;

  const ResultScreen({super.key, required this.pdfResult});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late String _currentFilePath;
  late String _currentFileName;
  late ConversionType _docType;
  int _fileSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _currentFilePath = widget.pdfResult.filePath;
    _currentFileName = widget.pdfResult.fileName;
    _docType = widget.pdfResult.conversionType;
    _loadFileSizeBytes();

    // Clear image selection so subsequent conversions start fresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ImageSelectionProvider>().clearAllImages();
      context.read<PdfManagerProvider>().loadDocuments();
    });
  }

  Future<void> _loadFileSizeBytes() async {
    try {
      final file = File(_currentFilePath);
      if (await file.exists()) {
        final size = await file.length();
        if (mounted) {
          setState(() {
            _fileSizeBytes = size;
          });
        }
      }
    } catch (_) {}
  }

  String get _formattedSize {
    if (_fileSizeBytes < 1024) {
      return '$_fileSizeBytes B';
    } else if (_fileSizeBytes < 1024 * 1024) {
      return '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  void _openDocument() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          filePath: _currentFilePath,
          fileName: _currentFileName,
        ),
      ),
    );
  }

  Future<void> _openWithExternalApp() async {
    try {
      await OpenFile.open(_currentFilePath);
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

  Future<void> _shareDocument() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Share.shareXFiles(
        [XFile(_currentFilePath)],
        text: 'Document created with DocVault: $_currentFileName',
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
        (d) => d.filePath == _currentFilePath || d.fileName == _currentFileName,
        orElse: () => PdfDocument(
          id: '',
          fileName: _currentFileName,
          filePath: _currentFilePath,
          fileSizeBytes: _fileSizeBytes,
          pageCount: widget.pdfResult.pageCount,
          createdAt: widget.pdfResult.generatedAt,
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

  void _showRenameDialog() {
    final doc = PdfDocument(
      id: '',
      fileName: _currentFileName,
      filePath: _currentFilePath,
      fileSizeBytes: _fileSizeBytes,
      pageCount: widget.pdfResult.pageCount,
      createdAt: widget.pdfResult.generatedAt,
      modifiedAt: DateTime.now(),
    );

    showDialog(
      context: context,
      builder: (_) => RenamePdfDialog(
        document: doc,
        onRename: (newName) async {
          final provider = context.read<PdfManagerProvider>();
          final matchedDoc = provider.documents.firstWhere(
            (d) => d.filePath == _currentFilePath,
            orElse: () => doc,
          );

          if (matchedDoc.id.isNotEmpty) {
            final updated = await provider.renamePdf(matchedDoc.id, newName);
            if (mounted) {
              setState(() {
                _currentFileName = updated.fileName;
                _currentFilePath = updated.filePath;
              });
            }
          }
        },
      ),
    );
  }

  void _navigateToAllFiles() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/all-files',
      (route) => false,
    );
  }

  void _createNew() {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final padding = ResponsiveHelper.getResponsivePadding(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    final itemUnit = _docType == ConversionType.ppt ? 'slide(s)' : 'page(s)';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _createNew();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _createNew,
            tooltip: 'Back to Home',
          ),
          title: Text(
            '${_docType.shortName} Created',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.home_outlined),
              onPressed: _createNew,
              tooltip: 'Home',
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: padding,
            vertical: isMobile ? 16 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Success Animation Banner
              Container(
                width: isMobile ? 76 : 90,
                height: isMobile ? 76 : 90,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successColor,
                    size: 46,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Ready to Share & Use',
                style: TextStyle(
                  fontSize: isMobile ? 22 : 26,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Your ${_docType.label} was generated and saved locally.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(height: 20),

              // File Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _docType.badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _docType.icon,
                            color: _docType.badgeColor,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentFileName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.pdfResult.pageCount} $itemUnit • $_formattedSize',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Primary Action Buttons: Open in App / Open in External App
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _openDocument,
                  icon: const Icon(Icons.visibility_rounded, size: 20),
                  label: Text(
                    'View ${_docType.shortName}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _docType.badgeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareDocument,
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportDocument,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Save to Device'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _showRenameDialog,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Rename'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _openWithExternalApp,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('System App'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Navigate to All Files / Create Another
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _navigateToAllFiles,
                      icon: const Icon(Icons.folder_outlined, size: 18),
                      label: const Text('All Files'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _createNew,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Create New'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
