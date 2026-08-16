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
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final image = _selectedImages.removeAt(oldIndex);
    _selectedImages.insert(newIndex, image);
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
