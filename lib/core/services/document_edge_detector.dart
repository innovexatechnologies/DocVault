import 'dart:math' as math;
import 'dart:typed_data';

// ============================================================
// DOCUMENT EDGE DETECTOR
// ============================================================
//
// The single, shared quadrilateral-detection algorithm used by:
//   - ScanFilterService.autoCrop (full-resolution captured photo)
//   - The live camera-preview overlay (downsampled video frames)
//
// It operates on a plain 8-bit single-channel luminance buffer
// rather than an `image` package `img.Image`, on purpose: that's
// the one representation both callers can produce cheaply --
// ScanFilterService already grayscales its analysis image, and a
// camera YUV420 frame's Y-plane *is* an 8-bit luminance buffer with
// no conversion needed at all. It's also plain data (Uint8List +
// two ints), which makes it safe to hand across an Isolate boundary
// via `compute()` for the live-preview case.
//
// Algorithm: Sobel edge magnitude -> extreme-corner candidate quad
// -> geometric + edge-support scoring -> accept/reject.

/// A simple 2D point. Deliberately not `dart:ui.Offset` so this file
/// has zero Flutter/UI dependency and is trivially safe to use
/// inside a background Isolate.
class EdgePoint {
  final double x;
  final double y;

  const EdgePoint(this.x, this.y);
}

class DetectedQuad {
  final EdgePoint topLeft;
  final EdgePoint topRight;
  final EdgePoint bottomRight;
  final EdgePoint bottomLeft;

  /// 0.0 -> 1.0 confidence that this quad is really a document edge.
  final double score;

  const DetectedQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
    required this.score,
  });

  /// Returns an equivalent quad with every point normalized to the
  /// 0.0 -> 1.0 range against [width]/[height] (the buffer the quad
  /// was detected in).
  DetectedQuad normalized(int width, int height) {
    EdgePoint n(EdgePoint p) =>
        EdgePoint(p.x / width, p.y / height);

    return DetectedQuad(
      topLeft: n(topLeft),
      topRight: n(topRight),
      bottomRight: n(bottomRight),
      bottomLeft: n(bottomLeft),
      score: score,
    );
  }
}

enum _ExtremeType { topLeft, topRight, bottomRight, bottomLeft }

class _Line {
  final EdgePoint a;
  final EdgePoint b;

  const _Line(this.a, this.b);
}

class DocumentEdgeDetector {
  DocumentEdgeDetector._();

  /// Minimum confidence for [detect] to report a quad at all. Kept
  /// as a named constant (rather than inlined) because the live
  /// preview and the final auto-crop intentionally use different
  /// thresholds -- see [minScoreForCrop] / [minScoreForLivePreview].
  static const double minScoreForCrop = 0.42;

  /// The live overlay would flicker constantly at the strict
  /// auto-crop threshold (a hand-held camera's edge signal is
  /// noisier than a still photo), so it accepts slightly weaker
  /// candidates purely for the purpose of drawing a helpful outline.
  /// The final captured photo is always re-analyzed at the full,
  /// stricter [minScoreForCrop] threshold -- this never lowers the
  /// bar for what actually gets cropped.
  static const double minScoreForLivePreview = 0.30;

  /// Detects the strongest document-like quadrilateral in a
  /// single-channel [luminance] buffer of size [width] x [height]
  /// (row-major, one byte per pixel, index = y * width + x).
  ///
  /// Returns `null` if no candidate clears [minScore].
  static DetectedQuad? detect({
    required Uint8List luminance,
    required int width,
    required int height,
    double minScore = minScoreForCrop,
  }) {
    if (width < 20 || height < 20) return null;

    final edges = _sobelEdgeMap(luminance, width, height);

    return _findBestDocumentQuad(
      edges,
      luminance,
      width,
      height,
      minScore,
    );
  }

  /// Pushes every corner of [quad] outward from the quad's center by
  /// a small fixed padding, so the crop doesn't shave off the very
  /// edge of the document. Shared by every caller that turns a
  /// detected quad into an actual crop.
  static DetectedQuad expand(
    DetectedQuad quad,
    int width,
    int height,
  ) {
    final pad = math.min(width, height) * 0.007;

    final center = EdgePoint(
      (quad.topLeft.x +
              quad.topRight.x +
              quad.bottomRight.x +
              quad.bottomLeft.x) /
          4,
      (quad.topLeft.y +
              quad.topRight.y +
              quad.bottomRight.y +
              quad.bottomLeft.y) /
          4,
    );

    EdgePoint push(EdgePoint p) {
      final dx = p.x - center.x;
      final dy = p.y - center.y;

      final length = math.sqrt((dx * dx) + (dy * dy));

      if (length == 0) return p;

      final nx = dx / length;
      final ny = dy / length;

      return EdgePoint(
        (p.x + nx * pad).clamp(0, width - 1).toDouble(),
        (p.y + ny * pad).clamp(0, height - 1).toDouble(),
      );
    }

    return DetectedQuad(
      topLeft: push(quad.topLeft),
      topRight: push(quad.topRight),
      bottomRight: push(quad.bottomRight),
      bottomLeft: push(quad.bottomLeft),
      score: quad.score,
    );
  }

  // ============================================================
  // SOBEL EDGE MAP
  // ============================================================

