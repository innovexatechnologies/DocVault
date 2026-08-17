import 'package:doc_vault/core/providers/image_selection_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageSelectionProvider reorder logic', () {
    test('reorders items without crashing when moving down', () {
      final provider = ImageSelectionProvider();
      provider.addImages(['a.png', 'b.png', 'c.png'], 'gallery');

      provider.reorderImages(0, 2);

      expect(provider.selectedImages.map((e) => e.filePath).toList(), [
        'b.png',
        'a.png',
        'c.png',
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
