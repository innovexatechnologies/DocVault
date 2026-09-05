import 'dart:typed_data';

import 'package:doc_vault/core/services/scan_filter_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('autoCrop trims the background around a document', () {
    final source = img.Image(width: 400, height: 500);

    for (final pixel in source) {
      pixel
        ..r = 20
        ..g = 20
        ..b = 20;
    }

    for (var y = 60; y < 440; y++) {
      for (var x = 50; x < 350; x++) {
        source.getPixel(x, y)
          ..r = 250
          ..g = 250
          ..b = 250;
      }
    }

    final bytes = Uint8List.fromList(img.encodeJpg(source));
    final croppedBytes = ScanFilterService.autoCrop(bytes);
    final cropped = img.decodeImage(croppedBytes);

    expect(cropped, isNotNull);
    expect(cropped!.width, lessThan(400));
    expect(cropped.height, lessThan(500));
  });

  test('autoCrop preserves an image when no reliable page is found', () {
    final source = img.Image(width: 100, height: 100);
    final bytes = Uint8List.fromList(img.encodeJpg(source));

    final result = ScanFilterService.autoCrop(bytes);

    expect(result, same(bytes));
  });

  test('autoCrop bounds the rectified output for a large document', () {
    final source = img.Image(width: 4200, height: 5200);

    for (final pixel in source) {
      pixel
        ..r = 20
        ..g = 20
        ..b = 20;
    }

    for (var y = 300; y < 4900; y++) {
      for (var x = 250; x < 3950; x++) {
        source.getPixel(x, y)
          ..r = 250
          ..g = 250
          ..b = 250;
      }
    }

    final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 80));
    final cropped = img.decodeImage(ScanFilterService.autoCrop(bytes));

    expect(cropped, isNotNull);
    expect(cropped!.width, lessThanOrEqualTo(4000));
    expect(cropped.height, lessThanOrEqualTo(4000));
  });
}
