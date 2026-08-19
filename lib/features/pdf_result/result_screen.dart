import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/image_selection_provider.dart';
import '../../core/providers/pdf_manager_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/pdf_document.dart';
import '../../models/pdf_result.dart';
import '../all_files/widgets/rename_pdf_dialog.dart';
import 'pdf_viewer_screen.dart';

class ResultScreen extends StatefulWidget {
  final PdfResult pdfResult;

  const ResultScreen({super.key, required this.pdfResult});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late String _currentFilePath;
  late String _currentFileName;
  int _fileSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _currentFilePath = widget.pdfResult.filePath;
    _currentFileName = widget.pdfResult.fileName;
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

  void _openPdf() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          filePath: _currentFilePath,
          fileName: _currentFileName,
        ),
      ),
    );
  }

  Future<void> _sharePdf() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Share.shareXFiles(
        [XFile(_currentFilePath)],
        text: 'Document created with DocVault: $_currentFileName',
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

  void _createNewPdf() {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final padding = ResponsiveHelper.getResponsivePadding(context);
    final isMobile = ResponsiveHelper.isMobile(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _createNewPdf();
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
            onPressed: _createNewPdf,
            tooltip: 'Back to Home',
          ),
          title: const Text(
            'PDF Created',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _createNewPdf,
              tooltip: 'Close',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: padding,
              vertical: isMobile ? 16 : 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Success Badge Animation / Icon
                Center(
                  child: Container(
                    width: isMobile ? 90 : 110,
                    height: isMobile ? 90 : 110,
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(
                        alpha: isDark ? 0.20 : 0.12,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.successColor.withValues(
                            alpha: isDark ? 0.22 : 0.15,
                          ),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: isMobile ? 54 : 64,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Congratulatory Title
                Text(
                  'Congratulations!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 24 : 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Your PDF has been created and saved locally in DocVault storage.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),

                const SizedBox(height: 24),

                // Document Summary Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.25 : 0.04,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor.withValues(alpha: 0.2),
                                  AppTheme.accentColor.withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: AppTheme.primaryColor,
                              size: 24,
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
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${widget.pdfResult.pageCount} ${widget.pdfResult.pageCount == 1 ? 'page' : 'pages'}'
                                  '${_fileSizeBytes > 0 ? ' • $_formattedSize' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _showRenameDialog,
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Rename PDF',
                            color: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Primary Action Button: Open PDF
                SizedBox(
                  height: ResponsiveHelper.getResponsiveButtonHeight(context),
                  child: ElevatedButton.icon(
                    onPressed: _openPdf,
                    icon: const Icon(Icons.visibility_rounded, size: 20),
                    label: const Text(
                      'Open PDF',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Quick Action Grid (Share, Save to Device, Rename, All Files)
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: _sharePdf,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.download_rounded,
                        label: 'Save to Device',
                        onTap: _exportPdf,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.edit_outlined,
                        label: 'Rename',
                        onTap: _showRenameDialog,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.folder_rounded,
                        label: 'All Files',
                        onTap: _navigateToAllFiles,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Secondary Action: Create Another PDF
                OutlinedButton.icon(
                  onPressed: _createNewPdf,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Create Another PDF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
