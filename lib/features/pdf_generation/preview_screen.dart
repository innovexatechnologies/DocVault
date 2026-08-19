import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/image_selection_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/pdf_document.dart';
import '../image_editing/image_editor_screen.dart';

class PreviewScreen extends StatefulWidget {
  final PdfDocument? existingDocument;
  final VoidCallback? onSave;

  const PreviewScreen({
    super.key,
    this.existingDocument,
    this.onSave,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late PageController _pageController;
  int _currentPageIndex = 0;

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

  void _generatePdf() {
    if (_isEditingExisting && widget.onSave != null) {
      Navigator.of(context).pop();
      widget.onSave!();
    } else {
      Navigator.of(context).pushNamed('/pdf-generation');
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

    if (images.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preview')),
        body: const Center(child: Text('No pages to preview')),
      );
    }

    final currentImage = images[_currentPageIndex.clamp(0, totalPages - 1)];

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
                    : 'Document Preview',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Page ${_currentPageIndex + 1} of $totalPages',
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
              tooltip: 'Edit Page',
              onPressed: () => _openEditorForCurrentPage(
                currentImage.id,
                currentImage.filePath,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Page Preview Viewer
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: totalPages,
                onPageChanged: (idx) {
                  setState(() => _currentPageIndex = idx);
                },
                itemBuilder: (context, index) {
                  final imgItem = images[index];
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: AspectRatio(
                        aspectRatio: 1 / 1.414, // A4 aspect ratio
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
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
                                File(imgItem.filePath),
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
                                width: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.file(
                                  File(images[idx].filePath),
                                  fit: BoxFit.cover,
                                  cacheWidth: 84,
                                  cacheHeight: 108,
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
                          label: const Text('Edit Page'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _generatePdf,
                            icon: Icon(
                              _isEditingExisting
                                  ? Icons.save_rounded
                                  : Icons.picture_as_pdf_rounded,
                              size: 18,
                            ),
                            label: Text(
                              _isEditingExisting ? 'Save Changes' : 'Generate PDF',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEditingExisting
                                  ? AppTheme.primaryColor
                                  : AppTheme.successColor,
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
