import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class GalleryService {
  final ImagePicker _imagePicker = ImagePicker();

  /// Pick multiple images from the device gallery.
  ///
  /// This is used when creating a PDF/DOCX/PPTX from
  /// multiple gallery images.
  Future<List<String>> pickImages() async {
    try {
      debugPrint('OPENING MULTIPLE IMAGE PICKER...');

      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 90,
      );

      debugPrint(
        'MULTIPLE IMAGE PICKER RETURNED: ${images.length} IMAGES',
      );

      if (images.isEmpty) {
        debugPrint('USER CANCELLED GALLERY OR NO IMAGES SELECTED.');
        return [];
      }

      final List<String> imagePaths = images
          .map((image) => image.path)
          .where((path) => path.isNotEmpty)
          .toList();

      debugPrint(
        'VALID IMAGE PATHS RETURNED: ${imagePaths.length}',
      );

      for (int i = 0; i < imagePaths.length; i++) {
        debugPrint('IMAGE ${i + 1}: ${imagePaths[i]}');
      }

      return imagePaths;
    } catch (e, stackTrace) {
      debugPrint('GALLERY MULTIPLE IMAGE PICK ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Pick one image from gallery.
  ///
  /// This method is kept for places where only one image
  /// is required. Do NOT use this method for Create PDF.
  Future<String?> pickSingleImage() async {
    try {
      debugPrint('OPENING SINGLE IMAGE PICKER...');

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) {
        debugPrint('USER CANCELLED SINGLE IMAGE PICKER.');
        return null;
      }

      debugPrint('SINGLE IMAGE SELECTED: ${image.path}');

      return image.path;
    } catch (e, stackTrace) {
      debugPrint('SINGLE IMAGE PICK ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Capture one image using the device camera.
  Future<String?> takePhoto() async {
    try {
      debugPrint('OPENING CAMERA...');

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (image == null) {
        debugPrint('USER CANCELLED CAMERA.');
        return null;
      }

      debugPrint('CAMERA IMAGE CAPTURED: ${image.path}');

      return image.path;
    } catch (e, stackTrace) {
      debugPrint('CAMERA IMAGE PICK ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}