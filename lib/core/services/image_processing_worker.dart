import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'image_editor_service.dart';
import 'scan_filter_service.dart';

/// Maximum length (in pixels) of the longest side an image may have
/// before it is automatically downscaled BEFORE filtering.
///
/// - Normal 12–16 MP photos (4032×3024 and smaller) are NEVER touched.
/// - Huge 48/64/108 MP camera frames and panoramic shots are
///   downscaled first so a single filter cannot exhaust the memory of
///   a low-end phone or block processing for tens of seconds.
/// - The value is still far above typical A4/Letter scan output
///   (300 DPI A4 ≈ 2480×3508), so documents keep their quality.
const int kMaxFilterProcessingDimension = 4000;

/// A single, serial, path-based image-processing worker isolate.
///
/// Why path-based instead of byte-based:
/// - The caller never ships raw JPEG bytes through the SendPort, so we
///   avoid the 2–3× memory copies that used to OOM low-end phones.
/// - The worker reads `inputPath`, processes it and writes the result
///   to a pre-computed `outputPath`, then replies with only a small
///   three-element message.
/// - Jobs are identified by an integer id, so results are matched to
///   the exact request and stale/late results are dropped. This makes
///   it impossible for an old filter result to overwrite a newer one
///   (the classic "filters overlapping on top of each other" race).
class ImageProcessingWorker {
  ImageProcessingWorker._();

  static final ImageProcessingWorker instance = ImageProcessingWorker._();

  SendPort? _sendPort;
  Isolate? _isolate;
  ReceivePort? _controlPort;

  int _nextJobId = 1;
  final Map<int, Completer<ImageProcessingWorkerResult>> _pending = {};

  /// Like [start] but idempotent — safe to call on every use.
  Future<void> ensureStarted() => start();

  /// Spawns the worker isolate (or re-spawns it after [dispose]).
  Future<void> start() async {
    if (_sendPort != null) return;

    final control = ReceivePort();
    _controlPort = control;

    final ready = Completer<void>();

    control.listen((dynamic message) {
      if (message is SendPort) {
        // First message from the worker is its reply port.
        _sendPort = message;
        if (!ready.isCompleted) {
          ready.complete();
        }
        return;
      }

      if (message is List && message.length == 3) {
        final jobId = message[0] as int;
        final completer = _pending.remove(jobId);
        if (completer == null) return; // Stale result -> drop it.
        completer.complete(
          ImageProcessingWorkerResult(
            outputPath: message[1] as String?,
            error: message[2] as String?,
          ),
        );
      }
    });

    final isolate = await Isolate.spawn<SendPort>(_entry, control.sendPort);
    _isolate = isolate;

    await ready.future;
  }
/// Applies [filter] to [inputPath] and writes the result to
  /// [outputPath]. Returns [outputPath] on success.
  Future<String> applyFilter(
    String inputPath,
    ImageFilterType filter,
    String outputPath,
  ) async {
    final result = await _submit(
      inputPath,
      outputPath,
      'filter',
      filter.index,
    );

    if (!result.isSuccess) {
      throw ImageProcessingException(
        result.error ?? 'Filter processing failed.',
      );
    }

    return result.outputPath!;
  }

  /// Auto-crops [inputPath] to the detected document region and writes
  /// the result to [outputPath]. Returns [outputPath] on success.
  Future<String> autoCrop(
    String inputPath,
    String outputPath,
  ) async {
    final result = await _submit(inputPath, outputPath, 'autocrop', 0);

    if (!result.isSuccess) {
      throw ImageProcessingException(
        result.error ?? 'Auto crop failed.',
      );
    }

    return result.outputPath!;
  }

  Future<String> crop(
    String inputPath,
    String outputPath, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    final result = await _submit(
      inputPath,
      outputPath,
      'crop',
      0,
      [x, y, width, height],
    );

    if (!result.isSuccess) {
      throw ImageProcessingException(
        result.error ?? 'Crop processing failed.',
      );
    }

    return result.outputPath!;
  }

  Future<String> cropNormalized(
    String inputPath,
    String outputPath, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) async {
    final result = await _submit(
      inputPath,
      outputPath,
      'cropNormalized',
      0,
      [left, top, right, bottom],
    );

    if (!result.isSuccess) {
      throw ImageProcessingException(
        result.error ?? 'Crop processing failed.',
      );
    }

    return result.outputPath!;
  }

  Future<ImageProcessingWorkerResult> _submit(
    String inputPath,
    String outputPath,
    String operation,
    int param,
    [
      List<num> arguments = const [],
    ]
  ) async {
    await start();

    final jobId = _nextJobId++;
    final completer = Completer<ImageProcessingWorkerResult>();
    _pending[jobId] = completer;

    _sendPort!.send([
      jobId,
      inputPath,
      outputPath,
      operation,
      param,
      arguments,
    ]);

    // Safety net: if the worker isolate ever dies mid-job, the caller
    // must still get an answer so the UI never hangs on a spinner.
    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _pending.remove(jobId);
        return const ImageProcessingWorkerResult(
          error: 'Image processing timed out.',
        );
      },
    );
  }

  void dispose() {
    _isolate?.kill();
    _isolate = null;
    _sendPort = null;

    if (_controlPort != null) {
      _controlPort!.close();
      _controlPort = null;
    }

    for (final completer in _pending.values) {
      completer.complete(
        const ImageProcessingWorkerResult(error: 'Worker was disposed.'),
      );
    }

    _pending.clear();
  }
}

class ImageProcessingWorkerResult {
  const ImageProcessingWorkerResult({this.outputPath, this.error});

  final String? outputPath;
  final String? error;

  bool get isSuccess => error == null && outputPath != null;
}

class ImageProcessingException implements Exception {
  ImageProcessingException(this.message);

