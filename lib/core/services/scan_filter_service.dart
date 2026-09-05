import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'image_editor_service.dart';

import 'image_processing_worker.dart';

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

/// ============================================================
/// FILTER CACHE - Store recently applied filters
/// ============================================================

class _FilterCache {
  final Map<String, Uint8List> _cache = {};
  static const maxCacheSize = 5;

  String _getCacheKey(ScanFilter filter, int imageIdentity, int byteLength) {
    return '${filter.toString()}_${byteLength}_$imageIdentity';
  }

  Uint8List? get(ScanFilter filter, Uint8List bytes) {
    final key = _getCacheKey(filter, identityHashCode(bytes), bytes.length);
    return _cache[key];
  }

  void set(ScanFilter filter, Uint8List bytes, Uint8List result) {
    if (_cache.length >= maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    final key = _getCacheKey(filter, identityHashCode(bytes), bytes.length);
    _cache[key] = result;
  }

  void clear() {
    _cache.clear();
  }
}

final _cache = _FilterCache();

/// ============================================================
/// MAIN SERVICE
/// ============================================================

class ScanFilterService {
  /// Warms up the shared background worker. Safe to call at startup;
  /// individual apply() calls also (re)start it lazily.
  static Future<void> initialize() async {
    await ImageProcessingWorker.instance.ensureStarted();
  }

  static void dispose() {
    ImageProcessingWorker.instance.dispose();
    _cache.clear();
  }

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

    final gray = img.grayscale(analysis);

    final enhanced = img.adjustColor(
      gray,
      contrast: 1.15,
      brightness: 1.02,
    );

    final edgeMap = _buildEdgeMap(enhanced);

    final candidate = _findBestDocumentQuad(
      edgeMap,
      enhanced,
    );

    if (candidate == null) {
      return inputBytes;
    }

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

    final expanded = _expandQuad(
      topLeft,
      topRight,
      bottomRight,
      bottomLeft,
      original.width,
      original.height,
    );

    final docWidth = math.max(
      _distance(expanded.topLeft, expanded.topRight),
      _distance(expanded.bottomLeft, expanded.bottomRight),
    ).round();

    final docHeight = math.max(
      _distance(expanded.topLeft, expanded.bottomLeft),
      _distance(expanded.topRight, expanded.bottomRight),
    ).round();

    if (docWidth < 2 || docHeight < 2) {
      return inputBytes;
    }

    // Rectification allocates the complete destination image. Keep the
    // result bounded so a high-resolution camera frame or a noisy edge
    // candidate cannot allocate an unbounded bitmap in the worker isolate.
    const maxOutputDimension = 4000;
    final outputScale = math.min(
      1.0,
      maxOutputDimension / math.max(docWidth, docHeight),
    );
    final outputWidth = math.max(50, (docWidth * outputScale).round());
    final outputHeight = math.max(50, (docHeight * outputScale).round());

    final targetImage = img.Image(
      width: outputWidth,
      height: outputHeight,
    );

    img.Image rectified;
    try {
      rectified = img.copyRectify(
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
    } catch (_) {
      // Detection is best-effort. A failed rectify must leave the source
      // usable instead of turning Auto Crop into a fatal edit operation.
      return inputBytes;
    }

    if (rectified.width < 50 || rectified.height < 50) {
      return inputBytes;
    }

    return Uint8List.fromList(
      img.encodeJpg(rectified, quality: 95),
    );
  }

  // ============================================================
  // MAIN FILTER APPLICATION - WITH CACHING
  // ============================================================
  //
  // IMPORTANT (overlap fix): `inputBytes` passed here must ALWAYS be
  // the ORIGINAL, unmodified image bytes — never the result of a
  // previously applied filter. If your UI/widget code keeps
  // overwriting the "current image" variable with each filter result
  // and then passes that into apply() again, filters will visually
  // stack/overlap on top of each other. Keep a separate, never
  // mutated `originalBytes` variable and always call:
  //   apply(selectedFilter, originalBytes)
  // ============================================================

