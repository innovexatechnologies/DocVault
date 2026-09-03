import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'document_edge_detector.dart';

enum ScanFilter {
  original,
  grayscale,
  blackAndWhite,
  enhance,
  sharpen,
  vivid,
  softLight,
  warmTone,
  coolTone,
  highContrastBW,
  softBW,
  sepia,
  noirDramatic,
  brightWhite,
  lowLightBoost,
  matte,
  vintagePaper,
  coldSteel,
  magicColorPro,
  invertNegative,
  cleanDocument,
}

class ScanFilterService {
  // ============================================================
  // PROFESSIONAL AUTO DOCUMENT CROP
  // ============================================================

  static Uint8List autoCrop(Uint8List inputBytes) {
    final original = img.decodeImage(inputBytes);

    if (original == null) {
      throw ArgumentError('Could not decode image bytes.');
    }

    if (original.width < 120 || original.height < 120) {
      return inputBytes;
    }

    // ----------------------------------------------------------
    // 1. Create smaller analysis image.
    // ----------------------------------------------------------

    const analysisMaxSize = 1200;

    img.Image analysis = original;

    if (original.width > analysisMaxSize ||
        original.height > analysisMaxSize) {
      final scale = original.width >= original.height
          ? analysisMaxSize / original.width
          : analysisMaxSize / original.height;

      analysis = img.copyResize(
        original,
        width: math.max(
          1,
          (original.width * scale).round(),
        ),
        height: math.max(
          1,
          (original.height * scale).round(),
        ),
        interpolation: img.Interpolation.linear,
      );
    }

    // ----------------------------------------------------------
    // 2. Normalize image.
    // ----------------------------------------------------------

    final gray = img.grayscale(analysis);

    // Slight contrast improvement helps document boundaries.
    final enhanced = img.adjustColor(
      gray,
      contrast: 1.15,
      brightness: 1.02,
    );

    // ----------------------------------------------------------
    // 3. Extract a flat luminance buffer and hand it to the
    // shared detector -- the exact same algorithm the live
    // camera-preview overlay uses (see DocumentEdgeDetector).
    // ----------------------------------------------------------

    final luminance = Uint8List(
      enhanced.width * enhanced.height,
    );

    for (var y = 0; y < enhanced.height; y++) {
      for (var x = 0; x < enhanced.width; x++) {
        luminance[y * enhanced.width + x] =
            enhanced.getPixel(x, y).r.toInt();
      }
    }

    final detected = DocumentEdgeDetector.detect(
      luminance: luminance,
      width: enhanced.width,
      height: enhanced.height,
      minScore: DocumentEdgeDetector.minScoreForCrop,
    );

    if (detected == null) {
      return inputBytes;
    }

    // ----------------------------------------------------------
    // 4. Convert analysis coordinates to original coordinates.
    // ----------------------------------------------------------

    final scaleX = original.width / analysis.width;
    final scaleY = original.height / analysis.height;

    final topLeft = _Point(
      detected.topLeft.x * scaleX,
      detected.topLeft.y * scaleY,
    );

    final topRight = _Point(
      detected.topRight.x * scaleX,
      detected.topRight.y * scaleY,
    );

    final bottomRight = _Point(
      detected.bottomRight.x * scaleX,
      detected.bottomRight.y * scaleY,
    );

    final bottomLeft = _Point(
      detected.bottomLeft.x * scaleX,
      detected.bottomLeft.y * scaleY,
    );

    // ----------------------------------------------------------
    // 5. Add a very small margin.
    // ----------------------------------------------------------

    final expanded = _expandQuad(
      topLeft,
      topRight,
      bottomRight,
      bottomLeft,
      original.width,
      original.height,
    );

    // ----------------------------------------------------------
    // 6. Perspective correction.
    //
    // image.copyRectify maps the detected quadrilateral
    // to the output image.
    // ----------------------------------------------------------

    final rectified = img.copyRectify(
      original,
      topLeft: img.Point(
        expanded.topLeft.x.round(),
        expanded.topLeft.y.round(),
      ),
      topRight: img.Point(
        expanded.topRight.x.round(),
        expanded.topRight.y.round(),
      ),
      bottomLeft: img.Point(
        expanded.bottomLeft.x.round(),
        expanded.bottomLeft.y.round(),
      ),
      bottomRight: img.Point(
        expanded.bottomRight.x.round(),
        expanded.bottomRight.y.round(),
      ),
      interpolation: img.Interpolation.cubic,
    );

    // ----------------------------------------------------------
    // 7. Validate result.
    // ----------------------------------------------------------

    if (rectified.width < 50 ||
        rectified.height < 50) {
      return inputBytes;
    }

    return Uint8List.fromList(
      img.encodeJpg(
        rectified,
        quality: 95,
      ),
    );
  }

