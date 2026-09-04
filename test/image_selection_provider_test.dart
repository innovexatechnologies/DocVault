import 'package:doc_vault/core/providers/image_selection_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageSelectionProvider reorder logic', () {
    test('initial addImages does not mark unsaved changes', () {
      final provider = ImageSelectionProvider();
      provider.addImages(['a.png', 'b.png'], 'gallery', markUnsaved: false);

      expect(provider.hasImages, isTrue);
      expect(provider.hasUnsavedChanges, isFalse);
    });

    test('reorders items when moving down and marks unsaved', () {
      final provider = ImageSelectionProvider();
      provider.addImages(['a.png', 'b.png', 'c.png'], 'gallery');

      provider.reorderImages(0, 2);

      expect(provider.selectedImages.map((e) => e.filePath).toList(), [
        'b.png',
        'a.png',
        'c.png',
      ]);
      expect(provider.hasUnsavedChanges, isTrue);
    });

    test('reorders items when moving to end of list', () {
      final provider = ImageSelectionProvider();
      provider.addImages(['a.png', 'b.png', 'c.png'], 'gallery');

      provider.reorderImages(0, 3);

      expect(provider.selectedImages.map((e) => e.filePath).toList(), [
        'b.png',
        'c.png',
        'a.png',
      ]);
    });

    test('reorders items when moving up', () {
      final provider = ImageSelectionProvider();
      provider.addImages(['a.png', 'b.png', 'c.png'], 'gallery');

      provider.reorderImages(2, 0);

      expect(provider.selectedImages.map((e) => e.filePath).toList(), [
        'c.png',
        'a.png',
        'b.png',
      ]);
    });

    test('swaps items correctly with swapImages', () {
      final provider = ImageSelectionProvider();
      provider.addImages(['a.png', 'b.png', 'c.png'], 'gallery');

      provider.swapImages(0, 1);
      expect(provider.selectedImages.map((e) => e.filePath).toList(), [
        'b.png',
        'a.png',
        'c.png',
      ]);

      provider.swapImages(1, 2);
      expect(provider.selectedImages.map((e) => e.filePath).toList(), [
        'b.png',
        'c.png',
        'a.png',
      ]);
    });

    test('updates image file path on edit and marks unsaved', () {
      final provider = ImageSelectionProvider();
      provider.addImages(['a.png', 'b.png'], 'gallery');

      final firstId = provider.selectedImages.first.id;
      provider.updateImageFilePath(firstId, 'a_edited.jpg');

      expect(provider.selectedImages.first.filePath, 'a_edited.jpg');
      expect(provider.hasUnsavedChanges, isTrue);
    });

    test('clearAllImages resets unsaved changes', () {
      final provider = ImageSelectionProvider();
      provider.addImages(['a.png'], 'camera', markUnsaved: true);
      expect(provider.hasUnsavedChanges, isTrue);

      provider.clearAllImages();
      expect(provider.hasImages, isFalse);
      expect(provider.hasUnsavedChanges, isFalse);
    });
  });
}