  static Future<Uint8List> apply(
    ScanFilter filter,
    Uint8List inputBytes,
  ) async {
    if (filter == ScanFilter.original) {
      return inputBytes;
    }

    // Check cache first. The key is based on the identity of the input
    // bytes object, so re-tapping the same filter on the same bytes is
    // instant and byte-for-byte identical.
    final cached = _cache.get(filter, inputBytes);
    if (cached != null) {
      return cached;
    }

    // Route the work through the shared background worker isolate:
    //   * the UI thread is never blocked (no more ANR/crash),
    //   * temp files are used instead of shipping full-resolution
    //     bytes over a SendPort (no more memory blow-ups),
    //   * results are matched by job id, so a stale filter result can
    //     never overwrite a newer selection (no more overlapping).
    final tempDir = Directory.systemTemp;
    final stamp = '${DateTime.now().microsecondsSinceEpoch}_'
        '${identityHashCode(inputBytes)}';

    final inputPath = '${tempDir.path}/scan_filter_in_$stamp.jpg';
    final outputPath = '${tempDir.path}/scan_filter_out_$stamp.jpg';

    Uint8List result;

    try {
      await File(inputPath).writeAsBytes(inputBytes, flush: true);

      await ImageProcessingWorker.instance.applyFilter(
        inputPath,
        _toImageFilter(filter),
        outputPath,
      );

      result = await File(outputPath).readAsBytes();
    } finally {
      final inFile = File(inputPath);
      final outFile = File(outputPath);

      if (await inFile.exists()) {
        try {
          await inFile.delete();
        } catch (_) {}
      }

      if (await outFile.exists()) {
        try {
          await outFile.delete();
        } catch (_) {}
      }
    }

    _cache.set(filter, inputBytes, result);

    return result;
  }

  /// Maps the legacy [ScanFilter] enum onto the shared
  /// [ImageFilterType] so a single code path (and a single worker)
  /// processes every filter.
  static ImageFilterType _toImageFilter(ScanFilter filter) {
    switch (filter) {
      case ScanFilter.original:
        return ImageFilterType.none;
      case ScanFilter.grayscale:
        return ImageFilterType.grayscale;
      case ScanFilter.blackAndWhite:
        return ImageFilterType.blackAndWhite;
      case ScanFilter.enhance:
        return ImageFilterType.enhance;
      case ScanFilter.sharpen:
        return ImageFilterType.sharpen;
      case ScanFilter.vivid:
        return ImageFilterType.vivid;
      case ScanFilter.softLight:
        return ImageFilterType.softLight;
      case ScanFilter.warmTone:
        return ImageFilterType.warmTone;
      case ScanFilter.coolTone:
        return ImageFilterType.coolTone;
      case ScanFilter.highContrastBW:
        return ImageFilterType.highContrastBW;
      case ScanFilter.softBW:
        return ImageFilterType.softBW;
      case ScanFilter.sepia:
        return ImageFilterType.sepia;
      case ScanFilter.noirDramatic:
        return ImageFilterType.noirDramatic;
      case ScanFilter.brightWhite:
        return ImageFilterType.brightWhite;
      case ScanFilter.lowLightBoost:
        return ImageFilterType.lowLightBoost;
      case ScanFilter.matte:
        return ImageFilterType.matte;
      case ScanFilter.vintagePaper:
        return ImageFilterType.vintagePaper;
      case ScanFilter.coldSteel:
        return ImageFilterType.coldSteel;
      case ScanFilter.magicColorPro:
        return ImageFilterType.magicColorPro;
      case ScanFilter.invertNegative:
        return ImageFilterType.invertNegative;
      case ScanFilter.cleanDocument:
        return ImageFilterType.cleanDocument;
    }
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

        final gx = (-p00) +
            p02 +
            (-2 * p10) +
            (2 * p12) +
            (-p20) +
            p22;

        final gy = (-p00) +
            (-2 * p01) +
            (-p02) +
            p20 +
            (2 * p21) +
            p22;

        final magnitude = math.sqrt((gx * gx) + (gy * gy));

        final value = magnitude >= threshold
            ? math.min(255, magnitude.round())
            : 0;

        result.setPixelRgba(x, y, value, value, value, 255);
      }
    }

