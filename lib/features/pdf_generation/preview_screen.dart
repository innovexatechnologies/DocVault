import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/image_selection_provider.dart';
import '../../core/theme/app_theme.dart';
import '../image_editing/image_editor_screen.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final PageController _pageController;
  int _currentPageIndex = 0;

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
    Navigator.of(context).pushNamed('/pdf-generation');
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
              const Text(
                'Document Preview',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit Current Page',
              onPressed: () => _openEditorForCurrentPage(
                currentImage.id,
                currentImage.filePath,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Page Viewer
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: totalPages,
                onPageChanged: (index) {
                  setState(() {
                    _currentPageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final item = images[index];
                  final file = File(item.filePath);

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 3.5,
                          child: file.existsSync()
                              ? Image.file(
                                  file,
                                  fit: BoxFit.contain,
                                  key: ValueKey(item.filePath),
                                )
                              : const Center(
                                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Thumbnail Strip & Generate Action
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor,
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Thumbnails list
                    if (totalPages > 1)
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: totalPages,
                          itemBuilder: (context, idx) {
                            final isSelected = idx == _currentPageIndex;
                            final thumbItem = images[idx];
                            return GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  idx,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.file(
                                  File(thumbItem.filePath),
                                  fit: BoxFit.cover,
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
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                            label: const Text(
                              'Generate PDF',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
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
