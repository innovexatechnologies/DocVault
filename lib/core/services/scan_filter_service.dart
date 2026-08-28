// scan_filter_service.dart
//
// Drop this file into your Flutter project's lib/ folder (e.g. lib/services/).
//
// 1) Add the dependency to pubspec.yaml:
//
//    dependencies:
//      image: ^4.2.0
//
// 2) Run: flutter pub get
//
// 3) Use ScanFilterService.apply(filter, imageBytes) wherever you process
//    a scanned photo (right after capture/crop, before saving/exporting).

import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// The set of filters available after scanning a document,
/// similar to CamScanner's "Magic Color / B&W / Gray / Original" options.
enum ScanFilter {
  original,
  grayscale,
  blackAndWhite, // high-contrast, best for text documents
  enhance,       // "magic color" — boosts contrast/brightness, keeps color
  sharpen,
}

class ScanFilterService {
  /// Applies [filter] to raw image bytes (jpg/png) and returns new bytes
  /// encoded as JPEG (quality 92). Runs synchronously — for large images,
  /// call this inside `compute()` to avoid jank on the UI thread (example below).
  static Uint8List apply(ScanFilter filter, Uint8List inputBytes) {
    img.Image? image = img.decodeImage(inputBytes);
    if (image == null) {
      throw ArgumentError('Could not decode image bytes.');
    }

    switch (filter) {
      case ScanFilter.original:
        break; // no-op

      case ScanFilter.grayscale:
        image = img.grayscale(image);
        break;

      case ScanFilter.blackAndWhite:
        image = _applyBlackAndWhite(image);
        break;

      case ScanFilter.enhance:
        image = _applyEnhance(image);
        break;

      case ScanFilter.sharpen:
        image = img.convolution(
          image,
          filter: [
            0, -1, 0,
            -1, 5, -1,
            0, -1, 0,
          ],
        );
        break;
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  /// Black & white "document mode": grayscale + strong contrast boost +
  /// adaptive-ish threshold, so text becomes crisp black on white.
  static img.Image _applyBlackAndWhite(img.Image image) {
    img.Image result = img.grayscale(image);

    // Boost contrast heavily so background flattens to white/black.
    result = img.adjustColor(
      result,
      contrast: 1.9,
      brightness: 1.05,
    );

    // Simple global threshold pass (tweak 140 to taste, 0-255).
    const threshold = 140;
    for (final pixel in result) {
      final luminance = img.getLuminance(pixel);
      final value = luminance > threshold ? 255 : 0;
      pixel
        ..r = value
        ..g = value
        ..b = value;
    }

    return result;
  }

  /// "Enhance / Magic Color": keeps the document in color but makes
  /// whites whiter and text darker — good general-purpose default filter.
  static img.Image _applyEnhance(img.Image image) {
    img.Image result = img.adjustColor(
      image,
      contrast: 1.35,
      brightness: 1.08,
      saturation: 1.15,
    );
    result = img.gaussianBlur(result, radius: 0); // no-op placeholder for future denoise step
    return result;
  }

  /// Human-readable labels for a filter picker UI.
  static String label(ScanFilter filter) {
    switch (filter) {
      case ScanFilter.original:
        return 'Original';
      case ScanFilter.grayscale:
        return 'Gray';
      case ScanFilter.blackAndWhite:
        return 'B&W';
      case ScanFilter.enhance:
        return 'Enhance';
      case ScanFilter.sharpen:
        return 'Sharpen';
    }
  }
}
