import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../utils/file_utils.dart';

/// All available image filters.
///
/// Total: 21 filters.
enum ImageFilterType {
  none,
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

class ImageEditorService {
  static const _uuid = Uuid();

  // ============================================================
  // FILE PATH
  // ============================================================

  Future<String> _getNewEditedPath({
    String extension = 'jpg',
  }) async {
    final cacheDir = await FileUtils.getCacheDirectory();

    final normalizedExtension =
        extension.toLowerCase().replaceFirst('.', '');

    final fileName =
        'edited_${DateTime.now().millisecondsSinceEpoch}_'
        '${_uuid.v4().substring(0, 8)}.$normalizedExtension';

    return '${cacheDir.path}/$fileName';
  }

  // ============================================================
  // ROTATE
  // ============================================================

  /// Rotates image by 90, 180 or 270 degrees.
  Future<String> rotateImage(
    String inputPath,
    int degrees,
  ) async {
    final bytes = await File(inputPath).readAsBytes();

    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Unable to decode image.');
    }

    img.Image rotated;

    final normalized = degrees % 360;

    if (normalized == 90) {
      rotated = img.copyRotate(
        image,
        angle: 90,
      );
    } else if (normalized == 180) {
      rotated = img.copyRotate(
        image,
        angle: 180,
      );
    } else if (normalized == 270) {
      rotated = img.copyRotate(
        image,
        angle: 270,
      );
    } else {
      rotated = image;
    }

    return _saveImage(rotated);
  }

  // ============================================================
  // FLIP
  // ============================================================

  /// Flips image horizontally or vertically.
  Future<String> flipImage(
    String inputPath, {
    bool horizontal = true,
    bool vertical = false,
  }) async {
    final bytes = await File(inputPath).readAsBytes();

    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Unable to decode image.');
    }

    img.FlipDirection direction;

    if (horizontal && vertical) {
      direction = img.FlipDirection.both;
    } else if (horizontal) {
      direction = img.FlipDirection.horizontal;
    } else {
      direction = img.FlipDirection.vertical;
    }

    final flipped = img.copyFlip(
      image,
      direction: direction,
    );

