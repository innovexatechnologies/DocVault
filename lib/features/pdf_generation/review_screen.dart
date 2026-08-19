import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../core/providers/pdf_manager_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/image_selection_provider.dart';
import '../../core/services/gallery_service.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/widgets/unsaved_changes_dialog.dart';
import '../../models/conversion_type.dart';
import '../../models/pdf_document.dart';
import '../image_editing/image_editor_screen.dart';
import 'pdf_generation_screen.dart';
import 'preview_screen.dart';

class ReviewScreen extends StatefulWidget {
  final PdfDocument? existingDocument;
  final ConversionType conversionType;

  const ReviewScreen({
    super.key,
    this.existingDocument,
    this.conversionType = ConversionType.pdf,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _isReordering = false;
  bool _isSaving = false;

  ConversionType get _effectiveType =>
      widget.existingDocument?.documentType ?? widget.conversionType;

  bool get _isEditingExisting => widget.existingDocument != null;

  void _toggleReorderMode() {
    setState(() {
      _isReordering = !_isReordering;
    });
  }

  void _removeImage(String imageId) {
    context.read<ImageSelectionProvider>().removeImage(imageId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _effectiveType == ConversionType.ppt ? 'Slide removed' : 'Page removed',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _reorderImages(int oldIndex, int newIndex) {
    context.read<ImageSelectionProvider>().reorderImages(oldIndex, newIndex);
  }

  Future<void> _addMoreImages(String source) async {
    if (source == 'camera') {
      if (mounted) {
        Navigator.of(context).pushNamed(
          '/camera',
          arguments: _effectiveType,
        );
      }
    } else {
      final galleryService = GalleryService();
      try {
        final imagePaths = await galleryService.pickImages();
        if (imagePaths.isNotEmpty && mounted) {
          context.read<ImageSelectionProvider>().addImages(
                imagePaths,
                'gallery',
                markUnsaved: true,
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added ${imagePaths.length} ${_effectiveType == ConversionType.ppt ? 'slide(s)' : 'page(s)'}',
              ),
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

  void _showAddImagesBottomSheet() {
    final itemLabel = _effectiveType == ConversionType.ppt ? 'Slides' : 'Pages';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isEditingExisting
                      ? 'Add $itemLabel to Document'
                      : 'Add More $itemLabel',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _addMoreImages('camera');
                        },
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Camera'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _addMoreImages('gallery');
                        },
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _effectiveType.badgeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openImageEditor(String imageId, String imagePath, int index) async {
    final updatedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ImageEditorScreen(
          imageId: imageId,
          imagePath: imagePath,
          pageIndex: index,
        ),
      ),
    );

    if (updatedPath != null && mounted) {
      setState(() {});
    }
  }

  void _openPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          existingDocument: widget.existingDocument,
          conversionType: _effectiveType,
          onSave: _isEditingExisting ? _saveExistingDocumentChanges : null,
        ),
      ),
    );
  }

  Future<void> _saveExistingDocumentChanges() async {
    final imagePaths = context.read<ImageSelectionProvider>().getImageFilePaths();
    if (imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot save empty document. At least 1 ${_effectiveType == ConversionType.ppt ? 'slide' : 'page'} is required.',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await context.read<PdfManagerProvider>().updateDocumentContent(
            widget.existingDocument!.id,
            imagePaths,
          );

      if (!mounted) return;
      context.read<ImageSelectionProvider>().clearAllImages();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_effectiveType.shortName} updated successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save changes: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _generateDocument() {
    if (_isEditingExisting) {
      _saveExistingDocumentChanges();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfGenerationScreen(conversionType: _effectiveType),
        ),
      );
    }
  }

  Future<void> _handleBack() async {
    if (_isReordering) {
      setState(() => _isReordering = false);
      return;
    }

    final hasUnsaved = context.read<ImageSelectionProvider>().hasUnsavedChanges;
    if (!hasUnsaved) {
      context.read<ImageSelectionProvider>().clearAllImages();
      Navigator.of(context).pop();
      return;
    }

    final action = await UnsavedChangesDialog.show(
      context,
      title: 'Discard Changes?',
      message: _isEditingExisting
          ? 'You have unsaved changes to "${widget.existingDocument!.fileName}". What would you like to do?'
          : 'You have unsaved changes. What would you like to do?',
      saveLabel: _isEditingExisting
          ? 'Save Changes'
          : 'Generate ${_effectiveType.shortName}',
      discardLabel: 'Discard Changes',
    );

    if (!mounted) return;

    if (action == UnsavedChangesAction.save) {
      _generateDocument();
    } else if (action == UnsavedChangesAction.discard) {
      context.read<ImageSelectionProvider>().clearAllImages();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final itemUnit = _effectiveType == ConversionType.ppt ? 'slides' : 'pages';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: _handleBack,
          ),
          title: Text(
            _isEditingExisting
                ? widget.existingDocument!.title
                : 'Review & Organize (${_effectiveType.shortName})',
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.preview_rounded),
              tooltip: 'Preview Document',
              onPressed: _openPreview,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _effectiveType.badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${context.watch<ImageSelectionProvider>().imageCount} $itemUnit',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: _effectiveType.badgeColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Consumer<ImageSelectionProvider>(
              builder: (context, imageProvider, _) {
                if (!imageProvider.hasImages) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 60,
                          color: colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No images in document',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddImagesBottomSheet,
                          icon: const Icon(Icons.add_photo_alternate_rounded),
                          label: Text('Add $itemLabel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _effectiveType.badgeColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Image Grid or Reorderable List
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
                                final imageItem = imageProvider.selectedImages[index];
                                return _buildReorderableRowItem(imageItem, index);
                              },
                            )
                          : GridView.builder(
                              padding: EdgeInsets.all(
                                ResponsiveHelper.getGridSpacing(context),
                              ),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: ResponsiveHelper.getGridCrossAxisCount(context),
                                crossAxisSpacing: ResponsiveHelper.getGridSpacing(context),
                                mainAxisSpacing: ResponsiveHelper.getGridSpacing(context),
                                childAspectRatio: _effectiveType == ConversionType.ppt ? 1.15 : 0.82,
                              ),
                              itemCount: imageProvider.selectedImages.length,
                              itemBuilder: (context, index) {
                                final imageItem = imageProvider.selectedImages[index];
                                return _buildImageItem(imageItem, index);
                              },
                            ),
                    ),

                    // Bottom Control Toolbar & Generate Button
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: EdgeInsets.all(
                          ResponsiveHelper.getResponsivePadding(context),
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                          border: Border(
                            top: BorderSide(
                              color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Action buttons row: Add Images, Reorder, Preview
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _showAddImagesBottomSheet,
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('Add'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _toggleReorderMode,
                                    icon: Icon(
                                      _isReordering
                                          ? Icons.check_rounded
                                          : Icons.swap_vert_rounded,
                                      size: 18,
                                    ),
                                    label: Text(_isReordering ? 'Done' : 'Reorder'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      backgroundColor: _isReordering
                                          ? _effectiveType.badgeColor.withValues(alpha: 0.15)
                                          : null,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _openPreview,
                                    icon: const Icon(Icons.preview_rounded, size: 18),
                                    label: const Text('Preview'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Primary Action Button (Save Changes or Generate Format)
                            SizedBox(
                              width: double.infinity,
                              height: ResponsiveHelper.getResponsiveButtonHeight(context),
                              child: ElevatedButton.icon(
                                onPressed: _generateDocument,
                                icon: Icon(
                                  _isEditingExisting
                                      ? Icons.save_rounded
                                      : _effectiveType.icon,
                                ),
                                label: Text(
                                  _isEditingExisting
                                      ? 'Save Changes'
                                      : 'Generate ${_effectiveType.shortName}',
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                                      context,
                                      mobileSize: 14,
                                      tabletSize: 16,
                                      desktopSize: 18,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isEditingExisting
                                      ? AppTheme.primaryColor
                                      : _effectiveType.badgeColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_isSaving)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primaryColor),
                          SizedBox(height: 16),
                          Text(
                            'Saving document changes...',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get itemLabel => _effectiveType == ConversionType.ppt ? 'Slides' : 'Pages';

  Widget _buildImageItem(dynamic imageItem, int index) {
    final itemUnit = _effectiveType == ConversionType.ppt ? 'Slide' : '';
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => _openImageEditor(imageItem.id, imageItem.filePath, index),
            child: Image.file(
              File(imageItem.filePath),
              fit: BoxFit.cover,
              cacheWidth: 220,
              cacheHeight: 220,
              filterQuality: FilterQuality.medium,
            ),
          ),
          // Page/Slide Number Badge
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _effectiveType.badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                itemUnit.isNotEmpty ? '$itemUnit ${index + 1}' : '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // Delete Button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _removeImage(imageItem.id),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: AppTheme.errorColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 15),
              ),
            ),
          ),
          // Edit Button
          Positioned(
            bottom: 8,
            left: 8,
            child: GestureDetector(
              onTap: () => _openImageEditor(imageItem.id, imageItem.filePath, index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Source Badge
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.50),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    imageItem.source == 'camera'
                        ? Icons.camera_alt_rounded
                        : Icons.photo_library_rounded,
                    size: 11,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    imageItem.source == 'camera' ? 'Cam' : 'Gal',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableRowItem(dynamic imageItem, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemLabel = _effectiveType == ConversionType.ppt ? 'Slide' : 'Page';

    return Card(
      key: ValueKey(imageItem.id),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imageItem.filePath),
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            cacheWidth: 96,
            cacheHeight: 96,
          ),
        ),
        title: Text(
          '$itemLabel ${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          imageItem.source == 'camera' ? 'Camera' : 'Gallery',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.tune_rounded, size: 20),
              tooltip: 'Edit $itemLabel',
              onPressed: () => _openImageEditor(imageItem.id, imageItem.filePath, index),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.errorColor),
              tooltip: 'Delete $itemLabel',
              onPressed: () => _removeImage(imageItem.id),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.drag_handle_rounded, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
