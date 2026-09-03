import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'document_edge_detector.dart';

// ============================================================
// LIVE FRAME ANALYSIS (top-level, Isolate-safe)
// ============================================================
//
// Everything below needs to be safe to run inside a background
// Isolate via `compute()`, so no Flutter/UI types.

/// A pre-downsampled, plain-luminance snapshot of one camera frame,
/// already extracted from the platform-specific YUV420/BGRA8888
/// buffer on the UI isolate (that extraction has to happen there,
/// since the original camera buffer isn't safe to touch off-isolate
/// or after the stream callback returns) -- everything from here on
/// is cheap, portable pixel math that can run in the background.
@immutable
class _FrameSample {
  final Uint8List luminance;
  final int width;
  final int height;

  /// Degrees the raw sensor frame must be rotated clockwise to
  /// appear upright in the device's natural (portrait) orientation.
  /// Comes straight from `CameraDescription.sensorOrientation`.
  final int sensorOrientationDegrees;

  const _FrameSample({
    required this.luminance,
    required this.width,
    required this.height,
    required this.sensorOrientationDegrees,
  });
}

/// A quad detected in a live frame, already rotated into
/// upright-portrait, 0.0 -> 1.0 normalized coordinates -- i.e.
/// directly usable to position an overlay on top of `CameraPreview`
/// without any further math about sensor orientation.
class LiveDetectedQuad {
  final EdgePoint topLeft;
  final EdgePoint topRight;
  final EdgePoint bottomRight;
  final EdgePoint bottomLeft;
  final double score;

  const LiveDetectedQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
    required this.score,
  });
}

/// Rotates a normalized (0..1) point clockwise by a multiple of 90
/// degrees within the unit square. Used to map a point detected in
/// raw sensor-frame space into upright-display space.
EdgePoint _rotateNormalizedCW(EdgePoint p, int degrees) {
  switch (degrees % 360) {
    case 90:
      return EdgePoint(1 - p.y, p.x);
    case 180:
      return EdgePoint(1 - p.x, 1 - p.y);
    case 270:
      return EdgePoint(p.y, 1 - p.x);
    default:
      return p;
  }
}

/// Runs the shared [DocumentEdgeDetector] against a single
/// downsampled frame and returns the result already rotated into
/// upright-display normalized coordinates. This is the function
/// actually executed inside the background Isolate spawned by
/// `compute()` -- it MUST be a top-level (or static) function.
LiveDetectedQuad? analyzeFrameSample(_FrameSample frame) {
  final quad = DocumentEdgeDetector.detect(
    luminance: frame.luminance,
    width: frame.width,
    height: frame.height,
    minScore: DocumentEdgeDetector.minScoreForLivePreview,
  );

  if (quad == null) return null;

  final normalized = quad.normalized(frame.width, frame.height);

  EdgePoint r(EdgePoint p) =>
      _rotateNormalizedCW(p, frame.sensorOrientationDegrees);

  return LiveDetectedQuad(
    topLeft: r(normalized.topLeft),
    topRight: r(normalized.topRight),
    bottomRight: r(normalized.bottomRight),
    bottomLeft: r(normalized.bottomLeft),
    score: normalized.score,
  );
}

// ============================================================
// CAMERA SERVICE
// ============================================================

class CameraService {
  late CameraController _controller;
  late List<CameraDescription> _cameras;
  bool _isInitialized = false;

  bool _isStreamingForDetection = false;
  bool _frameBusy = false;
  DateTime _lastFrameProcessed =
      DateTime.fromMillisecondsSinceEpoch(0);

  bool get isInitialized => _isInitialized;
  CameraController get controller => _controller;

