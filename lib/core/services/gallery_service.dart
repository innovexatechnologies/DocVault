import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class GalleryService {
  final ImagePicker _imagePicker = ImagePicker();

  /// Pick multiple images from the device gallery.
  Future<List<String>> pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 90,
      );
      debugPrint('MULTIPLE PICKER RETURNED: ${images.length} images');

      if (images.isEmpty) {
        return [];
      }

      return images
          .map((image) => image.path)
          .where((path) => path.isNotEmpty)
          .toList();
    } catch (e, stackTrace) {
      debugPrint('Gallery multiple image pick error: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Pick one image from gallery.
  Future<String?> pickSingleImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      return image?.path;
    } catch (e, stackTrace) {
      debugPrint('Single image pick error: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Capture one image using camera.
  Future<String?> takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      return image?.path;
    } catch (e, stackTrace) {
      debugPrint('Camera image pick error: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}