  // ============================================================
  // SMALL SMART PADDING
  // ============================================================

  static _DocumentCandidate _expandQuad(
    _Point topLeft,
    _Point topRight,
    _Point bottomRight,
    _Point bottomLeft,
    int width,
    int height,
  ) {
    // Only ~0.7% padding.
    final pad =
        math.min(width, height) * 0.007;

    final center = _Point(
      (
        topLeft.x +
        topRight.x +
        bottomRight.x +
        bottomLeft.x
      ) /
          4,
      (
        topLeft.y +
        topRight.y +
        bottomRight.y +
        bottomLeft.y
      ) /
          4,
    );

    _Point expand(_Point p) {
      final dx = p.x - center.x;
      final dy = p.y - center.y;

      final length =
          math.sqrt(
            (dx * dx) +
            (dy * dy),
          );

      if (length == 0) {
        return p;
      }

      final nx = dx / length;
      final ny = dy / length;

      return _Point(
        (p.x + nx * pad)
            .clamp(0, width - 1)
            .toDouble(),
        (p.y + ny * pad)
            .clamp(0, height - 1)
            .toDouble(),
      );
    }

    return _DocumentCandidate(
      topLeft: expand(topLeft),
      topRight: expand(topRight),
      bottomRight: expand(bottomRight),
      bottomLeft: expand(bottomLeft),
      score: 1,
    );
  }

  // ============================================================
  // EXISTING FILTER SYSTEM
  // ============================================================

  static Uint8List apply(
    ScanFilter filter,
    Uint8List inputBytes,
  ) {
    img.Image? image =
        img.decodeImage(inputBytes);

    if (image == null) {
      throw ArgumentError(
        'Could not decode image bytes.',
      );
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
          filter: [
            0, -1, 0,
            -1, 5, -1,
            0, -1, 0,
          ],
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

    return Uint8List.fromList(
      img.encodeJpg(
        image,
        quality: 92,
      ),
    );
  }

  static img.Image _applyBlackAndWhite(
    img.Image image,
  ) {
    var result = img.grayscale(image);

    result = img.adjustColor(
      result,
      contrast: 1.9,
      brightness: 1.05,
    );

    const threshold = 140;

    for (final pixel in result) {
      final luminance =
          img.getLuminance(pixel);

      final value =
          luminance > threshold ? 255 : 0;

      pixel
        ..r = value
        ..g = value
        ..b = value;
    }

    return result;
  }

  static img.Image _applyEnhance(
    img.Image image,
  ) {
    return img.adjustColor(
      image,
      contrast: 1.35,
      brightness: 1.08,
      saturation: 1.15,
    );
  }

  static img.Image _applyVivid(
    img.Image image,
  ) {
    var result = img.adjustColor(
      image,
      contrast: 1.25,
      saturation: 1.5,
      brightness: 1.03,
    );

    result = img.convolution(
      result,
      filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0,
      ],
    );

    return result;
  }

  static img.Image _applySoftLight(
    img.Image image,
  ) {
    var result = img.adjustColor(
      image,
      contrast: 0.92,
      brightness: 1.1,
      saturation: 0.95,
    );

    return img.gaussianBlur(
      result,
      radius: 1,
    );
  }

  static img.Image _applyWarmTone(
    img.Image image,
  ) {
    var result = img.adjustColor(
      image,
      contrast: 1.1,
      brightness: 1.04,
      saturation: 1.05,
    );

    return img.colorOffset(
      result,
      red: 18,
      green: 6,
      blue: -14,
    );
  }

