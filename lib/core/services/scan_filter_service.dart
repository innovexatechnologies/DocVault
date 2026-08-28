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
  /// Finds a document that contrasts with the outer photo border and crops to
  /// its bounds. If no reliable boundary is found, the original bytes return.
  static Uint8List autoCrop(Uint8List inputBytes) {
    final image = img.decodeImage(inputBytes);
    if (image == null) {
      throw ArgumentError('Could not decode image bytes.');
    }

    if (image.width < 20 || image.height < 20) {
      return inputBytes;
    }

    final borderSamples = <double>[];
    final sampleStep = ((image.width + image.height) ~/ 200).clamp(1, 1000);

    for (var x = 0; x < image.width; x += sampleStep) {
      borderSamples.add(
        img.getLuminance(image.getPixel(x, 0)).toDouble(),
      );
      borderSamples.add(
        img
            .getLuminance(image.getPixel(x, image.height - 1))
            .toDouble(),
      );
    }
    for (var y = 0; y < image.height; y += sampleStep) {
      borderSamples.add(
        img.getLuminance(image.getPixel(0, y)).toDouble(),
      );
      borderSamples.add(
        img
            .getLuminance(image.getPixel(image.width - 1, y))
            .toDouble(),
      );
    }

    final borderLuminance =
        borderSamples.reduce((a, b) => a + b) / borderSamples.length;
    final borderIsDark = borderLuminance < 128;
    final threshold = 35.0;

    var left = image.width;
    var top = image.height;
    var right = -1;
    var bottom = -1;

    for (var y = 0; y < image.height; y += sampleStep) {
      for (var x = 0; x < image.width; x += sampleStep) {
        final luminance = img.getLuminance(image.getPixel(x, y));
        final isDocumentPixel = borderIsDark
            ? luminance > borderLuminance + threshold
            : luminance < borderLuminance - threshold;

        if (isDocumentPixel) {
          left = x < left ? x : left;
          top = y < top ? y : top;
          right = x > right ? x : right;
          bottom = y > bottom ? y : bottom;
        }
      }
    }

    if (right < 0 || bottom < 0) {
      return inputBytes;
    }

    final detectedWidth = right - left + sampleStep;
    final detectedHeight = bottom - top + sampleStep;
    final detectedArea = detectedWidth * detectedHeight;
    final imageArea = image.width * image.height;

    if (detectedArea < imageArea * 0.20 ||
        detectedWidth > image.width * 0.98 &&
            detectedHeight > image.height * 0.98) {
      return inputBytes;
    }

    final paddingX = (image.width * 0.015).round();
    final paddingY = (image.height * 0.015).round();
    final cropX = (left - paddingX).clamp(0, image.width - 1);
    final cropY = (top - paddingY).clamp(0, image.height - 1);
    final cropRight = (right + paddingX).clamp(1, image.width);
    final cropBottom = (bottom + paddingY).clamp(1, image.height);
    final cropped = img.copyCrop(
      image,
      x: cropX,
      y: cropY,
      width: cropRight - cropX,
      height: cropBottom - cropY,
    );

    return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
  }

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
