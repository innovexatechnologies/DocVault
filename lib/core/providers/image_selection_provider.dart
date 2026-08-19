import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/image_item.dart';

class ImageSelectionProvider extends ChangeNotifier {
  final List<ImageItem> _selectedImages = [];

  List<ImageItem> get selectedImages => List.unmodifiable(_selectedImages);
  int get imageCount => _selectedImages.length;
  bool get hasImages => _selectedImages.isNotEmpty;

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
    notifyListeners();
  }

  void removeImage(String imageId) {
    _selectedImages.removeWhere((image) => image.id == imageId);
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
    notifyListeners();
  }

  void clearAllImages() {
    _selectedImages.clear();
    notifyListeners();
  }

  List<String> getImageFilePaths() {
    return _selectedImages.map((image) => image.filePath).toList();
  }
}
