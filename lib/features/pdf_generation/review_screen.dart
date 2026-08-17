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
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(
          title: const Text(AppConstants.review),
          backgroundColor: AppTheme.bgWhite,
          foregroundColor: AppTheme.textPrimary,
          elevation: 1,
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
                      ? ListView.builder(
                          padding: EdgeInsets.all(
                            ResponsiveHelper.getGridSpacing(context),
                          ),
                          itemCount: imageProvider.selectedImages.length,
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
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _addMoreImages('camera'),
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Camera'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _addMoreImages('gallery'),
                                    icon: const Icon(Icons.image),
                                    label: const Text('Gallery'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentColor,
                                    ),
                                  ),
                                ],
                              ),
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
            cacheWidth: 400,
            cacheHeight: 400,
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SizedBox(
                    height: 180,
                    child: Image.file(
                      File(imageItem.filePath),
                      fit: BoxFit.cover,
                      cacheWidth: 500,
                      cacheHeight: 500,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
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
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: canMoveUp
                    ? () => _reorderImages(index, index - 1)
                    : null,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                onPressed: canMoveDown
                    ? () => _reorderImages(index, index + 1)
                    : null,
                icon: const Icon(Icons.arrow_downward),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