  static Uint8List _sobelEdgeMap(
    Uint8List luminance,
    int width,
    int height,
  ) {
    final result = Uint8List(width * height);

    const threshold = 22;

    int at(int x, int y) => luminance[y * width + x];

    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final p00 = at(x - 1, y - 1);
        final p01 = at(x, y - 1);
        final p02 = at(x + 1, y - 1);

        final p10 = at(x - 1, y);
        final p12 = at(x + 1, y);

        final p20 = at(x - 1, y + 1);
        final p21 = at(x, y + 1);
        final p22 = at(x + 1, y + 1);

        final gx = (-p00) + p02 + (-2 * p10) + (2 * p12) + (-p20) + p22;

        final gy = (-p00) + (-2 * p01) + (-p02) + p20 + (2 * p21) + p22;

        final magnitude = math.sqrt((gx * gx) + (gy * gy));

        result[y * width + x] = magnitude >= threshold
            ? math.min(255, magnitude.round())
            : 0;
      }
    }

    return result;
  }

  // ============================================================
  // QUAD SEARCH
  // ============================================================

  static DetectedQuad? _findBestDocumentQuad(
    Uint8List edges,
    Uint8List luminance,
    int width,
    int height,
    double minScore,
  ) {
    final points = <EdgePoint>[];

    final step = math.max(2, math.min(width, height) ~/ 450);

    for (var y = 0; y < height; y += step) {
      for (var x = 0; x < width; x += step) {
        if (edges[y * width + x] >= 90) {
          points.add(EdgePoint(x.toDouble(), y.toDouble()));
        }
      }
    }

    if (points.length < 40) return null;

    final topLeft = _findExtreme(points, _ExtremeType.topLeft);
    final topRight = _findExtreme(points, _ExtremeType.topRight);
    final bottomRight =
        _findExtreme(points, _ExtremeType.bottomRight);
    final bottomLeft = _findExtreme(points, _ExtremeType.bottomLeft);

    if (topLeft == null ||
        topRight == null ||
        bottomRight == null ||
        bottomLeft == null) {
      return null;
    }

    final unscored = DetectedQuad(
      topLeft: topLeft,
      topRight: topRight,
      bottomRight: bottomRight,
      bottomLeft: bottomLeft,
      score: 0,
    );

    if (!_isValidQuad(unscored, width, height)) return null;

    final score = _scoreQuad(unscored, edges, width, height);

    if (score < minScore) return null;

    return DetectedQuad(
      topLeft: topLeft,
      topRight: topRight,
      bottomRight: bottomRight,
      bottomLeft: bottomLeft,
      score: score,
    );
  }

  static EdgePoint? _findExtreme(
    List<EdgePoint> points,
    _ExtremeType type,
  ) {
    if (points.isEmpty) return null;

    EdgePoint best = points.first;
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
  // VALIDATION + SCORING
  // ============================================================

  static bool _isValidQuad(
    DetectedQuad c,
    int width,
    int height,
  ) {
    final area = _quadArea(c);
    final imageArea = width * height;
    final ratio = area / imageArea;

    if (ratio < 0.20 || ratio > 0.98) return false;

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

    final horizontalRatio =
        math.min(top, bottom) / math.max(top, bottom);
    final verticalRatio =
        math.min(left, right) / math.max(left, right);

    if (horizontalRatio < 0.55 || verticalRatio < 0.55) {
      return false;
    }

    return true;
  }

  static double _scoreQuad(
    DetectedQuad c,
    Uint8List edges,
    int width,
    int height,
  ) {
    final edgeScore = _edgeSupportScore(c, edges, width, height);
    final geometryScore = _geometryScore(c);

    final areaRatio = _quadArea(c) / (width * height);

    double areaScore;

    if (areaRatio >= 0.35 && areaRatio <= 0.90) {
      areaScore = 1.0;
    } else {
      areaScore = 1.0 - ((areaRatio - 0.625).abs() / 0.625);
      areaScore = areaScore.clamp(0.0, 1.0).toDouble();
    }

    return (edgeScore * 0.50) +
        (geometryScore * 0.30) +
        (areaScore * 0.20);
  }

  static double _edgeSupportScore(
    DetectedQuad c,
    Uint8List edges,
    int width,
    int height,
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

        final x =
            (line.a.x + ((line.b.x - line.a.x) * t)).round();
        final y =
            (line.a.y + ((line.b.y - line.a.y) * t)).round();

        if (x < 1 || y < 1 || x >= width - 1 || y >= height - 1) {
          continue;
        }

        samples++;

        var localStrong = false;

        for (var oy = -3; oy <= 3 && !localStrong; oy++) {
          for (var ox = -3; ox <= 3; ox++) {
            final px = x + ox;
            final py = y + oy;

            if (px < 0 || py < 0 || px >= width || py >= height) {
              continue;
            }

            if (edges[py * width + px] >= 70) {
              localStrong = true;
              break;
            }
          }
        }

        if (localStrong) supported++;
      }

      if (samples > 0) total += supported / samples;
    }

    return total / sides.length;
  }

  static double _geometryScore(DetectedQuad c) {
    final top = _distance(c.topLeft, c.topRight);
    final bottom = _distance(c.bottomLeft, c.bottomRight);
    final left = _distance(c.topLeft, c.bottomLeft);
    final right = _distance(c.topRight, c.bottomRight);

    final horizontal = math.min(top, bottom) / math.max(top, bottom);
    final vertical = math.min(left, right) / math.max(left, right);

    return (horizontal + vertical) / 2;
  }

  static double _quadArea(DetectedQuad c) {
    final p = [c.topLeft, c.topRight, c.bottomRight, c.bottomLeft];

    double area = 0;

    for (var i = 0; i < 4; i++) {
      final current = p[i];
      final next = p[(i + 1) % 4];

      area += (current.x * next.y) - (next.x * current.y);
    }

    return area.abs() / 2;
  }

  static double _distance(EdgePoint a, EdgePoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;

    return math.sqrt((dx * dx) + (dy * dy));
  }
}
