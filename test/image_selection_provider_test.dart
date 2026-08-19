import 'package:doc_vault/core/providers/image_selection_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageSelectionProvider reorder logic', () {
    test('reorders items when moving down', () {
      final provider = ImageSelectionProvider();
      provider.addImages(['a.png', 'b.png', 'c.png'], 'gallery');

      provider.reorderImages(0, 2);

      expect(provider.selectedImages.map((e) => e.filePath).toList(), [
        'b.png',
        'a.png',
        'c.png',
      ]);
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

    test('ignores invalid reorder indexes', () {
      final provider = ImageSelectionProvider();
      provider.addImages(['a.png', 'b.png'], 'gallery');

      provider.reorderImages(-1, 1);
      provider.reorderImages(0, 99);

      expect(provider.selectedImages.map((e) => e.filePath).toList(), [
        'a.png',
        'b.png',
      ]);
    });
  });
}
