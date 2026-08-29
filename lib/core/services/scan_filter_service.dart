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
import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// The set of filters available after scanning a document —
/// CamScanner / Adobe Scan style options, expanded to 20.
enum ScanFilter {
  original,
  grayscale,
  blackAndWhite,
  enhance,        // "magic color"
  sharpen,
  vivid,
  softLight,
  warmTone,
  coolTone,
  highContrastBW,
  softBW,
  sepia,
  noirDramatic,
  brightWhite,     // whiteboard / bright-paper mode
  lowLightBoost,
  matte,
  vintagePaper,
  coldSteel,
  magicColorPro,
  invertNegative,
  cleanDocument,   // denoise + sharpen + whitepoint (best default for text)
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
      borderSamples.add(img.getLuminance(image.getPixel(x, 0)).toDouble());
      borderSamples.add(
        img.getLuminance(image.getPixel(x, image.height - 1)).toDouble(),
      );
    }
    for (var y = 0; y < image.height; y += sampleStep) {
      borderSamples.add(img.getLuminance(image.getPixel(0, y)).toDouble());
      borderSamples.add(
        img.getLuminance(image.getPixel(image.width - 1, y)).toDouble(),
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
  /// call this inside `compute()` to avoid jank on the UI thread.
  static Uint8List apply(ScanFilter filter, Uint8List inputBytes) {
    img.Image? image = img.decodeImage(inputBytes);
    if (image == null) {
      throw ArgumentError('Could not decode image bytes.');
    }

    switch (filter) {
      case ScanFilter.original:
        break;

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
          filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
        );
        break;

      case ScanFilter.vivid:
        image = _applyVivid(image);
        break;

      case ScanFilter.softLight:
        image = _applySoftLight(image);
        break;

      case ScanFilter.warmTone:
        image = _applyWarmTone(image);
        break;

      case ScanFilter.coolTone:
        image = _applyCoolTone(image);
        break;

      case ScanFilter.highContrastBW:
        image = _applyHighContrastBW(image);
        break;

      case ScanFilter.softBW:
        image = _applySoftBW(image);
        break;

      case ScanFilter.sepia:
        image = _applySepia(image);
        break;

      case ScanFilter.noirDramatic:
        image = _applyNoirDramatic(image);
        break;

      case ScanFilter.brightWhite:
        image = _applyBrightWhite(image);
        break;

      case ScanFilter.lowLightBoost:
        image = _applyLowLightBoost(image);
        break;

      case ScanFilter.matte:
        image = _applyMatte(image);
        break;

      case ScanFilter.vintagePaper:
        image = _applyVintagePaper(image);
        break;

      case ScanFilter.coldSteel:
        image = _applyColdSteel(image);
        break;

      case ScanFilter.magicColorPro:
        image = _applyMagicColorPro(image);
        break;

      case ScanFilter.invertNegative:
        image = img.invert(image);
        break;

      case ScanFilter.cleanDocument:
        image = _applyCleanDocument(image);
        break;
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  // ---------------------------------------------------------------------
  // Individual filter implementations
  // ---------------------------------------------------------------------

  /// Black & white "document mode": grayscale + strong contrast boost +
  /// global threshold, so text becomes crisp black on white.
  static img.Image _applyBlackAndWhite(img.Image image) {
    img.Image result = img.grayscale(image);
    result = img.adjustColor(result, contrast: 1.9, brightness: 1.05);

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
    return result;
  }

  /// Punchy, saturated look — good for photos of colorful printed material
  /// (magazines, posters, marketing collateral).
  static img.Image _applyVivid(img.Image image) {
    img.Image result = img.adjustColor(
      image,
      contrast: 1.25,
      saturation: 1.5,
      brightness: 1.03,
    );
    result = img.convolution(
      result,
      filter: [0, -0.5, 0, -0.5, 3, -0.5, 0, -0.5, 0],
      div: 1,
    );
    return result;
  }

  /// Gentle, low-contrast pastel look — reduces harsh highlights, good for
  /// glossy paper that reflects light.
  static img.Image _applySoftLight(img.Image image) {
    img.Image result = img.adjustColor(
      image,
      contrast: 0.92,
      brightness: 1.1,
      saturation: 0.95,
    );
    result = img.gaussianBlur(result, radius: 1);
    return result;
  }

  /// Warm amber cast — mimics warm indoor lighting / old paper documents.
  static img.Image _applyWarmTone(img.Image image) {
    img.Image result = img.adjustColor(
      image,
      contrast: 1.1,
      brightness: 1.04,
      saturation: 1.05,
    );
    result = img.colorOffset(result, red: 18, green: 6, blue: -14);
    return result;
  }

  /// Cool blue-tinted cast — clean, modern, "scanned in an office" feel.
  static img.Image _applyCoolTone(img.Image image) {
    img.Image result = img.adjustColor(
      image,
      contrast: 1.1,
      brightness: 1.03,
      saturation: 1.0,
    );
    result = img.colorOffset(result, red: -12, green: -2, blue: 16);
    return result;
  }

  /// Very high contrast black & white — for faded receipts, low-ink prints,
  /// pencil notes.
  static img.Image _applyHighContrastBW(img.Image image) {
    img.Image result = img.grayscale(image);
    result = img.adjustColor(result, contrast: 2.4, brightness: 1.02);
    return result;
  }

  /// Grayscale with gentler contrast — keeps subtle shading (good for
  /// photos, sketches, diagrams inside a document).
  static img.Image _applySoftBW(img.Image image) {
    img.Image result = img.grayscale(image);
    result = img.adjustColor(result, contrast: 1.15, brightness: 1.05);
    return result;
  }

  /// Classic sepia tone — brown-toned monochrome, decorative/vintage look.
  static img.Image _applySepia(img.Image image) {
    img.Image result = img.grayscale(image);
    for (final pixel in result) {
      final l = img.getLuminance(pixel);
      pixel
        ..r = (l * 1.07).clamp(0, 255)
        ..g = (l * 0.86).clamp(0, 255)
        ..b = (l * 0.63).clamp(0, 255);
    }
    return result;
  }

  /// Dark, moody, heavily-contrasted monochrome — dramatic "film noir" look.
  static img.Image _applyNoirDramatic(img.Image image) {
    img.Image result = img.grayscale(image);
    result = img.adjustColor(result, contrast: 1.7, brightness: 0.85);
    result = img.vignette(result, start: 0.4, end: 1.1, color: img.ColorRgb8(0, 0, 0));
    return result;
  }

  /// Pushes the background toward pure white — great for whiteboards and
  /// bright printed pages, minimizes yellowing/shadow.
  static img.Image _applyBrightWhite(img.Image image) {
    img.Image result = img.adjustColor(
      image,
      contrast: 1.5,
      brightness: 1.25,
      saturation: 0.6,
    );
    return result;
  }

  /// Brightens shadows/underexposed scans without blowing out highlights —
  /// useful for photos taken in dim rooms.
  static img.Image _applyLowLightBoost(img.Image image) {
    img.Image result = img.adjustColor(
      image,
      brightness: 1.35,
      contrast: 1.12,
      gamma: 0.85,
    );
    return result;
  }

  /// Flattened, low-glare "matte" finish — reduces specular highlights on
  /// glossy pages.
  static img.Image _applyMatte(img.Image image) {
    img.Image result = img.adjustColor(
      image,
      contrast: 0.85,
      brightness: 1.02,
      saturation: 0.85,
    );
    return result;
  }

  /// Aged, slightly yellowed paper look with soft grain — decorative filter
  /// for scanning old letters/books.
  static img.Image _applyVintagePaper(img.Image image) {
    img.Image result = img.adjustColor(
      image,
      contrast: 0.95,
      brightness: 1.02,
      saturation: 0.7,
    );
    result = img.colorOffset(result, red: 20, green: 10, blue: -20);
    result = img.noise(result, 8, type: img.NoiseType.gaussian);
    return result;
  }

  /// Cold, desaturated steel-blue monochrome — clean technical/blueprint feel.
  static img.Image _applyColdSteel(img.Image image) {
    img.Image result = img.grayscale(image);
    result = img.adjustColor(result, contrast: 1.3, brightness: 1.0);
    for (final pixel in result) {
      final l = img.getLuminance(pixel);
      pixel
        ..r = (l * 0.85).clamp(0, 255)
        ..g = (l * 0.95).clamp(0, 255)
        ..b = (l * 1.15).clamp(0, 255);
    }
    return result;
  }

  /// A stronger version of "Enhance" — more aggressive color pop + edge
  /// sharpening, aimed at making colorful documents look print-ready.
  static img.Image _applyMagicColorPro(img.Image image) {
    img.Image result = img.adjustColor(
      image,
      contrast: 1.45,
      brightness: 1.1,
      saturation: 1.3,
    );
    result = img.convolution(
      result,
      filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
    );
    return result;
  }

  /// The recommended "best default" for text documents: denoise, punch up
  /// contrast, sharpen edges, and push the page toward white — closest to
  /// a flatbed-scanner result.
  static img.Image _applyCleanDocument(img.Image image) {
    img.Image result = img.gaussianBlur(image, radius: 1);
    result = img.adjustColor(result, contrast: 1.4, brightness: 1.15, saturation: 0.9);
    result = img.convolution(
      result,
      filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
    );
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
      case ScanFilter.vivid:
        return 'Vivid';
      case ScanFilter.softLight:
        return 'Soft Light';
      case ScanFilter.warmTone:
        return 'Warm Tone';
      case ScanFilter.coolTone:
        return 'Cool Tone';
      case ScanFilter.highContrastBW:
        return 'High Contrast B&W';
      case ScanFilter.softBW:
        return 'Soft B&W';
      case ScanFilter.sepia:
        return 'Sepia';
      case ScanFilter.noirDramatic:
        return 'Noir';
      case ScanFilter.brightWhite:
        return 'Bright White';
      case ScanFilter.lowLightBoost:
        return 'Low Light Boost';
      case ScanFilter.matte:
        return 'Matte';
      case ScanFilter.vintagePaper:
        return 'Vintage Paper';
      case ScanFilter.coldSteel:
        return 'Cold Steel';
      case ScanFilter.magicColorPro:
        return 'Magic Color Pro';
      case ScanFilter.invertNegative:
        return 'Negative';
      case ScanFilter.cleanDocument:
        return 'Clean Document';
    }
  }
}