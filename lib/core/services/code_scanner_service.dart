import 'dart:io';

import 'package:flutter/services.dart';

// ============================================================
// GOOGLE CODE SCANNER SERVICE
// ============================================================
//
// Thin, typed wrapper around the native "docvault/code_scanner"
// platform channel, which itself wraps Google's Code Scanner API
// (com.google.mlkit.vision.codescanner.GmsBarcodeScanning).
//
// This API is delivered through Google Play services: it owns its
// own camera + scanning UI, requires no CAMERA permission from this
// app, and the on-device model is downloaded on demand (or ahead of
// time via the manifest meta-data already configured in
// AndroidManifest.xml).
//
// https://developers.google.com/ml-kit/vision/barcode-scanning/code-scanner
//
// IMPORTANT: This is an Android-only API -- Google does not provide
// an iOS equivalent. `CodeScannerService.isSupported` reflects that;
// calling code should check it (or catch [CodeScannerException] with
// code `UNSUPPORTED_PLATFORM`) before offering the feature on iOS.

/// The barcode/QR symbologies the Google Code Scanner API can detect.
/// Restricting to the formats you actually expect (e.g. just
/// [qrCode]) makes detection faster and reduces false positives.
enum ScannableBarcodeFormat {
  qrCode,
  aztec,
  code128,
  code39,
  code93,
  codabar,
  dataMatrix,
  ean13,
  ean8,
  itf,
  upcA,
  upcE,
  pdf417,
}

extension _ScannableBarcodeFormatWireName on ScannableBarcodeFormat {
  String get wireName {
    switch (this) {
      case ScannableBarcodeFormat.qrCode:
        return 'QR_CODE';
      case ScannableBarcodeFormat.aztec:
        return 'AZTEC';
      case ScannableBarcodeFormat.code128:
        return 'CODE_128';
      case ScannableBarcodeFormat.code39:
        return 'CODE_39';
      case ScannableBarcodeFormat.code93:
        return 'CODE_93';
      case ScannableBarcodeFormat.codabar:
        return 'CODABAR';
      case ScannableBarcodeFormat.dataMatrix:
        return 'DATA_MATRIX';
      case ScannableBarcodeFormat.ean13:
        return 'EAN_13';
      case ScannableBarcodeFormat.ean8:
        return 'EAN_8';
      case ScannableBarcodeFormat.itf:
        return 'ITF';
      case ScannableBarcodeFormat.upcA:
        return 'UPC_A';
      case ScannableBarcodeFormat.upcE:
        return 'UPC_E';
      case ScannableBarcodeFormat.pdf417:
        return 'PDF417';
    }
  }
}

/// What kind of structured content a scanned code represents, mirrors
/// `com.google.mlkit.vision.barcode.common.Barcode`'s `valueType`.
enum ScannedCodeType {
  text,
  url,
  wifi,
  email,
  phone,
  sms,
  contactInfo,
  isbn,
  product,
  geo,
  calendarEvent,
  driverLicense,
  unknown;

  static ScannedCodeType fromWireName(String? name) {
    switch (name) {
      case 'TEXT':
        return ScannedCodeType.text;
      case 'URL':
        return ScannedCodeType.url;
      case 'WIFI':
        return ScannedCodeType.wifi;
      case 'EMAIL':
        return ScannedCodeType.email;
      case 'PHONE':
        return ScannedCodeType.phone;
      case 'SMS':
        return ScannedCodeType.sms;
      case 'CONTACT_INFO':
        return ScannedCodeType.contactInfo;
      case 'ISBN':
        return ScannedCodeType.isbn;
      case 'PRODUCT':
        return ScannedCodeType.product;
      case 'GEO':
        return ScannedCodeType.geo;
      case 'CALENDAR_EVENT':
        return ScannedCodeType.calendarEvent;
      case 'DRIVER_LICENSE':
        return ScannedCodeType.driverLicense;
      default:
        return ScannedCodeType.unknown;
    }
  }
}

/// A single successfully-decoded barcode/QR result.
class ScannedCode {
  /// The raw, unformatted payload (e.g. the literal URL string for a
  /// URL-type QR code). This is the field most callers want.
  final String? rawValue;

  /// A human-readable, formatted version of [rawValue] where the SDK
  /// can produce one (e.g. a nicely formatted phone number).
  final String? displayValue;

  /// The symbology that was matched, e.g. "QR_CODE", "EAN_13".
  final String format;

