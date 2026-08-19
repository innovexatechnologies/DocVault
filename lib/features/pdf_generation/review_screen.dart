import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/image_selection_provider.dart';
import '../../core/services/gallery_service.dart';
import '../../core/utils/responsive_helper.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _isReordering = false;

  void _toggleReorderMode() {
    setState(() {
      _isReordering = !_isReordering;
    });
  }

  void _removeImage(String imageId) {
    context.read<ImageSelectionProvider>().removeImage(imageId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image removed'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _reorderImages(int oldIndex, int newIndex) {
    context.read<ImageSelectionProvider>().reorderImages(oldIndex, newIndex);
  }

  void _swapImages(int indexA, int indexB) {
    context.read<ImageSelectionProvider>().swapImages(indexA, indexB);
  }

  Future<void> _addMoreImages(String source) async {
    if (source == 'camera') {
      if (mounted) {
        Navigator.of(context).pushNamed('/camera');
      }
    } else {
      final galleryService = GalleryService();
      try {
        final imagePaths = await galleryService.pickImages();
        if (imagePaths.isNotEmpty && mounted) {
          context.read<ImageSelectionProvider>().addImages(
            imagePaths,
            'gallery',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${imagePaths.length} image(s)'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to pick images'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _generatePdf() {
    Navigator.of(context).pushNamed('/pdf-generation');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_isReordering,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isReordering) {
          setState(() {
            _isReordering = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () {
              if (_isReordering) {
                setState(() {
                  _isReordering = false;
                });
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          title: const Text(AppConstants.review),
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  '${context.watch<ImageSelectionProvider>().imageCount} images',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Consumer<ImageSelectionProvider>(
          builder: (context, imageProvider, _) {
            if (!imageProvider.hasImages) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 60,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No images selected',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Image Grid
                Expanded(
                  child: _isReordering
                      ? ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          padding: EdgeInsets.all(
                            ResponsiveHelper.getGridSpacing(context),
                          ),
                          itemCount: imageProvider.selectedImages.length,
                          onReorder: _reorderImages,
                          itemBuilder: (context, index) {
                            final imageItem =
                                imageProvider.selectedImages[index];
                            return _buildReorderableRowItem(imageItem, index);
                          },
                        )
                      : GridView.builder(
                          padding: EdgeInsets.all(
                            ResponsiveHelper.getGridSpacing(context),
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    ResponsiveHelper.getGridCrossAxisCount(
                                      context,
                                    ),
                                crossAxisSpacing:
                                    ResponsiveHelper.getGridSpacing(context),
                                mainAxisSpacing:
                                    ResponsiveHelper.getGridSpacing(context),
                              ),
                          itemCount: imageProvider.selectedImages.length,
                          itemBuilder: (context, index) {
                            return _buildImageItem(
                              imageProvider.selectedImages[index],
                              index,
                            );
                          },
                        ),
                ),
                // Bottom Controls
                Container(
                  color: AppTheme.bgWhite,
                  padding: EdgeInsets.all(
                    ResponsiveHelper.getResponsivePadding(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Mode Toggle Button
                      if (!_isReordering)
                        SizedBox(
                          height: ResponsiveHelper.getResponsiveButtonHeight(
                            context,
                          ),
                          child: OutlinedButton.icon(
                            onPressed: _toggleReorderMode,
                            icon: const Icon(Icons.drag_handle),
                            label: const Text(AppConstants.reorder),
                          ),
                        ),
                      if (_isReordering)
                        SizedBox(
                          height: ResponsiveHelper.getResponsiveButtonHeight(
                            context,
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _toggleReorderMode,
                            icon: const Icon(Icons.check),
                            label: const Text('Done'),
                          ),
                        ),
                      SizedBox(
                        height: ResponsiveHelper.isMobile(context) ? 10 : 16,
                      ),
                      // Add More Options
                      ResponsiveHelper.isMobile(context)
                          ? Column(
                              children: [
                                SizedBox(
                                  height:
                                      ResponsiveHelper.getResponsiveButtonHeight(
                                        context,
                                      ),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _addMoreImages('camera'),
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Camera'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height:
                                      ResponsiveHelper.getResponsiveButtonHeight(
                                        context,
                                      ),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _addMoreImages('gallery'),
                                    icon: const Icon(Icons.image),
                                    label: const Text('Gallery'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _addMoreImages('camera'),
                                    icon: const Icon(Icons.camera_alt, size: 18),
                                    label: const Text('Camera'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _addMoreImages('gallery'),
                                    icon: const Icon(Icons.image, size: 18),
                                    label: const Text('Gallery'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentColor,
                                      foregroundColor: AppTheme.bgDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      SizedBox(
                        height: ResponsiveHelper.isMobile(context) ? 10 : 16,
                      ),
                      // Generate PDF Button
                      SizedBox(
                        height: ResponsiveHelper.getResponsiveButtonHeight(
                          context,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _generatePdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text(
                            AppConstants.generatePdf,
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context,
                                mobileSize: 14,
                                tabletSize: 16,
                                desktopSize: 18,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageItem(dynamic imageItem, int index) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(imageItem.filePath),
            fit: BoxFit.cover,
            cacheWidth: 220,
            cacheHeight: 220,
            filterQuality: FilterQuality.medium,
          ),
          // Page Number Badge
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // Remove Button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _removeImage(imageItem.id),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          // Source Badge
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: imageItem.source == 'camera'
                    ? AppTheme.primaryColor
                    : AppTheme.accentColor,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                imageItem.source.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableRowItem(dynamic imageItem, int index) {
    final canMoveUp = index > 0;
    final canMoveDown =
        index < context.read<ImageSelectionProvider>().imageCount - 1;

    return Container(
      key: ValueKey(imageItem.id),
      margin: const EdgeInsets.only(bottom: 12),
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.transparent,
              child: const Icon(
                Icons.drag_indicator,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(imageItem.filePath),
                  fit: BoxFit.cover,
                  cacheWidth: 200,
                  cacheHeight: 200,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppTheme.bgLight,
                    child: const Icon(
                      Icons.broken_image,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Page ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (imageItem.source == 'camera'
                            ? AppTheme.primaryColor
                            : AppTheme.accentColor)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    imageItem.source.toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: imageItem.source == 'camera'
                          ? AppTheme.primaryColor
                          : AppTheme.accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 36,
                width: 36,
                child: IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  onPressed: canMoveUp
                      ? () => _swapImages(index, index - 1)
                      : null,
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: 'Move Up',
                ),
              ),
              SizedBox(
                height: 36,
                width: 36,
                child: IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  onPressed: canMoveDown
                      ? () => _swapImages(index, index + 1)
                      : null,
                  icon: const Icon(Icons.arrow_downward),
                  tooltip: 'Move Down',
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
