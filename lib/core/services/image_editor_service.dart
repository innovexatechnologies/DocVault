import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../utils/file_utils.dart';

enum ImageFilterType {
  none,
  grayscale,
  document,
  enhance,
}

class ImageEditorService {
  static const _uuid = Uuid();

  Future<String> _getNewEditedPath() async {
    final cacheDir = await FileUtils.getCacheDirectory();
    final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}.jpg';
    return '${cacheDir.path}/$fileName';
  }

  /// Rotates the image by [degrees] (90, 180, 270)
  Future<String> rotateImage(String inputPath, int degrees) async {
    final bytes = await File(inputPath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Unable to decode image.');

    img.Image rotated;
    final normalized = degrees % 360;
    if (normalized == 90) {
      rotated = img.copyRotate(image, angle: 90);
    } else if (normalized == 180) {
      rotated = img.copyRotate(image, angle: 180);
    } else if (normalized == 270) {
      rotated = img.copyRotate(image, angle: 270);
    } else {
      rotated = image;
    }

    final outPath = await _getNewEditedPath();
    final outBytes = img.encodeJpg(rotated, quality: 92);
    await File(outPath).writeAsBytes(outBytes, flush: true);
    return outPath;
  }

  /// Flips the image horizontally or vertically
  Future<String> flipImage(String inputPath, {bool horizontal = true, bool vertical = false}) async {
    final bytes = await File(inputPath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Unable to decode image.');

    img.FlipDirection direction;
    if (horizontal && vertical) {
      direction = img.FlipDirection.both;
    } else if (horizontal) {
      direction = img.FlipDirection.horizontal;
    } else {
      direction = img.FlipDirection.vertical;
    }

    final flipped = img.copyFlip(image, direction: direction);
    final outPath = await _getNewEditedPath();
    final outBytes = img.encodeJpg(flipped, quality: 92);
    await File(outPath).writeAsBytes(outBytes, flush: true);
    return outPath;
  }

  /// Crops the image with the specified pixel coordinates
  Future<String> cropImage(
    String inputPath, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Unable to decode image.');

    final clampX = x.clamp(0, image.width - 1);
    final clampY = y.clamp(0, image.height - 1);
    final clampW = width.clamp(1, image.width - clampX);
    final clampH = height.clamp(1, image.height - clampY);

    final cropped = img.copyCrop(
      image,
      x: clampX,
      y: clampY,
      width: clampW,
      height: clampH,
    );

    final outPath = await _getNewEditedPath();
    final outBytes = img.encodeJpg(cropped, quality: 92);
    await File(outPath).writeAsBytes(outBytes, flush: true);
    return outPath;
  }

  /// Applies a visual filter (none, grayscale, document, enhance)
  Future<String> applyFilter(String inputPath, ImageFilterType filter) async {
    if (filter == ImageFilterType.none) return inputPath;

    final bytes = await File(inputPath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Unable to decode image.');

    img.Image filtered = img.Image.from(image);

    switch (filter) {
      case ImageFilterType.grayscale:
        filtered = img.grayscale(filtered);
        break;
      case ImageFilterType.document:
        filtered = img.grayscale(filtered);
        filtered = img.contrast(filtered, contrast: 140);
        filtered = img.adjustColor(filtered, brightness: 1.1);
        break;
      case ImageFilterType.enhance:
        filtered = img.contrast(filtered, contrast: 120);
        filtered = img.adjustColor(filtered, saturation: 1.15, brightness: 1.05);
        break;
      case ImageFilterType.none:
        break;
    }

    final outPath = await _getNewEditedPath();
    final outBytes = img.encodeJpg(filtered, quality: 92);
    await File(outPath).writeAsBytes(outBytes, flush: true);
    return outPath;
  }

  /// Overlays text onto the image
  Future<String> addTextOverlay(
    String inputPath, {
    required String text,
    required double xPercent,
    required double yPercent,
    required Color color,
    int fontSize = 24,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Unable to decode image.');

    final posX = (xPercent * image.width).toInt().clamp(0, image.width - 20);
    final posY = (yPercent * image.height).toInt().clamp(0, image.height - 20);

    final font = fontSize > 32
        ? img.arial48
        : (fontSize > 18 ? img.arial24 : img.arial14);

    final textColor = img.ColorRgba8(
      (color.r * 255).round().clamp(0, 255),
      (color.g * 255).round().clamp(0, 255),
      (color.b * 255).round().clamp(0, 255),
      (color.a * 255).round().clamp(0, 255),
    );

    img.drawString(
      image,
      text,
      font: font,
      x: posX,
      y: posY,
      color: textColor,
    );

    final outPath = await _getNewEditedPath();
    final outBytes = img.encodeJpg(image, quality: 92);
    await File(outPath).writeAsBytes(outBytes, flush: true);
    return outPath;
  }
}