  /// The semantic type of the payload (URL, WIFI, EMAIL, ...).
  final ScannedCodeType type;

  /// Structured fields for the richer types (URL/WIFI/EMAIL/PHONE/SMS).
  /// Keys vary by [type]; see the `url`, `wifiSsid` etc. convenience
  /// getters below for the common cases.
  final Map<String, dynamic> details;

  const ScannedCode({
    required this.rawValue,
    required this.displayValue,
    required this.format,
    required this.type,
    required this.details,
  });

  factory ScannedCode.fromMap(Map<dynamic, dynamic> map) {
    final rawDetails = map['details'];

    final details = rawDetails is Map
        ? rawDetails.map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : <String, dynamic>{};

    return ScannedCode(
      rawValue: map['rawValue'] as String?,
      displayValue: map['displayValue'] as String?,
      format: (map['format'] as String?) ?? 'UNKNOWN',
      type: ScannedCodeType.fromWireName(
        map['valueType'] as String?,
      ),
      details: details,
    );
  }

  /// The link target when [type] is [ScannedCodeType.url].
  String? get url => details['url'] as String?;

  String? get wifiSsid => details['ssid'] as String?;
  String? get wifiPassword => details['password'] as String?;

  String? get email => details['address'] as String?;
  String? get phoneNumber =>
      (details['number'] ?? details['phoneNumber']) as String?;
  String? get smsMessage => details['message'] as String?;

  /// The best single string to show/copy/act on, falling back through
  /// the type-specific fields to [rawValue].
  String get bestDisplayValue =>
      displayValue ?? rawValue ?? url ?? '';

  @override
  String toString() =>
      'ScannedCode(format: $format, type: $type, value: $rawValue)';
}

/// Thrown for anything other than a clean user cancellation -- an
/// unsupported platform, Play services being unavailable/out of date,
/// the scanner module failing to download, camera issues, etc. A
/// user backing out of the scanner UI is NOT an exception; it's a
/// normal `null` return from [CodeScannerService.scan].
class CodeScannerException implements Exception {
  final String code;
  final String message;

  const CodeScannerException(this.code, this.message);

  @override
  String toString() => 'CodeScannerException($code): $message';
}

class CodeScannerService {
  CodeScannerService._();

  static const MethodChannel _channel = MethodChannel(
    'docvault/code_scanner',
  );

  /// The Google Code Scanner API is Android-only -- Google publishes
  /// no iOS equivalent of this specific (Play-services-backed) API.
  /// Check this before showing a "Scan code" entry point on iOS.
  static bool get isSupported => Platform.isAndroid;

  /// Launches the Google Play services code-scanning UI and waits for
  /// a result.
  ///
  /// Returns the decoded [ScannedCode], or `null` if the user
  /// cancelled the scan. Throws [CodeScannerException] for anything
  /// else that went wrong (unsupported platform, Play services
  /// unavailable, module download failure, etc.) so callers can show
  /// an appropriate message instead of silently failing.
  ///
  /// [formats] restricts detection to specific symbologies for speed
  /// and accuracy; omit it (or pass an empty list) to accept any
  /// supported format. [enableAutoZoom] (default on) lets the scanner
  /// automatically zoom in on small/distant codes -- available since
  /// SDK 16.1.0, which is what this project depends on.
  static Future<ScannedCode?> scan({
    List<ScannableBarcodeFormat>? formats,
    bool enableAutoZoom = true,
  }) async {
    if (!isSupported) {
      throw const CodeScannerException(
        'UNSUPPORTED_PLATFORM',
        'The Google Code Scanner API is only available on Android.',
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'startScan',
        <String, dynamic>{
          if (formats != null && formats.isNotEmpty)
            'formats': formats.map((f) => f.wireName).toList(),
          'enableAutoZoom': enableAutoZoom,
        },
      );

      if (result == null) {
        return null;
      }

      if (result['cancelled'] == true) {
        return null;
      }

      return ScannedCode.fromMap(result);
    } on PlatformException catch (e) {
      throw CodeScannerException(
        e.code,
        e.message ?? 'Code scanning failed.',
      );
    } on MissingPluginException {
      throw const CodeScannerException(
        'PLUGIN_NOT_REGISTERED',
        'The native code scanner channel is not available. '
            'Rebuild the app after adding the Android dependency.',
      );
    }
  }
}