    return _saveImage(flipped);
  }

  // ============================================================
  // CROP
  // ============================================================

  /// Crops an image using integer source-pixel coordinates.
  ///
  /// This is a true rectangular crop: pixels are copied directly from
  /// the decoded source image. No perspective transform, interpolation,
  /// scaling, padding, or resampling is performed.
  Future<String> cropImage(
    String inputPath, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Unable to decode image.');
    }

    if (image.width <= 0 || image.height <= 0) {
      throw Exception('Image has invalid dimensions.');
    }

    if (width <= 0 || height <= 0) {
      throw ArgumentError(
        'Crop width and height must be greater than zero.',
      );
    }

    final safeX = x.clamp(0, image.width - 1);
    final safeY = y.clamp(0, image.height - 1);

    final safeWidth = width.clamp(
      1,
      image.width - safeX,
    );
    final safeHeight = height.clamp(
      1,
      image.height - safeY,
    );

    final cropped = img.copyCrop(
      image,
      x: safeX,
      y: safeY,
      width: safeWidth,
      height: safeHeight,
    );

    // PNG is lossless. This prevents the crop operation itself from
    // introducing JPEG compression artefacts.
    return _saveLosslessCrop(cropped);
  }

  /// Crops using normalized image coordinates (0.0 -> 1.0).
  ///
  /// The normalized values are converted to integer source-pixel
  /// boundaries exactly once. Left/top/right/bottom are interpreted as
  /// crop boundaries, with right/bottom being exclusive.
  Future<String> cropImageNormalized(
    String inputPath, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Unable to decode image.');
    }

    if (image.width <= 0 || image.height <= 0) {
      throw Exception('Image has invalid dimensions.');
    }

    final l = left.clamp(0.0, 1.0);
    final t = top.clamp(0.0, 1.0);
    final r = right.clamp(0.0, 1.0);
    final b = bottom.clamp(0.0, 1.0);

    if (r <= l || b <= t) {
      throw ArgumentError(
        'Invalid crop rectangle.',
      );
    }

    // Convert the UI's normalized crop boundaries to source pixels.
    // round() gives a deterministic nearest-pixel boundary and avoids
    // accumulating floating-point truncation across multiple edits.
    var x0 = (l * image.width).round();
    var y0 = (t * image.height).round();
    var x1 = (r * image.width).round();
    var y1 = (b * image.height).round();

    x0 = x0.clamp(0, image.width - 1);
    y0 = y0.clamp(0, image.height - 1);
    x1 = x1.clamp(x0 + 1, image.width);
    y1 = y1.clamp(y0 + 1, image.height);

    final cropped = img.copyCrop(
      image,
      x: x0,
      y: y0,
      width: x1 - x0,
      height: y1 - y0,
    );

    // The crop itself remains lossless.
    return _saveLosslessCrop(cropped);
  }

  Future<String> _saveLosslessCrop(
    img.Image image,
  ) async {
    final outPath =
        await _getNewEditedPath(
      extension: 'png',
    );

    final outBytes = img.encodePng(image);

    await File(outPath).writeAsBytes(
      outBytes,
      flush: true,
    );

    return outPath;
  }

  // ============================================================
  // PERSPECTIVE CROP (4-POINT / QUAD)
  // ============================================================

  /// Crops and flattens an image using four independently-placed
  /// corners instead of an axis-aligned rectangle.
  ///
  /// Each corner is given as a fraction (0.0 -> 1.0) of the source
  /// image's width/height, so callers don't need to know the pixel
  /// dimensions up front.
  ///
  /// If the four corners already form an axis-aligned rectangle
  /// (e.g. a fixed-ratio crop that the user never skewed), this
  /// still produces a correct result: `img.copyRectify` degrades
  /// gracefully to a plain crop/resample in that case.
  Future<String> perspectiveCropQuad(
    String inputPath, {
    required Offset topLeft,
    required Offset topRight,
    required Offset bottomLeft,
    required Offset bottomRight,
  }) async {
    final bytes = await File(inputPath).readAsBytes();

    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Unable to decode image.');
    }

    img.Point toPixel(Offset normalized) {
      final px = (normalized.dx * image.width)
          .round()
          .clamp(0, image.width - 1);

      final py = (normalized.dy * image.height)
          .round()
          .clamp(0, image.height - 1);

      return img.Point(px, py);
    }

    final pTopLeft = toPixel(topLeft);
    final pTopRight = toPixel(topRight);
    final pBottomLeft = toPixel(bottomLeft);
    final pBottomRight = toPixel(bottomRight);

    // Guard against a degenerate/collapsed quad (e.g. all four
    // corners dragged to nearly the same point) before we ask the
    // image library to rectify it.
    final minSpanX = math.max(
      (pTopRight.x - pTopLeft.x).abs(),
      (pBottomRight.x - pBottomLeft.x).abs(),
    );

    final minSpanY = math.max(
      (pBottomLeft.y - pTopLeft.y).abs(),
      (pBottomRight.y - pTopRight.y).abs(),
    );

    if (minSpanX < 10 || minSpanY < 10) {
      throw Exception(
        'Crop area is too small. Drag the corners further apart.',
      );
    }

    final rectified = img.copyRectify(
      image,
      topLeft: pTopLeft,
      topRight: pTopRight,
      bottomLeft: pBottomLeft,
      bottomRight: pBottomRight,
      interpolation: img.Interpolation.cubic,
    );

    if (rectified.width < 10 || rectified.height < 10) {
      throw Exception('Crop result is too small.');
    }

    return _saveImage(rectified);
  }

  // ============================================================
  // APPLY FILTER
  // ============================================================

  /// Applies one of the 21 image filters.
  Future<String> applyFilter(
    String inputPath,
    ImageFilterType filter,
  ) async {
    // Original = no processing.
    if (filter == ImageFilterType.none) {
      return inputPath;
    }

    final bytes = await File(inputPath).readAsBytes();

    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Unable to decode image.');
    }

    img.Image filtered;

    switch (filter) {
      // ----------------------------------------------------------
      // 1. GRAYSCALE
      // ----------------------------------------------------------

      case ImageFilterType.grayscale:
        filtered = _applyGrayscale(image);
        break;

      // ----------------------------------------------------------
      // 2. BLACK & WHITE
      // ----------------------------------------------------------

      case ImageFilterType.blackAndWhite:
        filtered = _applyBlackAndWhite(image);
        break;

      // ----------------------------------------------------------
      // 3. ENHANCE
      // ----------------------------------------------------------

      case ImageFilterType.enhance:
        filtered = _applyEnhance(image);
        break;

      // ----------------------------------------------------------
      // 4. SHARPEN
      // ----------------------------------------------------------

      case ImageFilterType.sharpen:
        filtered = _applySharpen(image);
        break;

      // ----------------------------------------------------------
      // 5. VIVID
      // ----------------------------------------------------------

      case ImageFilterType.vivid:
        filtered = _applyVivid(image);
        break;

      // ----------------------------------------------------------
      // 6. SOFT LIGHT
      // ----------------------------------------------------------

      case ImageFilterType.softLight:
        filtered = _applySoftLight(image);
        break;

      // ----------------------------------------------------------
      // 7. WARM TONE
      // ----------------------------------------------------------

      case ImageFilterType.warmTone:
        filtered = _applyWarmTone(image);
        break;

      // ----------------------------------------------------------
      // 8. COOL TONE
      // ----------------------------------------------------------

      case ImageFilterType.coolTone:
        filtered = _applyCoolTone(image);
        break;

      // ----------------------------------------------------------
      // 9. HIGH CONTRAST B&W
      // ----------------------------------------------------------

      case ImageFilterType.highContrastBW:
        filtered = _applyHighContrastBW(image);
        break;

      // ----------------------------------------------------------
      // 10. SOFT B&W
      // ----------------------------------------------------------

      case ImageFilterType.softBW:
        filtered = _applySoftBW(image);
        break;

      // ----------------------------------------------------------
      // 11. SEPIA
      // ----------------------------------------------------------

      case ImageFilterType.sepia:
        filtered = _applySepia(image);
        break;

      // ----------------------------------------------------------
      // 12. NOIR
      // ----------------------------------------------------------

      case ImageFilterType.noirDramatic:
        filtered = _applyNoirDramatic(image);
        break;

      // ----------------------------------------------------------
      // 13. BRIGHT WHITE
      // ----------------------------------------------------------

      case ImageFilterType.brightWhite:
        filtered = _applyBrightWhite(image);
        break;

      // ----------------------------------------------------------
      // 14. LOW LIGHT BOOST
      // ----------------------------------------------------------

      case ImageFilterType.lowLightBoost:
        filtered = _applyLowLightBoost(image);
        break;

      // ----------------------------------------------------------
      // 15. MATTE
      // ----------------------------------------------------------

      case ImageFilterType.matte:
        filtered = _applyMatte(image);
        break;

      // ----------------------------------------------------------
      // 16. VINTAGE PAPER
      // ----------------------------------------------------------

      case ImageFilterType.vintagePaper:
        filtered = _applyVintagePaper(image);
        break;

      // ----------------------------------------------------------
      // 17. COLD STEEL
      // ----------------------------------------------------------

      case ImageFilterType.coldSteel:
        filtered = _applyColdSteel(image);
        break;

      // ----------------------------------------------------------
      // 18. MAGIC COLOR PRO
      // ----------------------------------------------------------

      case ImageFilterType.magicColorPro:
        filtered = _applyMagicColorPro(image);
        break;

      // ----------------------------------------------------------
      // 19. NEGATIVE
      // ----------------------------------------------------------

      case ImageFilterType.invertNegative:
        filtered = img.invert(image);
        break;

      // ----------------------------------------------------------
      // 20. CLEAN DOCUMENT
      // ----------------------------------------------------------

      case ImageFilterType.cleanDocument:
        filtered = _applyCleanDocument(image);
        break;

      // ----------------------------------------------------------
      // ORIGINAL
      // ----------------------------------------------------------

      case ImageFilterType.none:
        filtered = image;
        break;
    }

    return _saveImage(filtered);
  }

  // ============================================================
  // FILTER 1 - GRAYSCALE
  // ============================================================

  static img.Image _applyGrayscale(
    img.Image image,
  ) {
    return img.grayscale(image);
  }

  // ============================================================
  // FILTER 2 - BLACK & WHITE
  // ============================================================

  static img.Image _applyBlackAndWhite(
    img.Image image,
  ) {
    img.Image result = img.grayscale(image);

    result = img.adjustColor(
      result,
      contrast: 1.9,
      brightness: 1.05,
    );

    const threshold = 140;

    for (final pixel in result) {
      final luminance = img.getLuminance(pixel);

      final value =
          luminance > threshold ? 255 : 0;

      pixel
        ..r = value
        ..g = value
        ..b = value;
    }

    return result;
  }

  // ============================================================
  // FILTER 3 - ENHANCE
  // ============================================================

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

  // ============================================================
  // FILTER 4 - SHARPEN
  // ============================================================

  static img.Image _applySharpen(
    img.Image image,
  ) {
    return img.convolution(
      image,
      filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0,
      ],
    );
  }

  // ============================================================
  // FILTER 5 - VIVID
  // ============================================================

  static img.Image _applyVivid(
    img.Image image,
  ) {
    img.Image result = img.adjustColor(
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

  // ============================================================
  // FILTER 6 - SOFT LIGHT
  // ============================================================

  static img.Image _applySoftLight(
    img.Image image,
  ) {
    img.Image result = img.adjustColor(
      image,
      contrast: 0.92,
      brightness: 1.10,
      saturation: 0.95,
    );

    return img.gaussianBlur(
      result,
      radius: 1,
    );
  }

  // ============================================================
  // FILTER 7 - WARM TONE
  // ============================================================

  static img.Image _applyWarmTone(
    img.Image image,
  ) {
    img.Image result = img.adjustColor(
      image,
      contrast: 1.10,
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

  // ============================================================
  // FILTER 8 - COOL TONE
  // ============================================================

  static img.Image _applyCoolTone(
    img.Image image,
  ) {
    img.Image result = img.adjustColor(
      image,
      contrast: 1.10,
      brightness: 1.03,
    );

    return img.colorOffset(
      result,
      red: -12,
      green: -2,
      blue: 16,
    );
  }

  // ============================================================
  // FILTER 9 - HIGH CONTRAST B&W
  // ============================================================

  static img.Image _applyHighContrastBW(
    img.Image image,
  ) {
    img.Image result = img.grayscale(image);

    return img.adjustColor(
      result,
      contrast: 2.4,
      brightness: 1.02,
    );
  }

  // ============================================================
  // FILTER 10 - SOFT B&W
  // ============================================================

  static img.Image _applySoftBW(
    img.Image image,
  ) {
    img.Image result = img.grayscale(image);

    return img.adjustColor(
      result,
      contrast: 1.15,
      brightness: 1.05,
    );
  }

  // ============================================================
  // FILTER 11 - SEPIA
  // ============================================================

  static img.Image _applySepia(
    img.Image image,
  ) {
    img.Image result = img.grayscale(image);

    for (final pixel in result) {
      final l = img.getLuminance(pixel);

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

  // ============================================================
  // FILTER 12 - NOIR DRAMATIC
  // ============================================================

  static img.Image _applyNoirDramatic(
    img.Image image,
  ) {
    img.Image result = img.grayscale(image);

    result = img.adjustColor(
      result,
      contrast: 1.7,
      brightness: 0.85,
    );

    return result;
  }

  // ============================================================
  // FILTER 13 - BRIGHT WHITE
  // ============================================================

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

  // ============================================================
  // FILTER 14 - LOW LIGHT BOOST
  // ============================================================

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

  // ============================================================
  // FILTER 15 - MATTE
  // ============================================================

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

  // ============================================================
  // FILTER 16 - VINTAGE PAPER
  // ============================================================

  static img.Image _applyVintagePaper(
    img.Image image,
  ) {
    img.Image result = img.adjustColor(
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

  // ============================================================
  // FILTER 17 - COLD STEEL
  // ============================================================

  static img.Image _applyColdSteel(
    img.Image image,
  ) {
    img.Image result = img.grayscale(image);

    result = img.adjustColor(
      result,
      contrast: 1.3,
      brightness: 1.0,
    );

    for (final pixel in result) {
      final l = img.getLuminance(pixel);

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

  // ============================================================
  // FILTER 18 - MAGIC COLOR PRO
  // ============================================================

  static img.Image _applyMagicColorPro(
    img.Image image,
  ) {
    img.Image result = img.adjustColor(
      image,
      contrast: 1.45,
      brightness: 1.10,
      saturation: 1.30,
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

  // ============================================================
  // FILTER 20 - CLEAN DOCUMENT
  // ============================================================

  static img.Image _applyCleanDocument(
    img.Image image,
  ) {
    img.Image result = img.gaussianBlur(
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

  // ============================================================
  // AUTO CROP
  // ============================================================

  /// Attempts to detect the document area automatically.
  Future<String> autoCropImage(
    String inputPath,
  ) async {
    final bytes = await File(inputPath).readAsBytes();

    final original = img.decodeImage(bytes);

    if (original == null) {
      throw ArgumentError(
        'Could not decode image bytes.',
      );
    }

    if (original.width < 80 ||
        original.height < 80) {
      return inputPath;
    }

    const maxSize = 900;

    img.Image analysis = original;

    if (original.width > maxSize ||
        original.height > maxSize) {
      final scale =
          original.width >= original.height
              ? maxSize / original.width
              : maxSize / original.height;

      analysis = img.copyResize(
        original,
        width:
            (original.width * scale).round(),
        height:
            (original.height * scale).round(),
      );
    }

    final gray = img.grayscale(analysis);

    final width = gray.width;
    final height = gray.height;

    final borderValues = <int>[];

    final borderStep = math.max(
      2,
      math.min(width, height) ~/ 150,
    );

    for (
      var x = 0;
      x < width;
      x += borderStep
    ) {
      final topPixel =
          gray.getPixel(x, 0);

      final bottomPixel =
          gray.getPixel(x, height - 1);

      borderValues.add(
        ((topPixel.r +
                    topPixel.g +
                    topPixel.b) /
                3)
            .round(),
      );

      borderValues.add(
        ((bottomPixel.r +
                    bottomPixel.g +
                    bottomPixel.b) /
                3)
            .round(),
      );
    }

    for (
      var y = 0;
      y < height;
      y += borderStep
    ) {
      final leftPixel =
          gray.getPixel(0, y);

      final rightPixel =
          gray.getPixel(width - 1, y);

      borderValues.add(
        ((leftPixel.r +
                    leftPixel.g +
                    leftPixel.b) /
                3)
            .round(),
      );

      borderValues.add(
        ((rightPixel.r +
                    rightPixel.g +
                    rightPixel.b) /
                3)
            .round(),
      );
    }

    if (borderValues.isEmpty) {
      return inputPath;
    }

    borderValues.sort();

    final borderMedian =
        borderValues[
            borderValues.length ~/ 2];

    _CropCandidate? bestCandidate;

    const thresholds = [
      18,
      25,
      35,
      45,
      60,
      80,
    ];

    for (final threshold in thresholds) {
      final candidate =
          _detectDocumentBounds(
        gray,
        borderMedian,
        threshold,
      );

      if (candidate == null) {
        continue;
      }

      if (bestCandidate == null ||
          candidate.score >
              bestCandidate.score) {
        bestCandidate = candidate;
      }
    }

    // Second, content-adaptive pass: instead of relying only on a flat
    // border-color difference (which assumes a fairly uniform background),
    // also look at where the image's own internal edges are strongest.
    // This helps on busy backgrounds, low-contrast paper, or documents
    // that fill nearly the whole frame, where the border-diff method
    // alone tends to under- or over-crop.
    final gradientCandidate = _detectDocumentBoundsByGradient(gray);

    if (gradientCandidate != null &&
        (bestCandidate == null ||
            gradientCandidate.score > bestCandidate.score)) {
      bestCandidate = gradientCandidate;
    }

    if (bestCandidate == null) {
      return inputPath;
    }

    final scaleX =
        original.width / width;

    final scaleY =
        original.height / height;

    var left =
        (bestCandidate.left * scaleX)
            .round();

    var top =
        (bestCandidate.top * scaleY)
            .round();

    var right =
        (bestCandidate.right * scaleX)
            .round();

    var bottom =
        (bestCandidate.bottom * scaleY)
            .round();

    final paddingX = math.max(
      4,
      (original.width * 0.008).round(),
    );

    final paddingY = math.max(
      4,
      (original.height * 0.008).round(),
    );

    left = math.max(
      0,
      left - paddingX,
    );

    top = math.max(
      0,
      top - paddingY,
    );

    right = math.min(
      original.width,
      right + paddingX,
    );

    bottom = math.min(
      original.height,
      bottom + paddingY,
    );

    final cropWidth =
        right - left;

    final cropHeight =
        bottom - top;

    if (cropWidth <= 20 ||
        cropHeight <= 20) {
      return inputPath;
    }

    if (cropWidth <
            original.width * 0.15 ||
        cropHeight <
            original.height * 0.15) {
      return inputPath;
    }

    final cropped = img.copyCrop(
      original,
      x: left,
      y: top,
      width: cropWidth,
      height: cropHeight,
    );

    return _saveImage(cropped);
  }

  // ============================================================
  // DOCUMENT DETECTION
  // ============================================================

  static _CropCandidate?
      _detectDocumentBounds(
    img.Image gray,
    int borderMedian,
    int threshold,
  ) {
    final width = gray.width;
    final height = gray.height;

    var minX = width;
    var minY = height;

    var maxX = -1;
    var maxY = -1;

    var detectedPixels = 0;

    final sampleStep = math.max(
      1,
      math.min(width, height) ~/ 500,
    );

    for (
      var y = 0;
      y < height;
      y += sampleStep
    ) {
      for (
        var x = 0;
        x < width;
        x += sampleStep
      ) {
        final pixel =
            gray.getPixel(x, y);

        final value =
            ((pixel.r +
                        pixel.g +
                        pixel.b) /
                    3)
                .round();

        final difference =
            (value - borderMedian).abs();

        if (difference >= threshold) {
          detectedPixels++;

          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX <= minX ||
        maxY <= minY) {
      return null;
    }

    final detectedWidth =
        maxX - minX;

    final detectedHeight =
        maxY - minY;

    final imageArea =
        width * height;

    final detectedArea =
        detectedWidth * detectedHeight;

    final areaRatio =
        detectedArea / imageArea;

    if (areaRatio < 0.20 ||
        areaRatio > 0.98) {
      return null;
    }

    final aspectRatio =
        detectedWidth /
            detectedHeight;

    if (aspectRatio < 0.25 ||
        aspectRatio > 4.5) {
      return null;
    }

    final totalSamples =
        ((width +
                    sampleStep -
                    1) ~/
                sampleStep) *
            ((height +
                    sampleStep -
                    1) ~/
                sampleStep);

    final coverage =
        detectedPixels /
            totalSamples;

    final areaScore =
        areaRatio < 0.85
            ? areaRatio
            : 1.0 - areaRatio;

    final score =
        (areaScore * 0.7) +
            (coverage * 0.3);

    return _CropCandidate(
      left: minX,
      top: minY,
      right: maxX,
      bottom: maxY,
      score: score,
    );
  }

  // ============================================================
  // DOCUMENT DETECTION (edge-gradient, content-adaptive)
  // ============================================================

  /// Detects the document region by following the image's own strongest
  /// internal edges rather than assuming a flat, contrasting border.
  ///
  /// The threshold used to decide "this row/column has a document edge"
  /// is relative to that image's own peak edge energy (not a fixed
  /// constant), so the detector adapts to each photo's lighting,
  /// background clutter, and contrast instead of using one setting
  /// for every document.
  static _CropCandidate? _detectDocumentBoundsByGradient(
    img.Image gray,
  ) {
    final width = gray.width;
    final height = gray.height;

    final sampleStep = math.max(
      1,
      math.min(width, height) ~/ 400,
    );

    final cols = (width / sampleStep).ceil();
    final rows = (height / sampleStep).ceil();

    if (cols < 3 || rows < 3) {
      return null;
    }

    final lum = List.generate(
      rows,
      (_) => List<int>.filled(cols, 0),
    );

    for (var ry = 0; ry < rows; ry++) {
      final y = math.min(ry * sampleStep, height - 1);

      for (var rx = 0; rx < cols; rx++) {
        final x = math.min(rx * sampleStep, width - 1);
        final pixel = gray.getPixel(x, y);

        lum[ry][rx] =
            ((pixel.r + pixel.g + pixel.b) / 3).round();
      }
    }

    // Row/column edge-energy profiles: how much brightness changes
    // as you scan across that row / down that column.
    final rowEnergy = List<double>.filled(rows, 0);
    final colEnergy = List<double>.filled(cols, 0);

    for (var ry = 0; ry < rows; ry++) {
      for (var rx = 1; rx < cols; rx++) {
        rowEnergy[ry] +=
            (lum[ry][rx] - lum[ry][rx - 1]).abs().toDouble();
      }
    }

    for (var rx = 0; rx < cols; rx++) {
      for (var ry = 1; ry < rows; ry++) {
        colEnergy[rx] +=
            (lum[ry][rx] - lum[ry - 1][rx]).abs().toDouble();
      }
    }

    final maxRow = rowEnergy.isEmpty
        ? 0.0
        : rowEnergy.reduce(math.max);

    final maxCol = colEnergy.isEmpty
        ? 0.0
        : colEnergy.reduce(math.max);

    if (maxRow <= 0 || maxCol <= 0) {
      return null;
    }

    // Adaptive: relative to THIS image's own peak edge energy, so a
    // faint document on soft paper and a crisp document on a cluttered
    // desk both get a sensible cutoff.
    const relativeThreshold = 0.22;

    var top = 0;
    var bottom = rows - 1;
    var left = 0;
    var right = cols - 1;

    for (var ry = 0; ry < rows; ry++) {
      if (rowEnergy[ry] / maxRow >= relativeThreshold) {
        top = ry;
        break;
      }
    }

    for (var ry = rows - 1; ry >= 0; ry--) {
      if (rowEnergy[ry] / maxRow >= relativeThreshold) {
        bottom = ry;
        break;
      }
    }

    for (var rx = 0; rx < cols; rx++) {
      if (colEnergy[rx] / maxCol >= relativeThreshold) {
        left = rx;
        break;
      }
    }

    for (var rx = cols - 1; rx >= 0; rx--) {
      if (colEnergy[rx] / maxCol >= relativeThreshold) {
        right = rx;
        break;
      }
    }

    if (right <= left || bottom <= top) {
      return null;
    }

    final minX = left * sampleStep;
    final maxX = math.min(right * sampleStep, width - 1);
    final minY = top * sampleStep;
    final maxY = math.min(bottom * sampleStep, height - 1);

    final detectedWidth = maxX - minX;
    final detectedHeight = maxY - minY;

    final imageArea = width * height;
    final detectedArea = detectedWidth * detectedHeight;
    final areaRatio = detectedArea / imageArea;

    if (areaRatio < 0.20 || areaRatio > 0.98) {
      return null;
    }

    final aspectRatio = detectedWidth / detectedHeight;

    if (aspectRatio < 0.25 || aspectRatio > 4.5) {
      return null;
    }

    final areaScore =
        areaRatio < 0.85 ? areaRatio : 1.0 - areaRatio;

    final edgeScore =
        (((maxRow + maxCol) / 2).clamp(0, 500)) / 500;

    final score = (areaScore * 0.55) + (edgeScore * 0.45);

    return _CropCandidate(
      left: minX,
      top: minY,
      right: maxX,
      bottom: maxY,
      score: score,
    );
  }

  // ============================================================
  // TEXT OVERLAY
  // ============================================================

  Future<String> addTextOverlay(
    String inputPath, {
    required String text,
    required double xPercent,
    required double yPercent,
    required Color color,
    int fontSize = 24,
  }) async {
    final bytes =
        await File(inputPath).readAsBytes();

    final image =
        img.decodeImage(bytes);

    if (image == null) {
      throw Exception(
        'Unable to decode image.',
      );
    }

    final posX =
        (xPercent * image.width)
            .toInt()
            .clamp(
              0,
              image.width - 20,
            );

    final posY =
        (yPercent * image.height)
            .toInt()
            .clamp(
              0,
              image.height - 20,
            );

    final font =
        fontSize > 32
            ? img.arial48
            : (fontSize > 18
                ? img.arial24
                : img.arial14);

    final textColor =
        img.ColorRgba8(
      (color.r * 255)
          .round()
          .clamp(0, 255),
      (color.g * 255)
          .round()
          .clamp(0, 255),
      (color.b * 255)
          .round()
          .clamp(0, 255),
      (color.a * 255)
          .round()
          .clamp(0, 255),
    );

    img.drawString(
      image,
      text,
      font: font,
      x: posX,
      y: posY,
      color: textColor,
    );

    return _saveImage(image);
  }

  // ============================================================
  // FILTER LABEL
  // ============================================================

  static String label(
    ImageFilterType filter,
  ) {
    switch (filter) {
      case ImageFilterType.none:
        return 'Original';

      case ImageFilterType.grayscale:
        return 'Gray';

      case ImageFilterType.blackAndWhite:
        return 'B&W';

      case ImageFilterType.enhance:
        return 'Enhance';

      case ImageFilterType.sharpen:
        return 'Sharpen';

      case ImageFilterType.vivid:
        return 'Vivid';

      case ImageFilterType.softLight:
        return 'Soft Light';

      case ImageFilterType.warmTone:
        return 'Warm Tone';

      case ImageFilterType.coolTone:
        return 'Cool Tone';

      case ImageFilterType.highContrastBW:
        return 'High Contrast';

      case ImageFilterType.softBW:
        return 'Soft B&W';

      case ImageFilterType.sepia:
        return 'Sepia';

      case ImageFilterType.noirDramatic:
        return 'Noir';

      case ImageFilterType.brightWhite:
        return 'Bright White';

      case ImageFilterType.lowLightBoost:
        return 'Low Light';

      case ImageFilterType.matte:
        return 'Matte';

      case ImageFilterType.vintagePaper:
        return 'Vintage Paper';

      case ImageFilterType.coldSteel:
        return 'Cold Steel';

      case ImageFilterType.magicColorPro:
        return 'Magic Color';

      case ImageFilterType.invertNegative:
        return 'Negative';

      case ImageFilterType.cleanDocument:
        return 'Clean Doc';
    }
  }

  // ============================================================
  // SAVE IMAGE
  // ============================================================

  Future<String> _saveImage(
    img.Image image,
  ) async {
    final outPath =
        await _getNewEditedPath();

    final outBytes =
        img.encodeJpg(
      image,
      quality: 92,
    );

    await File(outPath).writeAsBytes(
      outBytes,
      flush: true,
    );

    return outPath;
  }
}

// ================================================================
// CROP CANDIDATE
// ================================================================

class _CropCandidate {
  final int left;
  final int top;
  final int right;
  final int bottom;
  final double score;

  const _CropCandidate({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.score,
  });
}