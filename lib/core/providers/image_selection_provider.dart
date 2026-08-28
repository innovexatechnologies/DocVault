 import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/image_item.dart';

class ImageSelectionProvider extends ChangeNotifier {
  final List<ImageItem> _selectedImages = [];

  bool _hasUnsavedChanges = false;

  static const Uuid _uuid = Uuid();

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
    if (_hasUnsavedChanges == value) {
      return;
    }

    _hasUnsavedChanges = value;
    notifyListeners();
  }

  // ==============================================================
  // START NEW FILE / NEW CONVERSION
  // ==============================================================
  //
  // IMPORTANT:
  // Call this BEFORE selecting images for a NEW PDF/DOCX/PPTX.
  //
  // This completely removes images from the previous file.
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
  // Adds images to the CURRENT selection.
  //
  // Duplicate file paths are automatically ignored.
  //
  

  void addImages(
    List<String> filePaths,
    String source, {
    bool markUnsaved = true,
  }) {
    if (filePaths.isEmpty) {
      return;
    }

    bool changed = false;

    for (final rawPath in filePaths) {
      final filePath = rawPath.trim();

      if (filePath.isEmpty) {
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

      _selectedImages.add(
        ImageItem(
          id: _uuid.v4(),
          filePath: filePath,
          capturedAt: DateTime.now(),
          source: source,
        ),
      );

      changed = true;
    }

    if (!changed) {
      return;
    }

    if (markUnsaved) {
      _hasUnsavedChanges = true;
    }

    notifyListeners();
  }

  // ==============================================================
  // REPLACE CURRENT SELECTION
  // ==============================================================
  //
  // Use this when the picker returns the COMPLETE selection.
  //
  // Old images are removed.
  //

  void replaceImages(
    List<ImageItem> items, {
    bool markUnsaved = true,
  }) {
    final uniquePaths = <String>{};
    final newImages = <ImageItem>[];

    for (final image in items) {
      final path = image.filePath.trim();

      if (path.isEmpty) {
        continue;
      }

      if (!uniquePaths.add(path)) {
        continue;
      }

      newImages.add(image);
    }

    _selectedImages
      ..clear()
      ..addAll(newImages);

    _hasUnsavedChanges = markUnsaved;

    notifyListeners();
  }

  // ==============================================================
  // REPLACE IMAGES FROM FILE PATHS
  // ==============================================================
  //
  // IMPORTANT:
  // Use this when selecting images for a NEW/COMPLETE file.
  //
  // It ALWAYS replaces the old selection.
  //

  void replaceImagesFromPaths(
    List<String> filePaths,
    String source, {
    bool markUnsaved = true,
  }) {
    final uniquePaths = <String>{};
    final newImages = <ImageItem>[];

    for (final rawPath in filePaths) {
      final filePath = rawPath.trim();

      if (filePath.isEmpty) {
        continue;
      }

      // Prevent duplicates inside the new selection.
      if (!uniquePaths.add(filePath)) {
        continue;
      }

      newImages.add(
        ImageItem(
          id: _uuid.v4(),
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
    final path = newFilePath.trim();

    if (path.isEmpty) {
      return;
    }

    final index = _selectedImages.indexWhere(
      (image) => image.id == imageId,
    );

    if (index == -1) {
      return;
    }

    // Prevent duplicate paths.
    final duplicateExists = _selectedImages.any(
      (image) =>
          image.id != imageId &&
          image.filePath == path,
    );

    if (duplicateExists) {
      return;
    }

    final oldImage = _selectedImages[index];

    _selectedImages[index] = ImageItem(
      id: oldImage.id,
      filePath: path,
      capturedAt: oldImage.capturedAt,
      source: oldImage.source,
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

    if (_selectedImages.length == oldLength) {
      return;
    }

    _hasUnsavedChanges = true;

    notifyListeners();
  }

  // ==============================================================
  // REMOVE IMAGE BY FILE PATH
  // ==============================================================

  void removeImageByPath(String filePath) {
    final oldLength = _selectedImages.length;

    _selectedImages.removeWhere(
      (image) => image.filePath == filePath,
    );

    if (_selectedImages.length == oldLength) {
      return;
    }

    _hasUnsavedChanges = true;

    notifyListeners();
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
        oldIndex >= _selectedImages.length ||
        newIndex < 0 ||
        newIndex > _selectedImages.length) {
      return;
    }

    if (oldIndex == newIndex) {
      return;
    }

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = _selectedImages.removeAt(oldIndex);

    _selectedImages.insert(
      newIndex,
      item,
    );

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

    _selectedImages[indexA] = _selectedImages[indexB];
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
    return List<String>.from(
      _selectedImages.map(
        (image) => image.filePath,
      ),
    );
  }

  // ==============================================================
  // CHECK IF IMAGE EXISTS
  // ==============================================================

  bool containsImage(String filePath) {
    return _selectedImages.any(
      (image) => image.filePath == filePath,
    );
  }

  // ==============================================================
  // RESET PROVIDER
  // ==============================================================

  void reset() {
    _selectedImages.clear();
    _hasUnsavedChanges = false;

    notifyListeners();
  }
}
 
