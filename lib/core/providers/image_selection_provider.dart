import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/image_item.dart';

class ImageSelectionProvider extends ChangeNotifier {
  final List<ImageItem> _selectedImages = [];
  bool _hasUnsavedChanges = false;

  List<ImageItem> get selectedImages => List.unmodifiable(_selectedImages);
  int get imageCount => _selectedImages.length;
  bool get hasImages => _selectedImages.isNotEmpty;
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  void setUnsavedChanges(bool value) {
    if (_hasUnsavedChanges != value) {
      _hasUnsavedChanges = value;
      notifyListeners();
    }
  }

  void addImages(List<String> filePaths, String source) {
    const uuid = Uuid();
    for (final filePath in filePaths) {
      final imageItem = ImageItem(
        id: uuid.v4(),
        filePath: filePath,
        capturedAt: DateTime.now(),
        source: source,
      );
      _selectedImages.add(imageItem);
    }
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void updateImageFilePath(String imageId, String newFilePath) {
    final index = _selectedImages.indexWhere((image) => image.id == imageId);
    if (index != -1) {
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
  }

  void replaceImages(List<ImageItem> items) {
    _selectedImages
      ..clear()
      ..addAll(items);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void removeImage(String imageId) {
    _selectedImages.removeWhere((image) => image.id == imageId);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void reorderImages(int oldIndex, int newIndex) {
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

    final reorderedItems = List<ImageItem>.from(_selectedImages);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = reorderedItems.removeAt(oldIndex);
    reorderedItems.insert(newIndex, item);

    _selectedImages
      ..clear()
      ..addAll(reorderedItems);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void swapImages(int indexA, int indexB) {
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

  void clearAllImages() {
    _selectedImages.clear();
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  List<String> getImageFilePaths() {
    return _selectedImages.map((image) => image.filePath).toList();
  }
}
