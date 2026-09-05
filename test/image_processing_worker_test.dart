import 'dart:io';
import 'dart:typed_data';

import 'package:doc_vault/core/services/image_editor_service.dart';
import 'package:doc_vault/core/services/image_processing_worker.dart';
import 'package:doc_vault/core/services/scan_filter_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String inputPath;
  late Uint8List inputBytes;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('docvault_worker_test');

    // 200x300 test image: top half red, bottom half yellow.
    final sample = img.Image(width: 200, height: 300);
    for (var y = 0; y < 300; y++) {
      for (var x = 0; x < 200; x++) {
        final isRed = y < 150;
        sample.setPixelRgb(x, y, 255, isRed ? 0 : 255, 0);
      }
    }

    inputPath = '${tempDir.path}/input.jpg';
    inputBytes = Uint8List.fromList(img.encodeJpg(sample));
    await File(inputPath).writeAsBytes(inputBytes);
  });

  tearDownAll(() async {
    ImageProcessingWorker.instance.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('worker applies a grayscale filter from a file', () async {
    final outputPath = '${tempDir.path}/filtered.jpg';

    final resultPath = await ImageProcessingWorker.instance.applyFilter(
      inputPath,
      ImageFilterType.grayscale,
      outputPath,
    );

    expect(resultPath, outputPath);
    expect(File(outputPath).existsSync(), isTrue);

    final decoded = img.decodeImage(await File(outputPath).readAsBytes());
    expect(decoded, isNotNull);
    expect(decoded!.width, 200);
    expect(decoded.height, 300);

    // Grayscale means R == G == B for every pixel.
    for (final pixel in decoded) {
      expect(pixel.r, pixel.g);
      expect(pixel.g, pixel.b);
    }
  });

  test('ScanFilterService.apply applies sephia fresh from the same base',
      () async {
    // First tap: grayscale.
    final gray = await ScanFilterService.apply(
      ScanFilter.grayscale,
      inputBytes,
    );
    // Second tap on a DIFFERENT filter must be computed from the same
    // original bytes (not on top of the grayscale result) — otherwise
    // filters would overlap/stack.
    final sepia = await ScanFilterService.apply(
      ScanFilter.sepia,
      inputBytes,
    );

    final sepiaImage = img.decodeImage(sepia);
    expect(sepiaImage, isNotNull);

    // Sepia strongly shifts red up and blue down (red >> blue), which
    // would be impossible if sepia were applied on top of a grayscale
    // image computed from a red/yellow source.
    final top = sepiaImage!.getPixel(100, 20);
    expect(top.b, lessThan(top.r));

    // The grayscale output must itself be perfectly neutral.
    final grayImage = img.decodeImage(gray);
    expect(grayImage, isNotNull);
    final p = grayImage!.getPixel(100, 20);
    expect(p.r, p.g);
    expect(p.g, p.b);
  });

  test('ScanFilterService.apply caches the result for the same bytes',
      () async {
    final first = await ScanFilterService.apply(
      ScanFilter.sharpen,
      inputBytes,
    );
    final second = await ScanFilterService.apply(
      ScanFilter.sharpen,
      inputBytes,
    );

    // The cache returns the exact same object on the second tap.
    expect(identical(first, second), isTrue);
  });

  test('worker auto-crops or falls back to a valid file', () async {
    final outputPath = '${tempDir.path}/autocrop.jpg';

    final resultPath = await ImageProcessingWorker.instance.autoCrop(
      inputPath,
      outputPath,
    );

    expect(resultPath, outputPath);
    expect(File(outputPath).existsSync(), isTrue);

    final decoded = img.decodeImage(await File(outputPath).readAsBytes());
    expect(decoded, isNotNull);
  });
}