    return result;
  }

  static int _gray(img.Image image, int x, int y) {
    final pixel = image.getPixel(x, y);

    return ((pixel.r * 0.299) + (pixel.g * 0.587) + (pixel.b * 0.114))
        .round();
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

    final step = math.max(2, math.min(width, height) ~/ 450);

    for (var y = 0; y < height; y += step) {
      for (var x = 0; x < width; x += step) {
        final pixel = edges.getPixel(x, y);

        if (pixel.r >= 90) {
          points.add(_Point(x.toDouble(), y.toDouble()));
        }
      }
    }

    if (points.length < 40) {
      return null;
    }

    final topLeft =
        _findExtreme(points, type: _ExtremeType.topLeft);

    final topRight =
        _findExtreme(points, type: _ExtremeType.topRight);

    final bottomRight =
        _findExtreme(points, type: _ExtremeType.bottomRight);

    final bottomLeft =
        _findExtreme(points, type: _ExtremeType.bottomLeft);

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

    if (!_isValidQuad(candidate, width, height)) {
      return null;
    }

    final score = _scoreQuad(candidate, edges, gray);

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

  static bool _isValidQuad(
    _DocumentCandidate c,
    int width,
    int height,
  ) {
    final area = _quadArea(c);
    final imageArea = width * height;
    final ratio = area / imageArea;

    if (ratio < 0.20 || ratio > 0.98) {
      return false;
    }

    final top = _distance(c.topLeft, c.topRight);
    final bottom = _distance(c.bottomLeft, c.bottomRight);
    final left = _distance(c.topLeft, c.bottomLeft);
    final right = _distance(c.topRight, c.bottomRight);

    if (top < width * 0.15 ||
        bottom < width * 0.15 ||
        left < height * 0.15 ||
        right < height * 0.15) {
      return false;
    }

    final horizontalRatio = math.min(top, bottom) / math.max(top, bottom);
    final verticalRatio = math.min(left, right) / math.max(left, right);

    if (horizontalRatio < 0.55 || verticalRatio < 0.55) {
      return false;
    }

    return true;
  }

  static double _scoreQuad(
    _DocumentCandidate c,
    img.Image edges,
    img.Image gray,
  ) {
    final width = edges.width;
    final height = edges.height;

    final edgeScore = _edgeSupportScore(c, edges);
    final geometryScore = _geometryScore(c);
    final areaRatio = _quadArea(c) / (width * height);

    double areaScore;

    if (areaRatio >= 0.35 && areaRatio <= 0.90) {
      areaScore = 1.0;
    } else {
      areaScore = 1.0 - ((areaRatio - 0.625).abs() / 0.625);
      areaScore = areaScore.clamp(0.0, 1.0);
    }

    return (edgeScore * 0.50) + (geometryScore * 0.30) + (areaScore * 0.20);
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

      final length = _distance(line.a, line.b);
      final count = math.max(12, (length / 8).round());

      for (var i = 0; i <= count; i++) {
        final t = i / count;

        final x = (line.a.x + ((line.b.x - line.a.x) * t)).round();
        final y = (line.a.y + ((line.b.y - line.a.y) * t)).round();

        if (x < 1 ||
            y < 1 ||
            x >= edges.width - 1 ||
            y >= edges.height - 1) {
          continue;
        }

        samples++;

        var localStrong = false;

        for (var oy = -3; oy <= 3; oy++) {
          for (var ox = -3; ox <= 3; ox++) {
            final p = edges.getPixel(x + ox, y + oy);

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

  static double _geometryScore(_DocumentCandidate c) {
    final top = _distance(c.topLeft, c.topRight);
    final bottom = _distance(c.bottomLeft, c.bottomRight);
    final left = _distance(c.topLeft, c.bottomLeft);
    final right = _distance(c.topRight, c.bottomRight);

    final horizontal = math.min(top, bottom) / math.max(top, bottom);
    final vertical = math.min(left, right) / math.max(left, right);

    return (horizontal + vertical) / 2;
  }

  static double _quadArea(_DocumentCandidate c) {
    final p = [c.topLeft, c.topRight, c.bottomRight, c.bottomLeft];

    double area = 0;

    for (var i = 0; i < 4; i++) {
      final current = p[i];
      final next = p[(i + 1) % 4];

      area += (current.x * next.y) - (next.x * current.y);
    }

    return area.abs() / 2;
  }

  static _DocumentCandidate _expandQuad(
    _Point topLeft,
    _Point topRight,
    _Point bottomRight,
    _Point bottomLeft,
    int width,
    int height,
  ) {
    final pad = math.min(width, height) * 0.007;

    final center = _Point(
      (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) / 4,
      (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) / 4,
    );

    _Point expand(_Point p) {
      final dx = p.x - center.x;
      final dy = p.y - center.y;

      final length = math.sqrt((dx * dx) + (dy * dy));

      if (length == 0) {
        return p;
      }

      final nx = dx / length;
      final ny = dy / length;

      return _Point(
        (p.x + nx * pad).clamp(0, width - 1),
        (p.y + ny * pad).clamp(0, height - 1),
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

  static double _distance(_Point a, _Point b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;

    return math.sqrt((dx * dx) + (dy * dy));
  }

  // (filter implementations removed — the live app uses the shared
  // ImageFilterType path via ImageProcessingWorker / ImageEditorService)

  

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

// ============================================================
// SUPPORT CLASSES
// ============================================================

enum _ExtremeType { topLeft, topRight, bottomRight, bottomLeft }

class _Point {
  final double x;
  final double y;

  const _Point(this.x, this.y);
}

class _Line {
  final _Point a;
  final _Point b;

  const _Line(this.a, this.b);
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