  static img.Image _applyCoolTone(
    img.Image image,
  ) {
    var result = img.adjustColor(
      image,
      contrast: 1.1,
      brightness: 1.03,
    );

    return img.colorOffset(
      result,
      red: -12,
      green: -2,
      blue: 16,
    );
  }

  static img.Image _applyHighContrastBW(
    img.Image image,
  ) {
    final result = img.grayscale(image);

    return img.adjustColor(
      result,
      contrast: 2.4,
      brightness: 1.02,
    );
  }

  static img.Image _applySoftBW(
    img.Image image,
  ) {
    final result = img.grayscale(image);

    return img.adjustColor(
      result,
      contrast: 1.15,
      brightness: 1.05,
    );
  }

  static img.Image _applySepia(
    img.Image image,
  ) {
    final result = img.grayscale(image);

    for (final pixel in result) {
      final l =
          img.getLuminance(pixel);

      pixel
        ..r = (l * 1.07)
            .clamp(0, 255)
            .toInt()
        ..g = (l * 0.86)
            .clamp(0, 255)
            .toInt()
        ..b = (l * 0.63)
            .clamp(0, 255)
            .toInt();
    }

    return result;
  }

  static img.Image _applyNoirDramatic(
    img.Image image,
  ) {
    var result = img.grayscale(image);

    result = img.adjustColor(
      result,
      contrast: 1.7,
      brightness: 0.85,
    );

    return result;
  }

  static img.Image _applyBrightWhite(
    img.Image image,
  ) {
    return img.adjustColor(
      image,
      contrast: 1.5,
      brightness: 1.25,
      saturation: 0.6,
    );
  }

  static img.Image _applyLowLightBoost(
    img.Image image,
  ) {
    return img.adjustColor(
      image,
      brightness: 1.35,
      contrast: 1.12,
      gamma: 0.85,
    );
  }

  static img.Image _applyMatte(
    img.Image image,
  ) {
    return img.adjustColor(
      image,
      contrast: 0.85,
      brightness: 1.02,
      saturation: 0.85,
    );
  }

  static img.Image _applyVintagePaper(
    img.Image image,
  ) {
    var result = img.adjustColor(
      image,
      contrast: 0.95,
      brightness: 1.02,
      saturation: 0.7,
    );

    return img.colorOffset(
      result,
      red: 20,
      green: 10,
      blue: -20,
    );
  }

  static img.Image _applyColdSteel(
    img.Image image,
  ) {
    var result = img.grayscale(image);

    result = img.adjustColor(
      result,
      contrast: 1.3,
      brightness: 1.0,
    );

    for (final pixel in result) {
      final l =
          img.getLuminance(pixel);

      pixel
        ..r = (l * 0.85)
            .clamp(0, 255)
            .toInt()
        ..g = (l * 0.95)
            .clamp(0, 255)
            .toInt()
        ..b = (l * 1.15)
            .clamp(0, 255)
            .toInt();
    }

    return result;
  }

  static img.Image _applyMagicColorPro(
    img.Image image,
  ) {
    var result = img.adjustColor(
      image,
      contrast: 1.45,
      brightness: 1.1,
      saturation: 1.3,
    );

    return img.convolution(
      result,
      filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0,
      ],
    );
  }

  static img.Image _applyCleanDocument(
    img.Image image,
  ) {
    var result = img.gaussianBlur(
      image,
      radius: 1,
    );

    result = img.adjustColor(
      result,
      contrast: 1.4,
      brightness: 1.15,
      saturation: 0.9,
    );

    return img.convolution(
      result,
      filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0,
      ],
    );
  }

  static String label(
    ScanFilter filter,
  ) {
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

// ============================================================
// SUPPORT CLASSES
// ============================================================

class _Point {
  final double x;
  final double y;

  const _Point(
    this.x,
    this.y,
  );
}

class _DocumentCandidate {
  final _Point topLeft;
  final _Point topRight;
  final _Point bottomRight;
  final _Point bottomLeft;
  final double score;

  const _DocumentCandidate({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
    required this.score,
  });
}