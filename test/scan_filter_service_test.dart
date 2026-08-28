import 'dart:typed_data';

import 'package:doc_vault/core/services/scan_filter_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('autoCrop trims the background around a document', () {
    final source = img.Image(width: 100, height: 140);

    for (final pixel in source) {
      pixel
        ..r = 25
        ..g = 25
        ..b = 25;
    }

    for (var y = 20; y < 120; y++) {
      for (var x = 15; x < 85; x++) {
        source.getPixel(x, y)
          ..r = 245
          ..g = 245
          ..b = 245;
      }
    }

    final bytes = Uint8List.fromList(img.encodeJpg(source));
    final cropped = img.decodeImage(
      ScanFilterService.autoCrop(bytes),
    );

    expect(cropped, isNotNull);
    expect(cropped!.width, lessThan(100));
    expect(cropped.height, lessThan(140));
    expect(cropped.width, greaterThanOrEqualTo(70));
    expect(cropped.height, greaterThanOrEqualTo(100));
  });

  test('autoCrop preserves an image when no reliable page is found', () {
    final source = img.Image(width: 100, height: 100);
    final bytes = Uint8List.fromList(img.encodeJpg(source));

    final result = ScanFilterService.autoCrop(bytes);

    expect(result, same(bytes));
  });
}
