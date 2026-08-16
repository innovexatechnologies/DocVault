import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class GalleryService {
  final _imagePicker = ImagePicker();

  Future<List<String>> pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 90);

      return images.map((image) => image.path).toList();
    } catch (e) {
      debugPrint('Gallery pick error: $e');
      rethrow;
    }
  }

  Future<String?> pickSingleImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      return image?.path;
    } catch (e) {
      debugPrint('Single image pick error: $e');
      rethrow;
    }
  }
}