  final String message;

  @override
  String toString() => message;
}
/// Worker isolate entry point.
///
/// Processes incoming jobs one at a time (serial), reads the input
/// file itself, and replies with `[jobId, outputPath, error]`.
Future<void> _entry(SendPort mainPort) async {
  final port = ReceivePort();
  mainPort.send(port.sendPort);

  await for (final dynamic message in port) {
    if (message is List && message.length == 6) {
      final jobId = message[0] as int;
      final inputPath = message[1] as String;
      final outputPath = message[2] as String;
      final operation = message[3] as String;
      final param = message[4] as int;
      final arguments = (message[5] as List).cast<num>();

      try {
        await _runJob(
          inputPath,
          outputPath,
          operation,
          param,
          arguments,
        );
        mainPort.send([jobId, outputPath, null]);
      } catch (e) {
        mainPort.send([jobId, null, '$e']);
      }
    }
  }
}

Future<void> _runJob(
  String inputPath,
  String outputPath,
  String operation,
  int param,
  List<num> arguments,
) async {
  final file = File(inputPath);

  if (!await file.exists()) {
    throw ImageProcessingException(
      'Input image does not exist: $inputPath',
    );
  }

  final bytes = await file.readAsBytes();

  switch (operation) {
    case 'filter':
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw ImageProcessingException(
          'Could not decode image: $inputPath',
        );
      }

      if (param < 0 || param >= ImageFilterType.values.length) {
        throw ImageProcessingException('Unknown filter: $param');
      }

      final filter = ImageFilterType.values[param];

      if (filter == ImageFilterType.none) {
        throw ImageProcessingException(
          'Cannot apply "original" through the worker.',
        );
      }

      final work = _applyResolutionGuard(decoded);
      final filtered = ImageEditorService.applyFilterToImage(work, filter);

      final outBytes = Uint8List.fromList(
        img.encodeJpg(filtered, quality: 92),
      );

      await File(outputPath).writeAsBytes(outBytes, flush: true);
      break;

    case 'autocrop':
      final cropped = ScanFilterService.autoCrop(bytes);

      if (cropped == bytes) {
        // No reliable document corner was detected — save the
        // untouched (but resolution-guarded) image so the caller
        // always gets a valid file.
        final decoded = img.decodeImage(bytes);

        if (decoded == null) {
          throw ImageProcessingException(
            'Could not decode image: $inputPath',
          );
        }

        final work = _applyResolutionGuard(decoded);
        final fallback = Uint8List.fromList(
          img.encodeJpg(work, quality: 95),
        );

        await File(outputPath).writeAsBytes(fallback, flush: true);
      } else {
        await File(outputPath).writeAsBytes(cropped, flush: true);
      }
      break;

    case 'crop':
      if (arguments.length != 4) {
        throw ImageProcessingException('Invalid crop arguments.');
      }

      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw ImageProcessingException(
          'Could not decode image: $inputPath',
        );
      }

      final x = arguments[0].toInt();
      final y = arguments[1].toInt();
      final width = arguments[2].toInt();
      final height = arguments[3].toInt();

      if (width <= 0 || height <= 0) {
        throw ImageProcessingException(
          'Crop width and height must be greater than zero.',
        );
      }

      final safeX = x.clamp(0, decoded.width - 1);
      final safeY = y.clamp(0, decoded.height - 1);
      final safeWidth = width.clamp(1, decoded.width - safeX);
      final safeHeight = height.clamp(1, decoded.height - safeY);

      final cropped = img.copyCrop(
        decoded,
        x: safeX,
        y: safeY,
        width: safeWidth,
        height: safeHeight,
      );

      await File(outputPath).writeAsBytes(
        img.encodePng(cropped),
        flush: true,
      );
      break;

    case 'cropNormalized':
      if (arguments.length != 4 ||
          arguments.any((value) => !value.isFinite)) {
        throw ImageProcessingException('Invalid crop coordinates.');
      }

      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw ImageProcessingException(
          'Could not decode image: $inputPath',
        );
      }

      final l = arguments[0].toDouble().clamp(0.0, 1.0).toDouble();
      final t = arguments[1].toDouble().clamp(0.0, 1.0).toDouble();
      final r = arguments[2].toDouble().clamp(0.0, 1.0).toDouble();
      final b = arguments[3].toDouble().clamp(0.0, 1.0).toDouble();

      if (r <= l || b <= t) {
        throw ImageProcessingException('Invalid crop rectangle.');
      }

      final x0 = (l * decoded.width).round().clamp(0, decoded.width - 1);
      final y0 = (t * decoded.height).round().clamp(0, decoded.height - 1);
      final x1 = (r * decoded.width).round().clamp(x0 + 1, decoded.width);
      final y1 = (b * decoded.height).round().clamp(y0 + 1, decoded.height);

      final cropped = img.copyCrop(
        decoded,
        x: x0,
        y: y0,
        width: x1 - x0,
        height: y1 - y0,
      );

      await File(outputPath).writeAsBytes(
        img.encodePng(cropped),
        flush: true,
      );
      break;

    default:
      throw ImageProcessingException('Unknown operation: $operation');
  }
}

/// If the image is wider/taller than [kMaxFilterProcessingDimension],
/// downscale it (keeping the aspect ratio) before any processing so a
/// huge camera frame can never freeze or crash the worker.
img.Image _applyResolutionGuard(img.Image image) {
  final longest = image.width >= image.height ? image.width : image.height;

  if (longest <= kMaxFilterProcessingDimension) {
    return image;
  }

  final scale = kMaxFilterProcessingDimension / longest;

  return img.copyResize(
    image,
    width: (image.width * scale).round(),
    height: (image.height * scale).round(),
    interpolation: img.Interpolation.linear,
  );
}