  Future<void> initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('No camera available');
      }

      final firstCamera = _cameras.first;

      _controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      rethrow;
    }
  }

  Future<XFile?> capturePhoto() async {
    if (!_isInitialized) {
      throw Exception('Camera not initialized');
    }

    try {
      final image = await _controller.takePicture();
      return image;
    } catch (e) {
      debugPrint('Capture error: $e');
      rethrow;
    }
  }

  // ============================================================
  // LIVE DOCUMENT-EDGE DETECTION
  // ============================================================
  //
  // Streams camera frames, downsamples + extracts luminance on the
  // UI isolate (cheap -- just stride-skipping array reads, no
  // decoding), then runs the actual Sobel/quad-search work in a
  // background Isolate via `compute()` so a slow frame never drops
  // the preview's frame rate. Frames are throttled: if a previous
  // analysis is still running, or not enough time has passed since
  // the last one, the new frame is simply skipped.

  /// Width (in pixels) the analysis buffer is downsampled to before
  /// detection runs. Kept small on purpose: this only needs to be
  /// good enough to draw a helpful outline, not to produce the final
  /// crop (the real auto-crop re-analyzes the full-resolution photo).
  static const int _analysisTargetWidth = 220;

  Future<void> startLiveDetection({
    required void Function(LiveDetectedQuad? quad) onQuadDetected,
    Duration throttle = const Duration(milliseconds: 350),
  }) async {
    if (!_isInitialized || _isStreamingForDetection) return;

    if (_controller.value.isStreamingImages) return;

    _isStreamingForDetection = true;

    final sensorOrientation =
        _controller.description.sensorOrientation;

    await _controller.startImageStream((image) {
      final now = DateTime.now();

      if (_frameBusy ||
          now.difference(_lastFrameProcessed) < throttle) {
        return;
      }

      final sample = _extractDownsampledLuminance(
        image,
        sensorOrientation,
      );

      if (sample == null) return;

      _frameBusy = true;
      _lastFrameProcessed = now;

      compute(analyzeFrameSample, sample)
          .then((quad) {
        _frameBusy = false;
        onQuadDetected(quad);
      })
          .catchError((Object _) {
        // A single bad frame shouldn't kill the live preview --
        // just skip it and let the next frame try again.
        _frameBusy = false;
      });
    });
  }

  Future<void> stopLiveDetection() async {
    if (_isStreamingForDetection &&
        _controller.value.isStreamingImages) {
      await _controller.stopImageStream();
    }

    _isStreamingForDetection = false;
    _frameBusy = false;
  }

  /// Synchronously (must stay on the UI isolate -- the source
  /// [CameraImage] buffer isn't valid once this callback returns)
  /// samples [image] down to a small luminance buffer.
  ///
  /// Handles the two formats the `camera` plugin actually delivers:
  /// YUV420 (Android) where the Y-plane already IS luminance, and
  /// BGRA8888 (iOS) where luminance is computed from B/G/R.
  _FrameSample? _extractDownsampledLuminance(
    CameraImage image,
    int sensorOrientationDegrees,
  ) {
    final srcWidth = image.width;
    final srcHeight = image.height;

    if (srcWidth <= 0 || srcHeight <= 0) return null;

    final targetWidth = _analysisTargetWidth
        .clamp(1, srcWidth)
        .toInt();

    final targetHeight =
        (srcHeight * targetWidth / srcWidth).round().clamp(
              1,
              srcHeight,
            ).toInt();

    final out = Uint8List(targetWidth * targetHeight);

    switch (image.format.group) {
      case ImageFormatGroup.yuv420:
        final plane = image.planes.first;
        final bytes = plane.bytes;
        final stride = plane.bytesPerRow;

        for (var ty = 0; ty < targetHeight; ty++) {
          final sy = (ty * srcHeight ~/ targetHeight)
              .clamp(0, srcHeight - 1)
              .toInt();

          final rowOffset = sy * stride;

          for (var tx = 0; tx < targetWidth; tx++) {
            final sx = (tx * srcWidth ~/ targetWidth)
                .clamp(0, srcWidth - 1)
                .toInt();

            final index = rowOffset + sx;

            out[ty * targetWidth + tx] =
                index < bytes.length ? bytes[index] : 0;
          }
        }
        break;

      case ImageFormatGroup.bgra8888:
        final plane = image.planes.first;
        final bytes = plane.bytes;
        final stride = plane.bytesPerRow;

        for (var ty = 0; ty < targetHeight; ty++) {
          final sy = (ty * srcHeight ~/ targetHeight)
              .clamp(0, srcHeight - 1)
              .toInt();

          final rowOffset = sy * stride;

          for (var tx = 0; tx < targetWidth; tx++) {
            final sx = (tx * srcWidth ~/ targetWidth)
                .clamp(0, srcWidth - 1)
                .toInt();

            final index = rowOffset + (sx * 4);

            if (index + 2 >= bytes.length) {
              out[ty * targetWidth + tx] = 0;
              continue;
            }

            final b = bytes[index];
            final g = bytes[index + 1];
            final r = bytes[index + 2];

            out[ty * targetWidth + tx] =
                ((r * 0.299) + (g * 0.587) + (b * 0.114))
                    .round()
                    .clamp(0, 255)
                    .toInt();
          }
        }
        break;

      default:
        // Unsupported format for this device/platform -- skip this
        // frame rather than guess at a conversion.
        return null;
    }

    return _FrameSample(
      luminance: out,
      width: targetWidth,
      height: targetHeight,
      sensorOrientationDegrees: sensorOrientationDegrees,
    );
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await stopLiveDetection();
      await _controller.dispose();
      _isInitialized = false;
    }
  }
}
