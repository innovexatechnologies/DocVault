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
    // 3. Build edge map.
    // ----------------------------------------------------------

    final edgeMap = _buildEdgeMap(enhanced);

    // ----------------------------------------------------------
    // 4. Detect strongest document candidates.
    // ----------------------------------------------------------

    final candidate = _findBestDocumentQuad(
      edgeMap,
      enhanced,
    );

    if (candidate == null) {
      return inputBytes;
    }

    // ----------------------------------------------------------
    // 5. Convert analysis coordinates to original coordinates.
    // ----------------------------------------------------------

    final scaleX = original.width / analysis.width;
    final scaleY = original.height / analysis.height;

    final topLeft = _Point(
      candidate.topLeft.x * scaleX,
      candidate.topLeft.y * scaleY,
    );

    final topRight = _Point(
      candidate.topRight.x * scaleX,
      candidate.topRight.y * scaleY,
    );

    final bottomRight = _Point(
      candidate.bottomRight.x * scaleX,
      candidate.bottomRight.y * scaleY,
    );

    final bottomLeft = _Point(
      candidate.bottomLeft.x * scaleX,
      candidate.bottomLeft.y * scaleY,
    );

    // ----------------------------------------------------------
    // 6. Add a very small margin.
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
    // 7. Perspective correction.
    //
    // image.copyRectify maps the detected quadrilateral
    // to the output image.
    // ----------------------------------------------------------

    final docWidth = math.max(
      _distance(expanded.topLeft, expanded.topRight),
      _distance(expanded.bottomLeft, expanded.bottomRight),
    ).round();

    final docHeight = math.max(
      _distance(expanded.topLeft, expanded.bottomLeft),
      _distance(expanded.topRight, expanded.bottomRight),
    ).round();

    final targetImage = img.Image(
      width: math.max(50, docWidth),
      height: math.max(50, docHeight),
    );

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
      toImage: targetImage,
      interpolation: img.Interpolation.cubic,
    );

    // ----------------------------------------------------------
    // 8. Validate result.
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
  // EDGE DETECTION
  // ============================================================

  static img.Image _buildEdgeMap(img.Image image) {
    final width = image.width;
    final height = image.height;

    final result = img.Image(
      width: width,
      height: height,
      numChannels: 1,
    );

    const threshold = 22;

    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final p00 = _gray(image, x - 1, y - 1);
        final p01 = _gray(image, x, y - 1);
        final p02 = _gray(image, x + 1, y - 1);

        final p10 = _gray(image, x - 1, y);
        final p12 = _gray(image, x + 1, y);

        final p20 = _gray(image, x - 1, y + 1);
        final p21 = _gray(image, x, y + 1);
        final p22 = _gray(image, x + 1, y + 1);

        final gx =
            (-p00) +
            p02 +
            (-2 * p10) +
            (2 * p12) +
            (-p20) +
            p22;

        final gy =
            (-p00) +
            (-2 * p01) +
            (-p02) +
            p20 +
            (2 * p21) +
            p22;

        final magnitude =
            math.sqrt(
              (gx * gx) + (gy * gy),
            );

        final value =
            magnitude >= threshold
                ? math.min(255, magnitude.round())
                : 0;

        result.setPixelRgba(
          x,
          y,
          value,
          value,
          value,
          255,
        );
      }
    }

    return result;
  }

  static int _gray(
    img.Image image,
    int x,
    int y,
  ) {
    final pixel = image.getPixel(x, y);

    return (
      (pixel.r * 0.299) +
      (pixel.g * 0.587) +
      (pixel.b * 0.114)
    ).round();
  }

  // ============================================================
  // DOCUMENT QUADRILATERAL DETECTION
  // ============================================================

  static _DocumentCandidate? _findBestDocumentQuad(
    img.Image edges,
    img.Image gray,
  ) {
    final width = edges.width;
    final height = edges.height;

    final points = <_Point>[];

    // ----------------------------------------------------------
    // Collect strong edge points.
    // ----------------------------------------------------------

    final step = math.max(
      2,
      math.min(width, height) ~/ 450,
    );

    for (var y = 0; y < height; y += step) {
      for (var x = 0; x < width; x += step) {
        final pixel = edges.getPixel(x, y);

        if (pixel.r >= 90) {
          points.add(
            _Point(
              x.toDouble(),
              y.toDouble(),
            ),
          );
        }
      }
    }

    if (points.length < 40) {
      return null;
    }

    // ----------------------------------------------------------
    // Get extreme points.
    // ----------------------------------------------------------

    final topLeft = _findExtreme(
      points,
      type: _ExtremeType.topLeft,
    );

    final topRight = _findExtreme(
      points,
      type: _ExtremeType.topRight,
    );

    final bottomRight = _findExtreme(
      points,
      type: _ExtremeType.bottomRight,
    );

    final bottomLeft = _findExtreme(
      points,
      type: _ExtremeType.bottomLeft,
    );

    if (topLeft == null ||
        topRight == null ||
        bottomRight == null ||
        bottomLeft == null) {
      return null;
    }

    final candidate = _DocumentCandidate(
      topLeft: topLeft,
      topRight: topRight,
      bottomRight: bottomRight,
      bottomLeft: bottomLeft,
      score: 0,
    );

    if (!_isValidQuad(
      candidate,
      width,
      height,
    )) {
      return null;
    }

    final score = _scoreQuad(
      candidate,
      edges,
      gray,
    );

    if (score < 0.42) {
      return null;
    }

    return _DocumentCandidate(
      topLeft: topLeft,
      topRight: topRight,
      bottomRight: bottomRight,
      bottomLeft: bottomLeft,
      score: score,
    );
  }

  // ============================================================
  // EXTREME POINT SEARCH
  // ============================================================

  static _Point? _findExtreme(
    List<_Point> points, {
    required _ExtremeType type,
  }) {
    if (points.isEmpty) {
      return null;
    }

    _Point best = points.first;
    double bestScore = double.infinity;

    for (final point in points) {
      double score;

      switch (type) {
        case _ExtremeType.topLeft:
          score = point.x + point.y;
          break;

        case _ExtremeType.topRight:
          score = -point.x + point.y;
          break;

        case _ExtremeType.bottomRight:
          score = -point.x - point.y;
          break;

        case _ExtremeType.bottomLeft:
          score = point.x - point.y;
          break;
      }

      if (score < bestScore) {
        bestScore = score;
        best = point;
      }
    }

    return best;
  }

  // ============================================================
  // QUAD VALIDATION
  // ============================================================

  static bool _isValidQuad(
    _DocumentCandidate c,
    int width,
    int height,
  ) {
    final area = _quadArea(c);

    final imageArea = width * height;

    final ratio = area / imageArea;

    // Document should occupy a meaningful part of image.
    if (ratio < 0.20 || ratio > 0.98) {
      return false;
    }

    final top = _distance(
      c.topLeft,
      c.topRight,
    );

    final bottom = _distance(
      c.bottomLeft,
      c.bottomRight,
    );

    final left = _distance(
      c.topLeft,
      c.bottomLeft,
    );

    final right = _distance(
      c.topRight,
      c.bottomRight,
    );

    if (top < width * 0.15 ||
        bottom < width * 0.15 ||
        left < height * 0.15 ||
        right < height * 0.15) {
      return false;
    }

    final horizontalRatio =
        math.min(top, bottom) /
            math.max(top, bottom);

    final verticalRatio =
        math.min(left, right) /
            math.max(left, right);

    // Opposite sides should not be wildly different.
    if (horizontalRatio < 0.55 ||
        verticalRatio < 0.55) {
      return false;
    }

    return true;
  }

  // ============================================================
  // DOCUMENT SCORE
  // ============================================================

  static double _scoreQuad(
    _DocumentCandidate c,
    img.Image edges,
    img.Image gray,
  ) {
    final width = edges.width;
    final height = edges.height;

    final edgeScore = _edgeSupportScore(
      c,
      edges,
    );

    final geometryScore =
        _geometryScore(c);

    final areaRatio =
        _quadArea(c) /
            (width * height);

    double areaScore;

    if (areaRatio >= 0.35 &&
        areaRatio <= 0.90) {
      areaScore = 1.0;
    } else {
      areaScore =
          1.0 -
          ((areaRatio - 0.625).abs() / 0.625);

      areaScore =
          areaScore.clamp(0.0, 1.0);
    }

    return
        (edgeScore * 0.50) +
        (geometryScore * 0.30) +
        (areaScore * 0.20);
  }

  static double _edgeSupportScore(
    _DocumentCandidate c,
    img.Image edges,
  ) {
    final sides = [
      _Line(c.topLeft, c.topRight),
      _Line(c.topRight, c.bottomRight),
      _Line(c.bottomRight, c.bottomLeft),
      _Line(c.bottomLeft, c.topLeft),
    ];

    double total = 0;

    for (final line in sides) {
      var supported = 0;
      var samples = 0;

      final length =
          _distance(
            line.a,
            line.b,
          );

      final count =
          math.max(
            12,
            (length / 8).round(),
          );

      for (var i = 0; i <= count; i++) {
        final t = i / count;

        final x =
            (line.a.x +
                    ((line.b.x - line.a.x) * t))
                .round();

        final y =
            (line.a.y +
                    ((line.b.y - line.a.y) * t))
                .round();

        if (x < 1 ||
            y < 1 ||
            x >= edges.width - 1 ||
            y >= edges.height - 1) {
          continue;
        }

        samples++;

        var localStrong = false;

        // Search a few pixels around expected line.
        for (var oy = -3; oy <= 3; oy++) {
          for (var ox = -3; ox <= 3; ox++) {
            final p =
                edges.getPixel(
              x + ox,
              y + oy,
            );

            if (p.r >= 70) {
              localStrong = true;
              break;
            }
          }

          if (localStrong) {
            break;
          }
        }

        if (localStrong) {
          supported++;
        }
      }

      if (samples > 0) {
        total += supported / samples;
      }
    }

    return total / sides.length;
  }

  static double _geometryScore(
    _DocumentCandidate c,
  ) {
    final top = _distance(
      c.topLeft,
      c.topRight,
    );

    final bottom = _distance(
      c.bottomLeft,
      c.bottomRight,
    );

    final left = _distance(
      c.topLeft,
      c.bottomLeft,
    );

    final right = _distance(
      c.topRight,
      c.bottomRight,
    );

    final horizontal =
        math.min(top, bottom) /
            math.max(top, bottom);

    final vertical =
        math.min(left, right) /
            math.max(left, right);

    return (
      horizontal +
      vertical
    ) /
    2;
  }

  // ============================================================
  // QUAD AREA
  // ============================================================

  static double _quadArea(
    _DocumentCandidate c,
  ) {
    final p = [
      c.topLeft,
      c.topRight,
      c.bottomRight,
      c.bottomLeft,
    ];

    double area = 0;

    for (var i = 0; i < 4; i++) {
      final current = p[i];
      final next = p[(i + 1) % 4];

      area +=
          (current.x * next.y) -
          (next.x * current.y);
    }

    return area.abs() / 2;
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
            .clamp(0, width - 1),
        (p.y + ny * pad)
            .clamp(0, height - 1),
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
  // DISTANCE
  // ============================================================

  static double _distance(
    _Point a,
    _Point b,
  ) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;

    return math.sqrt(
      (dx * dx) +
      (dy * dy),
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

enum _ExtremeType {
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
}

class _Point {
  final double x;
  final double y;

  const _Point(
    this.x,
    this.y,
  );
}

class _Line {
  final _Point a;
  final _Point b;

  const _Line(
    this.a,
    this.b,
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