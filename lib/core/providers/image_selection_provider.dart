import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/image_item.dart';

class ImageSelectionProvider extends ChangeNotifier {
  final List<ImageItem> _selectedImages = [];

  bool _hasUnsavedChanges = false;

  // ==============================================================
  // GETTERS
  // ==============================================================

  List<ImageItem> get selectedImages =>
      List.unmodifiable(_selectedImages);

  int get imageCount => _selectedImages.length;

  bool get hasImages => _selectedImages.isNotEmpty;

  bool get hasUnsavedChanges => _hasUnsavedChanges;

  // ==============================================================
  // UNSAVED CHANGES
  // ==============================================================

  void setUnsavedChanges(bool value) {
    if (_hasUnsavedChanges != value) {
      _hasUnsavedChanges = value;
      notifyListeners();
    }
  }

  // ==============================================================
  // START NEW SELECTION
  // ==============================================================
  //
  // IMPORTANT:
  //
  // Call this when the user starts a NEW PDF/DOCX/PPTX conversion.
  //
  // This removes images from the previous conversion so they cannot
  // appear in the new conversion.
  //

  void startNewSelection() {
    _selectedImages.clear();
    _hasUnsavedChanges = false;

    notifyListeners();
  }

  // ==============================================================
  // ADD IMAGES
  // ==============================================================
  //
  // This method adds images without creating duplicates.
  //
  // If the same file path already exists, it will NOT be added again.
  //

  void addImages(
    List<String> filePaths,
    String source, {
    bool markUnsaved = false,
  }) {
    if (filePaths.isEmpty) {
      return;
    }

    const uuid = Uuid();

    bool changed = false;

    for (final filePath in filePaths) {
      if (filePath.trim().isEmpty) {
        continue;
      }

      // ------------------------------------------------------------
      // Prevent duplicate image paths.
      // ------------------------------------------------------------

      final alreadyExists = _selectedImages.any(
        (image) => image.filePath == filePath,
      );

      if (alreadyExists) {
        continue;
      }

      final imageItem = ImageItem(
        id: uuid.v4(),
        filePath: filePath,
        capturedAt: DateTime.now(),
        source: source,
      );

      _selectedImages.add(imageItem);

      changed = true;
    }

    if (markUnsaved && changed) {
      _hasUnsavedChanges = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  // ==============================================================
  // REPLACE IMAGES
  // ==============================================================
  //
  // Completely replaces current selection.
  //
  // Useful when image picker returns the complete current selection.
  //

  void replaceImages(List<ImageItem> items) {
    _selectedImages
      ..clear()
      ..addAll(items);

    _hasUnsavedChanges = true;

    notifyListeners();
  }

  // ==============================================================
  // REPLACE IMAGES FROM FILE PATHS
  // ==============================================================
  //
  // Use this when starting a new selection from the image picker.
  //
  // Existing images are removed first.
  //

  void replaceImagesFromPaths(
    List<String> filePaths,
    String source, {
    bool markUnsaved = true,
  }) {
    const uuid = Uuid();

    final newImages = <ImageItem>[];

    final uniquePaths = <String>{};

    for (final filePath in filePaths) {
      if (filePath.trim().isEmpty) {
        continue;
      }

      // Prevent duplicate paths in the same selection.
      if (!uniquePaths.add(filePath)) {
        continue;
      }

      newImages.add(
        ImageItem(
          id: uuid.v4(),
          filePath: filePath,
          capturedAt: DateTime.now(),
          source: source,
        ),
      );
    }

    _selectedImages
      ..clear()
      ..addAll(newImages);

    _hasUnsavedChanges = markUnsaved;

    notifyListeners();
  }

  // ==============================================================
  // UPDATE IMAGE FILE PATH
  // ==============================================================

  void updateImageFilePath(
    String imageId,
    String newFilePath,
  ) {
    final index = _selectedImages.indexWhere(
      (image) => image.id == imageId,
    );

    if (index == -1) {
      return;
    }

    // ------------------------------------------------------------
    // Prevent changing to a path that already exists.
    // ------------------------------------------------------------

    final duplicateExists = _selectedImages.any(
      (image) =>
          image.id != imageId &&
          image.filePath == newFilePath,
    );

    if (duplicateExists) {
      return;
    }

    final old = _selectedImages[index];

    _selectedImages[index] = ImageItem(
      id: old.id,
      filePath: newFilePath,
      capturedAt: old.capturedAt,
      source: old.source,
    );

    _hasUnsavedChanges = true;

    notifyListeners();
  }

  // ==============================================================
  // REMOVE IMAGE
  // ==============================================================

  void removeImage(String imageId) {
    final oldLength = _selectedImages.length;

    _selectedImages.removeWhere(
      (image) => image.id == imageId,
    );

    if (_selectedImages.length != oldLength) {
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  // ==============================================================
  // REORDER IMAGES
  // ==============================================================

  void reorderImages(
    int oldIndex,
    int newIndex,
  ) {
    if (_selectedImages.length < 2) {
      return;
    }

    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _selectedImages.length ||
        newIndex > _selectedImages.length) {
      return;
    }

    if (oldIndex == newIndex) {
      return;
    }

    final reorderedItems =
        List<ImageItem>.from(_selectedImages);

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item =
        reorderedItems.removeAt(oldIndex);

    reorderedItems.insert(
      newIndex,
      item,
    );

    _selectedImages
      ..clear()
      ..addAll(reorderedItems);

    _hasUnsavedChanges = true;

    notifyListeners();
  }

  // ==============================================================
  // SWAP IMAGES
  // ==============================================================

  void swapImages(
    int indexA,
    int indexB,
  ) {
    if (indexA < 0 ||
        indexB < 0 ||
        indexA >= _selectedImages.length ||
        indexB >= _selectedImages.length ||
        indexA == indexB) {
      return;
    }

    final temp = _selectedImages[indexA];

    _selectedImages[indexA] =
        _selectedImages[indexB];

    _selectedImages[indexB] = temp;

    _hasUnsavedChanges = true;

    notifyListeners();
  }

  // ==============================================================
  // CLEAR ALL IMAGES
  // ==============================================================

  void clearAllImages() {
    if (_selectedImages.isEmpty &&
        !_hasUnsavedChanges) {
      return;
    }

    _selectedImages.clear();

    _hasUnsavedChanges = false;

    notifyListeners();
  }

  // ==============================================================
  // GET IMAGE FILE PATHS
  // ==============================================================

  List<String> getImageFilePaths() {
    return _selectedImages
        .map((image) => image.filePath)
        .toList();
  }
}