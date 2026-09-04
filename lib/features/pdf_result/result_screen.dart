import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

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

  const ResultScreen({
    super.key,
    required this.pdfResult,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late String _currentFilePath;
  late String _currentFileName;
  late ConversionType _docType;

  int _fileSizeBytes = 0;
  bool _isExporting = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();

    _currentFilePath = widget.pdfResult.filePath;
    _currentFileName = widget.pdfResult.fileName;
    _docType = widget.pdfResult.conversionType;

    _loadFileSizeBytes();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<PdfManagerProvider>().loadDocuments();
    });
  }

  // ===========================================================================
  // FILE SIZE
  // ===========================================================================

  Future<void> _loadFileSizeBytes() async {
    try {
      final file = File(_currentFilePath);

      if (await file.exists()) {
        final size = await file.length();

        if (!mounted) return;

        setState(() {
          _fileSizeBytes = size;
        });
      }
    } catch (_) {
      // Ignore file size errors.
    }
  }

  String get _formattedSize {
    if (_fileSizeBytes <= 0) {
      return 'Calculating...';
    }

    if (_fileSizeBytes < 1024) {
      return '$_fileSizeBytes B';
    }

    if (_fileSizeBytes < 1024 * 1024) {
      return '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  // ===========================================================================
  // COLORS
  // ===========================================================================

  Color get _accentColor => _docType.badgeColor;

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  }

  void _navigateToAllFiles() {
    Navigator.of(context).pushNamed('/all-files');
  }

  // ===========================================================================
  // VIEW DOCUMENT
  // ===========================================================================

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

  // ===========================================================================
  // SYSTEM APP
  // ===========================================================================

  Future<void> _openWithExternalApp() async {
    try {
      final result = await OpenFile.open(
        _currentFilePath,
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

  // ===========================================================================
  // SHARE
  // ===========================================================================

  Future<void> _shareDocument() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      await Share.shareXFiles(
        [
          XFile(_currentFilePath),
        ],
        text:
            'Document created with DocScanner: $_currentFileName',
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Failed to share document',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  // ===========================================================================
  // EXPORT / SAVE
  // ===========================================================================

  Future<void> _exportDocument() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final provider =
          context.read<PdfManagerProvider>();

      final doc = provider.documents.firstWhere(
        (d) =>
            d.filePath == _currentFilePath ||
            d.fileName == _currentFileName,
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

      final exportedPath =
          await provider.exportPdf(doc.id);

      if (!mounted) return;

      if (exportedPath != null) {
        _showSnackBar(
          'File saved successfully',
        );
      } else {
        _showSnackBar(
          'Unable to save document',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Export failed: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  // ===========================================================================
  // RENAME
  // ===========================================================================

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
          final provider =
              context.read<PdfManagerProvider>();

          final matchedDoc =
              provider.documents.firstWhere(
            (d) => d.filePath == _currentFilePath,
            orElse: () => doc,
          );

          if (matchedDoc.id.isNotEmpty) {
            final updated =
                await provider.renamePdf(
              matchedDoc.id,
              newName,
            );

            if (!mounted) return;

            setState(() {
              _currentFileName =
                  updated.fileName;

              _currentFilePath =
                  updated.filePath;
            });
          }
        },
      ),
    );
  }

  // ===========================================================================
  // SNACKBAR
  // ===========================================================================

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? AppTheme.errorColor
              : AppTheme.successColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDark =
        theme.brightness == Brightness.dark;

    final padding =
        ResponsiveHelper.getResponsivePadding(
      context,
    );

    final isMobile =
        ResponsiveHelper.isMobile(context);

    final pageUnit =
        _docType == ConversionType.ppt
            ? 'slides'
            : 'pages';

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: isDark
            ? AppTheme.bgDark
            : const Color(0xFFF7F8FC),

        // =====================================================================
        // APP BAR
        // =====================================================================

        appBar: AppBar(
          backgroundColor: isDark
              ? AppTheme.bgDark
              : const Color(0xFFF7F8FC),

          foregroundColor:
              colorScheme.onSurface,

          elevation: 0,

          scrolledUnderElevation: 0,

          leading: Padding(
            padding: const EdgeInsets.only(
              left: 8,
            ),
            child: IconButton(
              onPressed: _goBack,
              tooltip: 'Back',
              style: IconButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.white.withValues(
                        alpha: 0.06,
                      )
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(
                            alpha: 0.08,
                          )
                        : const Color(0xFFE8EAF0),
                  ),
                ),
              ),
              icon: const Icon(
                Icons.arrow_back_rounded,
              ),
            ),
          ),

          title: Text(
            'Created Successfully',
            style: TextStyle(
              fontSize: isMobile ? 17 : 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),

          actions: [
            Padding(
              padding: const EdgeInsets.only(
                right: 12,
              ),
              child: IconButton(
                onPressed: _goHome,
                tooltip: 'Home',
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white.withValues(
                          alpha: 0.06,
                        )
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(
                              alpha: 0.08,
                            )
                          : const Color(0xFFE8EAF0),
                    ),
                  ),
                ),
                icon: const Icon(
                  Icons.home_outlined,
                ),
              ),
            ),
          ],
        ),

        // =====================================================================
        // BODY
        // =====================================================================

        body: SafeArea(
          child: SingleChildScrollView(
            physics:
                const BouncingScrollPhysics(),

            padding: EdgeInsets.fromLTRB(
              padding,
              12,
              padding,
              30,
            ),

            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 650,
                ),

                child: Column(
                  children: [
                    // ===========================================================
                    // SUCCESS HEADER
                    // ===========================================================

                    _buildSuccessHeader(
                      isDark,
                      colorScheme,
                      isMobile,
                    ),

                    const SizedBox(
                      height: 26,
                    ),

                    // ===========================================================
                    // FILE CARD
                    // ===========================================================

                    _buildFileCard(
                      isDark,
                      colorScheme,
                      pageUnit,
                      isMobile,
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // ===========================================================
                    // PRIMARY VIEW BUTTON
                    // ===========================================================

                    _buildViewButton(
                      isMobile,
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ===========================================================
                    // SHARE + SAVE
                    // ===========================================================

                    _buildActionButtons(
                      isDark,
                      isMobile,
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // ===========================================================
                    // MORE OPTIONS
                    // ===========================================================

                    _buildSecondaryActions(
                      isDark,
                      isMobile,
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    // ===========================================================
                    // DIVIDER
                    // ===========================================================

                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: isDark
                                ? Colors.white
                                    .withValues(
                                    alpha: 0.10,
                                  )
                                : const Color(
                                    0xFFE3E5EB,
                                  ),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 12,
                          ),
                          child: Text(
                            'MORE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.w800,
                              letterSpacing: 1.2,
                              color: colorScheme
                                  .onSurface
                                  .withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: isDark
                                ? Colors.white
                                    .withValues(
                                    alpha: 0.10,
                                  )
                                : const Color(
                                    0xFFE3E5EB,
                                  ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // ===========================================================
                    // ALL FILES + CREATE NEW
                    // ===========================================================

                    _buildBottomActions(
                      isDark,
                      isMobile,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SUCCESS HEADER
  // ===========================================================================

  Widget _buildSuccessHeader(
    bool isDark,
    ColorScheme colorScheme,
    bool isMobile,
  ) {
    return Column(
      children: [
        Container(
          width: isMobile ? 84 : 96,
          height: isMobile ? 84 : 96,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: AppTheme.successColor
                .withValues(alpha: 0.10),

            border: Border.all(
              color: AppTheme.successColor
                  .withValues(alpha: 0.18),
              width: 1,
            ),
          ),

          child: Center(
            child: Container(
              width: isMobile ? 62 : 70,
              height: isMobile ? 62 : 70,

              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.successColor,
              ),

              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        Text(
          '${_docType.shortName} Ready!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 25 : 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: colorScheme.onSurface,
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        Text(
          'Your ${_docType.label} has been created successfully.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            height: 1.45,
            color: colorScheme.onSurface
                .withValues(alpha: 0.58),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // FILE CARD
  // ===========================================================================

  Widget _buildFileCard(
    bool isDark,
    ColorScheme colorScheme,
    String pageUnit,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,

      padding: EdgeInsets.all(
        isMobile ? 17 : 20,
      ),

      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.surfaceDark
            : Colors.white,

        borderRadius:
            BorderRadius.circular(22),

        border: Border.all(
          color: isDark
              ? Colors.white.withValues(
                  alpha: 0.07,
                )
              : const Color(0xFFE8EAF0),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.12 : 0.045,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ===============================================================
              // FILE ICON
              // ===============================================================

              Container(
                width: isMobile ? 58 : 66,
                height: isMobile ? 58 : 66,

                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(17),

                  color: _accentColor
                      .withValues(alpha: 0.12),
                ),

                child: Icon(
                  _docType.icon,
                  color: _accentColor,
                  size: isMobile ? 31 : 35,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              // ===============================================================
              // FILE INFORMATION
              // ===============================================================

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentFileName,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize:
                            isMobile ? 15 : 17,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        _buildInfoChip(
                          icon: Icons.description_outlined,
                          text:
                              '${widget.pdfResult.pageCount} $pageUnit',
                          isDark: isDark,
                        ),

                        _buildInfoChip(
                          icon: Icons.data_usage_rounded,
                          text: _formattedSize,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ===============================================================
              // RENAME
              // ===============================================================

              IconButton(
                onPressed: _showRenameDialog,
                tooltip: 'Rename',
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: colorScheme.onSurface
                      .withValues(alpha: 0.60),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          // ===============================================================
          // FILE STATUS
          // ===============================================================

          Container(
            width: double.infinity,

            padding:
                const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 10,
            ),

            decoration: BoxDecoration(
              color: AppTheme.successColor
                  .withValues(alpha: 0.07),

              borderRadius:
                  BorderRadius.circular(12),
            ),

            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 17,
                  color: AppTheme.successColor,
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child: Text(
                    'Saved locally and ready to use',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                      color: colorScheme
                          .onSurface
                          .withValues(
                        alpha: 0.68,
                      ),
                    ),
                  ),
                ),

                const Icon(
                  Icons.check_circle_rounded,
                  size: 17,
                  color: AppTheme.successColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // INFO CHIP
  // ===========================================================================

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),

      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(
                alpha: 0.06,
              )
            : const Color(0xFFF4F5F8),

        borderRadius:
            BorderRadius.circular(8),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: _accentColor,
          ),

          const SizedBox(
            width: 5,
          ),

          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // VIEW BUTTON
  // ===========================================================================

  Widget _buildViewButton(
    bool isMobile,
  ) {
    return SizedBox(
      width: double.infinity,
      height: isMobile ? 54 : 58,

      child: ElevatedButton.icon(
        onPressed: _openDocument,

        icon: const Icon(
          Icons.visibility_rounded,
          size: 21,
        ),

        label: Text(
          'View ${_docType.shortName}',
          style: TextStyle(
            fontSize: isMobile ? 15 : 16,
            fontWeight: FontWeight.w800,
          ),
        ),

        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,

          elevation: 0,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SHARE + SAVE BUTTONS
  // ===========================================================================

  Widget _buildActionButtons(
    bool isDark,
    bool isMobile,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildOutlinedAction(
            icon: _isSharing
                ? Icons.hourglass_top_rounded
                : Icons.share_outlined,
            label: 'Share',
            onPressed:
                _isSharing ? null : _shareDocument,
            isDark: isDark,
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child: _buildOutlinedAction(
            icon: _isExporting
                ? Icons.hourglass_top_rounded
                : Icons.download_outlined,
            label: _isExporting
                ? 'Saving...'
                : 'Save',
            onPressed:
                _isExporting ? null : _exportDocument,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // OUTLINED ACTION
  // ===========================================================================

  Widget _buildOutlinedAction({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isDark,
  }) {
    return SizedBox(
      height: 50,

      child: OutlinedButton.icon(
        onPressed: onPressed,

        icon: Icon(
          icon,
          size: 19,
        ),

        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        style: OutlinedButton.styleFrom(
          foregroundColor:
              Theme.of(context)
                  .colorScheme
                  .onSurface,

          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(
                    alpha: 0.12,
                  )
                : const Color(0xFFE0E3EA),
          ),

          backgroundColor: isDark
              ? Colors.white.withValues(
                  alpha: 0.03,
                )
              : Colors.white,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECONDARY ACTIONS
  // ===========================================================================

  Widget _buildSecondaryActions(
    bool isDark,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),

      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(
                alpha: 0.025,
              )
            : Colors.white,

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color: isDark
              ? Colors.white.withValues(
                  alpha: 0.06,
                )
              : const Color(0xFFE8EAF0),
        ),
      ),

      child: Row(
        children: [
          Expanded(
            child: _buildSmallAction(
              icon: Icons.edit_outlined,
              label: 'Rename',
              onPressed: _showRenameDialog,
            ),
          ),

          Container(
            height: 30,
            width: 1,
            color: isDark
                ? Colors.white.withValues(
                    alpha: 0.08,
                  )
                : const Color(0xFFE5E7EC),
          ),

          Expanded(
            child: _buildSmallAction(
              icon: Icons.open_in_new_rounded,
              label: 'System App',
              onPressed:
                  _openWithExternalApp,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SMALL ACTION
  // ===========================================================================

  Widget _buildSmallAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return TextButton(
      onPressed: onPressed,

      style: TextButton.styleFrom(
        foregroundColor:
            colorScheme.onSurface
                .withValues(alpha: 0.70),

        padding:
            const EdgeInsets.symmetric(
          vertical: 11,
        ),
      ),

      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
            ),

            const SizedBox(
              width: 7,
            ),

            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM ACTIONS
  // ===========================================================================

  Widget _buildBottomActions(
    bool isDark,
    bool isMobile,
  ) {
    return Row(
      children: [
        // =====================================================================
        // ALL FILES
        // =====================================================================

        Expanded(
          child: _buildBottomCard(
            icon: Icons.folder_outlined,
            label: 'All Files',
            onPressed: _navigateToAllFiles,
            isDark: isDark,
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        // =====================================================================
        // CREATE NEW
        // =====================================================================

        Expanded(
          child: _buildBottomCard(
            icon: Icons.add_rounded,
            label: 'Create New',
            onPressed: _goHome,
            isDark: isDark,
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // BOTTOM CARD
  // ===========================================================================

  Widget _buildBottomCard({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isDark,
    bool isPrimary = false,
  }) {
    return SizedBox(
      height: 54,

      child: Material(
        color: isPrimary
            ? _accentColor
            : isDark
                ? AppTheme.surfaceDark
                : Colors.white,

        borderRadius:
            BorderRadius.circular(16),

        child: InkWell(
          onTap: onPressed,

          borderRadius:
              BorderRadius.circular(16),

          child: Container(
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(16),

              border: isPrimary
                  ? null
                  : Border.all(
                      color: isDark
                          ? Colors.white
                              .withValues(
                              alpha: 0.08,
                            )
                          : const Color(
                              0xFFE4E6EC,
                            ),
                    ),
            ),

            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,

                children: [
                  Icon(
                    icon,
                    size: 21,
                    color: isPrimary
                        ? Colors.white
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(
                            alpha: 0.72,
                          ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w800,
                      color: isPrimary
                          ? Colors.white
                          : Theme.of(context)
                              .colorScheme
                              .onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}