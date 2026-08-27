import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/image_selection_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/conversion_type.dart';
import '../../models/pdf_document.dart';
import '../image_editing/image_editor_screen.dart';
import 'pdf_generation_screen.dart';

class PreviewScreen extends StatefulWidget {
  final PdfDocument? existingDocument;
  final ConversionType conversionType;
  final VoidCallback? onSave;

  const PreviewScreen({
    super.key,
    this.existingDocument,
    this.conversionType = ConversionType.pdf,
    this.onSave,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late PageController _pageController;

  int _currentPageIndex = 0;

  ConversionType get _effectiveType =>
      widget.existingDocument?.documentType ?? widget.conversionType;

  bool get _isEditingExisting => widget.existingDocument != null;

  bool get _isPpt => _effectiveType == ConversionType.ppt;

  String get _itemUnit => _isPpt ? 'Slide' : 'Page';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================
  // OPEN IMAGE EDITOR
  // ============================================================

  Future<void> _openEditorForCurrentPage(
    String imageId,
    String imagePath,
  ) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ImageEditorScreen(
          imageId: imageId,
          imagePath: imagePath,
          pageIndex: _currentPageIndex,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // GENERATE / SAVE DOCUMENT
  // ============================================================

  void _generateDocument() {
    if (_isEditingExisting && widget.onSave != null) {
      Navigator.of(context).pop();
      widget.onSave!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfGenerationScreen(
            conversionType: _effectiveType,
          ),
        ),
      );
    }
  }

  // ============================================================
  // BACK
  // ============================================================

  void _handleBack() {
    Navigator.of(context).pop();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final imageProvider = context.watch<ImageSelectionProvider>();

    final images = imageProvider.selectedImages;
    final totalPages = images.length;

    // ============================================================
    // EMPTY STATE
    // ============================================================

    if (images.isEmpty) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          title: const Text(
            'Preview',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Center(
          child: _buildEmptyState(context),
        ),
      );
    }

    final safeIndex = _currentPageIndex.clamp(
      0,
      totalPages - 1,
    );

    final currentImage = images[safeIndex];

    // ============================================================
    // PREVIEW RATIO
    // ============================================================

    final previewAspectRatio = _isPpt
        ? 16 / 9
        : 1 / 1.414;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? AppTheme.bgDark
            : const Color(0xFFF1F4F3),

        // ========================================================
        // APP BAR
        // ========================================================

        appBar: AppBar(
          backgroundColor: isDark
              ? AppTheme.surfaceDark
              : AppTheme.surfaceLight,

          foregroundColor: colorScheme.onSurface,

          elevation: 0,

          scrolledUnderElevation: 0,

          leading: IconButton(
            onPressed: _handleBack,
            tooltip: 'Back',
            icon: const Icon(
              Icons.arrow_back_rounded,
            ),
          ),

          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditingExisting
                    ? widget.existingDocument!.title
                    : '${_effectiveType.shortName} Preview',

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                '$_itemUnit ${safeIndex + 1} of $totalPages',

                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withValues(
                    alpha: 0.55,
                  ),
                ),
              ),
            ],
          ),

          actions: [
            // ====================================================
            // CURRENT PAGE EDIT
            // ====================================================

            IconButton(
              onPressed: () {
                _openEditorForCurrentPage(
                  currentImage.id,
                  currentImage.filePath,
                );
              },

              tooltip: 'Edit $_itemUnit',

              icon: Container(
                padding: const EdgeInsets.all(7),

                decoration: BoxDecoration(
                  color: _effectiveType.badgeColor.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),

                child: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: _effectiveType.badgeColor,
                ),
              ),
            ),

            const SizedBox(width: 6),
          ],
        ),

        // ========================================================
        // BODY
        // ========================================================

        body: Column(
          children: [
            // ======================================================
            // PAGE COUNTER
            // ======================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                14,
                16,
                8,
              ),

              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),

                    decoration: BoxDecoration(
                      color: _effectiveType.badgeColor.withValues(
                        alpha: isDark ? 0.16 : 0.10,
                      ),

                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Row(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Icon(
                          _isPpt
                              ? Icons.slideshow_rounded
                              : Icons.description_rounded,

                          size: 16,

                          color: _effectiveType.badgeColor,
                        ),

                        const SizedBox(width: 6),

                        Text(
                          '$_itemUnit ${safeIndex + 1}',

                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _effectiveType.badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  Text(
                    '$totalPages ${_isPpt ? 'slides' : 'pages'}',

                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ======================================================
            // IMAGE PREVIEW
            // ======================================================

            Expanded(
              child: PageView.builder(
                controller: _pageController,

                scrollDirection: _isPpt
                    ? Axis.horizontal
                    : Axis.vertical,

                itemCount: totalPages,

                physics: const BouncingScrollPhysics(),

                onPageChanged: (index) {
                  if (!mounted) return;

                  setState(() {
                    _currentPageIndex = index;
                  });
                },

                itemBuilder: (context, index) {
                  final imgItem = images[index];

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        18,
                        8,
                        18,
                        14,
                      ),

                      child: AspectRatio(
                        aspectRatio: previewAspectRatio,

                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,

                            borderRadius: BorderRadius.circular(
                              _isPpt ? 14 : 10,
                            ),

                            border: Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.black12,
                            ),

                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: 0.12,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),

                          clipBehavior: Clip.antiAlias,

                          child: Stack(
                            fit: StackFit.expand,

                            children: [
                              // ==================================
                              // IMAGE
                              // ==================================

                              Image.file(
                                File(imgItem.filePath),

                                fit: BoxFit.contain,

                                key: ValueKey(
                                  imgItem.filePath,
                                ),

                                errorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,

                                      children: [
                                        Icon(
                                          Icons
                                              .broken_image_outlined,

                                          size: 52,

                                          color: Colors.grey
                                              .shade400,
                                        ),

                                        const SizedBox(height: 10),

                                        Text(
                                          'Unable to load image',

                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey
                                                .shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // ==================================
                              // PAGE NUMBER
                              // ==================================

                              Positioned(
                                right: 10,
                                bottom: 10,

                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),

                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(
                                      alpha: 0.62,
                                    ),

                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),

                                  child: Text(
                                    '${index + 1}',

                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),

                              // ==================================
                              // DOCX LABEL
                              // ==================================

                              if (_effectiveType ==
                                  ConversionType.docs)
                                Positioned(
                                  left: 10,
                                  top: 10,

                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),

                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(
                                        alpha: 0.90,
                                      ),

                                      borderRadius:
                                          BorderRadius.circular(7),
                                    ),

                                    child: Text(
                                      'DOCX • Page ${index + 1}',

                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.black54,
                                        fontWeight:
                                            FontWeight.w700,
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
            // BOTTOM DOCK
            // ======================================================

            SafeArea(
              top: false,

              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  10,
                  14,
                  12,
                ),

                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.surfaceDark
                      : AppTheme.surfaceLight,

                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppTheme.dividerDark
                          : AppTheme.dividerColor,
                    ),
                  ),
                ),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    // ==================================================
                    // THUMBNAILS
                    // ==================================================

                    if (totalPages > 1)
                      SizedBox(
                        height: 62,

                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,

                          physics:
                              const BouncingScrollPhysics(),

                          itemCount: totalPages,

                          separatorBuilder:
                              (context, index) =>
                                  const SizedBox(width: 8),

                          itemBuilder: (context, index) {
                            final isSelected =
                                index == safeIndex;

                            return GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  index,

                                  duration:
                                      const Duration(
                                    milliseconds: 300,
                                  ),

                                  curve: Curves.easeOutCubic,
                                );
                              },

                              child: AnimatedContainer(
                                duration:
                                    const Duration(
                                  milliseconds: 200,
                                ),

                                width: _isPpt ? 76 : 48,

                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black12
                                      : Colors.grey.shade100,

                                  borderRadius:
                                      BorderRadius.circular(9),

                                  border: Border.all(
                                    color: isSelected
                                        ? _effectiveType
                                            .badgeColor
                                        : Colors.transparent,

                                    width: 2,
                                  ),

                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color:
                                                _effectiveType
                                                    .badgeColor
                                                    .withValues(
                                              alpha: 0.18,
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
                                        images[index].filePath,
                                      ),

                                      fit: BoxFit.cover,

                                      cacheWidth: 160,
                                      cacheHeight: 160,
                                    ),

                                    // Thumbnail number
                                    Positioned(
                                      right: 3,
                                      bottom: 3,

                                      child: Container(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),

                                        decoration:
                                            BoxDecoration(
                                          color: Colors.black
                                              .withValues(
                                            alpha: 0.65,
                                          ),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                            5,
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
                      ),

                    if (totalPages > 1)
                      const SizedBox(height: 12),

                    // ==================================================
                    // ACTION BUTTONS
                    // ==================================================

                    Row(
                      children: [
                        // ============================================
                        // EDIT BUTTON
                        // ============================================

                        Expanded(
                          flex: 2,

                          child: OutlinedButton.icon(
                            onPressed: () {
                              _openEditorForCurrentPage(
                                currentImage.id,
                                currentImage.filePath,
                              );
                            },

                            icon: const Icon(
                              Icons.edit_rounded,
                              size: 18,
                            ),

                            label: Text(
                              'Edit $_itemUnit',

                              maxLines: 1,

                              overflow:
                                  TextOverflow.ellipsis,

                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  colorScheme.primary,

                              side: BorderSide(
                                color:
                                    colorScheme.primary
                                        .withValues(
                                  alpha: 0.65,
                                ),
                              ),

                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 13,
                                horizontal: 10,
                              ),

                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(13),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // ============================================
                        // GENERATE / SAVE BUTTON
                        // ============================================

                        Expanded(
                          flex: 3,

                          child: ElevatedButton.icon(
                            onPressed: _generateDocument,

                            icon: Icon(
                              _isEditingExisting
                                  ? Icons.save_rounded
                                  : _effectiveType.icon,

                              size: 18,
                            ),

                            label: Text(
                              _isEditingExisting
                                  ? 'Save Changes'
                                  : 'Generate ${_effectiveType.shortName}',

                              maxLines: 1,

                              overflow:
                                  TextOverflow.ellipsis,

                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isEditingExisting
                                      ? AppTheme.primaryColor
                                      : _effectiveType
                                          .badgeColor,

                              foregroundColor: Colors.white,

                              elevation: 0,

                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 13,
                                horizontal: 10,
                              ),

                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          Container(
            width: 90,
            height: 90,

            decoration: BoxDecoration(
              color: _effectiveType.badgeColor.withValues(
                alpha: 0.10,
              ),

              borderRadius: BorderRadius.circular(24),
            ),

            child: Icon(
              _isPpt
                  ? Icons.slideshow_rounded
                  : Icons.description_outlined,

              size: 48,

              color: _effectiveType.badgeColor,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            _isPpt
                ? 'No slides to preview'
                : 'No pages to preview',

            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Add some images first to see your preview.',

            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(
                alpha: 0.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}