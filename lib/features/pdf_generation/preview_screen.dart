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

  void _openEditorForCurrentPage(String imageId, String imagePath) async {
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

  void _generateDocument() {
    if (_isEditingExisting && widget.onSave != null) {
      Navigator.of(context).pop();
      widget.onSave!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfGenerationScreen(conversionType: _effectiveType),
        ),
      );
    }
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final imageProvider = context.watch<ImageSelectionProvider>();
    final images = imageProvider.selectedImages;
    final totalPages = images.length;
    final itemUnit = _effectiveType == ConversionType.ppt ? 'Slide' : 'Page';

    if (images.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preview')),
        body: Center(
          child: Text(
            _effectiveType == ConversionType.ppt
                ? 'No slides to preview'
                : 'No pages to preview',
          ),
        ),
      );
    }

    final currentImage = images[_currentPageIndex.clamp(0, totalPages - 1)];

    // Aspect ratio: A4 (1 / 1.414) for PDF/DOCS, 16:9 for PPT
    final previewAspectRatio =
        _effectiveType == ConversionType.ppt ? (16 / 9) : (1 / 1.414);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.bgDark : const Color(0xFFE8ECEB),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
            tooltip: 'Back',
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditingExisting
                    ? 'Preview: ${widget.existingDocument!.title}'
                    : '${_effectiveType.shortName} Preview',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '$itemUnit ${_currentPageIndex + 1} of $totalPages',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Edit $itemUnit',
              onPressed: () => _openEditorForCurrentPage(
                currentImage.id,
                currentImage.filePath,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
       Expanded(
  child: PageView.builder(
    controller: _pageController,

    // ============================================================
    // MOVEMENT DIRECTION
    // PDF / DOCX  → TOP TO BOTTOM
    // PPTX        → LEFT TO RIGHT
    // ============================================================
    scrollDirection: _effectiveType == ConversionType.ppt
        ? Axis.horizontal
        : Axis.vertical,

    itemCount: totalPages,

    onPageChanged: (idx) {
      if (!mounted) return;

      setState(() {
        _currentPageIndex = idx;
      });
    },

    itemBuilder: (context, index) {
      final imgItem = images[index];

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: AspectRatio(
            aspectRatio: previewAspectRatio,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  _effectiveType == ConversionType.ppt
                      ? 12
                      : 8,
                ),
                border: _effectiveType == ConversionType.docs
                    ? Border.all(
                        color: Colors.blueGrey.shade100,
                        width: 1,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.15,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ========================================================
                  // PAGE / SLIDE IMAGE
                  // ========================================================

                  Image.file(
                    File(imgItem.filePath),
                    fit: BoxFit.contain,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),

                  // ========================================================
                  // PAGE / SLIDE NUMBER
                  // ========================================================

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

                  // ========================================================
                  // DOCX LABEL
                  // ========================================================

                  if (_effectiveType == ConversionType.docs)
                    Positioned(
                      top: 8,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white70,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'DOCX Page ${index + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black38,
                            fontWeight: FontWeight.w600,
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
            // Bottom Navigation & Edit Actions Dock
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Thumbnail Carousel (for >1 pages)
                    if (totalPages > 1)
                      SizedBox(
                        height: 54,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: totalPages,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final isSelected = idx == _currentPageIndex;
                            return GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  idx,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: Container(
                                width: _effectiveType == ConversionType.ppt ? 64 : 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? _effectiveType.badgeColor
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.file(
                                  File(images[idx].filePath),
                                  fit: BoxFit.cover,
                                  cacheWidth: 96,
                                  cacheHeight: 96,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (totalPages > 1) const SizedBox(height: 12),

                    // Actions Row
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openEditorForCurrentPage(
                            currentImage.id,
                            currentImage.filePath,
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: Text('Edit $itemUnit'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
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
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEditingExisting
                                  ? AppTheme.primaryColor
                                  : _effectiveType.badgeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}
