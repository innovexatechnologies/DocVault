 import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

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
  static Uint8List autoCrop(Uint8List inputBytes) {
    final original = img.decodeImage(inputBytes);

    if (original == null) {
      throw ArgumentError('Could not decode image bytes.');
    }

    if (original.width < 80 || original.height < 80) {
      return inputBytes;
    }

    const maxSize = 900;

    img.Image analysis = original;

    if (original.width > maxSize || original.height > maxSize) {
      final scale = original.width >= original.height
          ? maxSize / original.width
          : maxSize / original.height;

      analysis = img.copyResize(
        original,
        width: (original.width * scale).round(),
        height: (original.height * scale).round(),
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

for (var x = 0; x < width; x += borderStep) {
  final topPixel = gray.getPixel(x, 0);
  final bottomPixel = gray.getPixel(x, height - 1);

  borderValues.add(
    ((topPixel.r + topPixel.g + topPixel.b) / 3).round(),
  );

  borderValues.add(
    ((bottomPixel.r + bottomPixel.g + bottomPixel.b) / 3).round(),
  );
}

for (var y = 0; y < height; y += borderStep) {
  final leftPixel = gray.getPixel(0, y);
  final rightPixel = gray.getPixel(width - 1, y);

  borderValues.add(
    ((leftPixel.r + leftPixel.g + leftPixel.b) / 3).round(),
  );

  borderValues.add(
    ((rightPixel.r + rightPixel.g + rightPixel.b) / 3).round(),
  );
}

    if (borderValues.isEmpty) {
      return inputBytes;
    }

    borderValues.sort();

    final borderMedian =
        borderValues[borderValues.length ~/ 2];

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
      final candidate = _detectDocumentBounds(
        gray,
        borderMedian,
        threshold,
      );

      if (candidate == null) {
        continue;
      }

      if (bestCandidate == null ||
          candidate.score > bestCandidate.score) {
        bestCandidate = candidate;
      }
    }

    if (bestCandidate == null) {
      return inputBytes;
    }

    final scaleX = original.width / width;
    final scaleY = original.height / height;

    var left =
        (bestCandidate.left * scaleX).round();

    var top =
        (bestCandidate.top * scaleY).round();

    var right =
        (bestCandidate.right * scaleX).round();

    var bottom =
        (bestCandidate.bottom * scaleY).round();

    final paddingX = math.max(
      4,
      (original.width * 0.008).round(),
    );

    final paddingY = math.max(
      4,
      (original.height * 0.008).round(),
    );

    left = math.max(0, left - paddingX);
    top = math.max(0, top - paddingY);

    right = math.min(
      original.width,
      right + paddingX,
    );

    bottom = math.min(
      original.height,
      bottom + paddingY,
    );

    final cropWidth = right - left;
    final cropHeight = bottom - top;

    if (cropWidth <= 20 || cropHeight <= 20) {
      return inputBytes;
    }

    if (cropWidth < original.width * 0.15 ||
        cropHeight < original.height * 0.15) {
      return inputBytes;
    }

    final cropped = img.copyCrop(
      original,
      x: left,
      y: top,
      width: cropWidth,
      height: cropHeight,
    );

    return Uint8List.fromList(
      img.encodeJpg(
        cropped,
        quality: 95,
      ),
    );
  }

  static _CropCandidate? _detectDocumentBounds(
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

    for (var y = 0; y < height; y += sampleStep) {
      for (var x = 0; x < width; x += sampleStep) {
        final pixel = gray.getPixel(x, y);

final value =
    ((pixel.r + pixel.g + pixel.b) / 3).round();

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

    if (maxX <= minX || maxY <= minY) {
      return null;
    }

    final detectedWidth = maxX - minX;
    final detectedHeight = maxY - minY;

    final imageArea = width * height;
    final detectedArea =
        detectedWidth * detectedHeight;

    final areaRatio =
        detectedArea / imageArea;

    if (areaRatio < 0.20 || areaRatio > 0.98) {
      return null;
    }

    final aspectRatio =
        detectedWidth / detectedHeight;

    if (aspectRatio < 0.25 || aspectRatio > 4.5) {
      return null;
    }

    final totalSamples =
        ((width + sampleStep - 1) ~/ sampleStep) *
            ((height + sampleStep - 1) ~/ sampleStep);

    final coverage =
        detectedPixels / totalSamples;

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
    img.Image result = img.grayscale(image);

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

  static img.Image _applySoftLight(
    img.Image image,
  ) {
    img.Image result = img.adjustColor(
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
    img.Image result = img.adjustColor(
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
    img.Image result = img.adjustColor(
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
    img.Image result =
        img.grayscale(image);

    return img.adjustColor(
      result,
      contrast: 2.4,
      brightness: 1.02,
    );
  }

  static img.Image _applySoftBW(
    img.Image image,
  ) {
    img.Image result =
        img.grayscale(image);

    return img.adjustColor(
      result,
      contrast: 1.15,
      brightness: 1.05,
    );
  }

  static img.Image _applySepia(
    img.Image image,
  ) {
    img.Image result =
        img.grayscale(image);

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
    img.Image result =
        img.grayscale(image);

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

  static img.Image _applyColdSteel(
    img.Image image,
  ) {
    img.Image result =
        img.grayscale(image);

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
    img.Image result = img.adjustColor(
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
    img.Image result =
        img.gaussianBlur(
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
 
