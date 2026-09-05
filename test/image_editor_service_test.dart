import 'dart:io';
import 'package:doc_vault/core/services/image_editor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String sampleImagePath;
  final editorService = ImageEditorService();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('docvault_editor_test');
    sampleImagePath = '${tempDir.path}/sample.jpg';

    // Mock path_provider channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    // Create a 100x200 red/green test image
    final sampleImg = img.Image(width: 100, height: 200);
    for (int y = 0; y < 200; y++) {
      for (int x = 0; x < 100; x++) {
        sampleImg.setPixelRgb(x, y, 255, y < 100 ? 0 : 255, 0);
      }
    }
    await File(sampleImagePath).writeAsBytes(img.encodeJpg(sampleImg));
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('rotates image 90 degrees', () async {
    final rotatedPath = await editorService.rotateImage(sampleImagePath, 90);
    expect(File(rotatedPath).existsSync(), isTrue);

    final rotatedBytes = await File(rotatedPath).readAsBytes();
    final decoded = img.decodeImage(rotatedBytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 200);
    expect(decoded.height, 100);
  });

  test('crops image to requested dimensions', () async {
    final croppedPath = await editorService.cropImage(
      sampleImagePath,
      x: 10,
      y: 10,
      width: 50,
      height: 60,
    );
    expect(File(croppedPath).existsSync(), isTrue);

    final croppedBytes = await File(croppedPath).readAsBytes();
    final decoded = img.decodeImage(croppedBytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 50);
    expect(decoded.height, 60);
  });

  test('normalized crop clamps boundaries', () async {
    final croppedPath = await editorService.cropImageNormalized(
      sampleImagePath,
      left: -0.1,
      top: 0.1,
      right: 0.6,
      bottom: 1.2,
    );

    final decoded = img.decodeImage(await File(croppedPath).readAsBytes());
    expect(decoded, isNotNull);
    expect(decoded!.width, 60);
    expect(decoded.height, 180);
  });

  test('normalized crop rejects non-finite coordinates', () async {
    expect(
      () => editorService.cropImageNormalized(
        sampleImagePath,
        left: double.nan,
        top: 0,
        right: 1,
        bottom: 1,
      ),
      throwsArgumentError,
    );
  });

  test('applies grayscale filter', () async {
    final filteredPath = await editorService.applyFilter(
      sampleImagePath,
      ImageFilterType.grayscale,
    );
    expect(File(filteredPath).existsSync(), isTrue);

    final filteredBytes = await File(filteredPath).readAsBytes();
    final decoded = img.decodeImage(filteredBytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 100);
    expect(decoded.height, 200);
  });

  test('adds text overlay without crashing', () async {
    final textPath = await editorService.addTextOverlay(
      sampleImagePath,
      text: 'Test Doc',
      xPercent: 0.1,
      yPercent: 0.1,
      color: Colors.white,
      fontSize: 20,
    );
    expect(File(textPath).existsSync(), isTrue);
    expect(File(textPath).lengthSync(), greaterThan(0));
  });
}
