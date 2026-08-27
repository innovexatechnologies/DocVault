import 'dart:convert';

import 'conversion_type.dart';

class PdfDocument {
  final String id;
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final int pageCount;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const PdfDocument({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.createdAt,
    required this.modifiedAt,
  });

  // ============================================================
  // DOCUMENT TYPE
  // ============================================================

  /// Returns PDF, DOCS or PPT based on the file extension.
  ConversionType get documentType {
    return ConversionType.fromFileName(fileName);
  }

  // ============================================================
  // FILE INFORMATION
  // ============================================================

  /// File extension.
  String get extension {
    final name = fileName.toLowerCase();

    if (name.endsWith('.docx')) return 'docx';
    if (name.endsWith('.doc')) return 'doc';
    if (name.endsWith('.pptx')) return 'pptx';
    if (name.endsWith('.ppt')) return 'ppt';
    if (name.endsWith('.pdf')) return 'pdf';

    return '';
  }

  /// File name without extension.
  String get baseName {
    final name = fileName.trim();

    final lastDot = name.lastIndexOf('.');

    if (lastDot > 0) {
      return name.substring(0, lastDot);
    }

    return name;
  }

  /// Alias used by UI.
  String get title => baseName;

  /// Complete file name shown in UI.
  String get displayName {
    if (fileName.trim().isEmpty) {
      return 'Untitled Document';
    }

    return fileName;
  }

  // ============================================================
  // PAGE / SLIDE INFORMATION
  // ============================================================

  /// Returns Page or Slide depending on document type.
  String get pageLabel {
    return documentType == ConversionType.ppt
        ? 'Slide'
        : 'Page';
  }

  /// Returns Page(s) or Slide(s).
  String get pagesLabel {
    return documentType == ConversionType.ppt
        ? (pageCount == 1 ? 'Slide' : 'Slides')
        : (pageCount == 1 ? 'Page' : 'Pages');
  }

  /// Human-readable page information.
  String get pageInfo {
    return '$pageCount $pagesLabel';
  }

  // ============================================================
  // FILE SIZE
  // ============================================================

  /// Formatted file size.
  String get formattedFileSize {
    if (fileSizeBytes <= 0) {
      return '0 B';
    }

    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    }

    if (fileSizeBytes < 1024 * 1024) {
      final kb = fileSizeBytes / 1024;

      return '${kb.toStringAsFixed(
        kb >= 100 ? 0 : 1,
      )} KB';
    }

    if (fileSizeBytes < 1024 * 1024 * 1024) {
      final mb = fileSizeBytes / (1024 * 1024);

      return '${mb.toStringAsFixed(
        mb >= 100 ? 0 : 2,
      )} MB';
    }

    final gb =
        fileSizeBytes / (1024 * 1024 * 1024);

    return '${gb.toStringAsFixed(2)} GB';
  }

  // ============================================================
  // DATE / TIME
  // ============================================================

  /// Formatted creation date.
  String get formattedCreatedDate {
    return _formatDateTime(createdAt);
  }

  /// Formatted modified date.
  String get formattedModifiedDate {
    return _formatDateTime(modifiedAt);
  }

  /// Short creation date.
  String get shortCreatedDate {
    return _formatShortDate(createdAt);
  }

  /// Short modified date.
  String get shortModifiedDate {
    return _formatShortDate(modifiedAt);
  }

  static String _formatDateTime(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;

    final hour = dateTime.hour == 0
        ? 12
        : dateTime.hour > 12
            ? dateTime.hour - 12
            : dateTime.hour;

    final minute =
        dateTime.minute.toString().padLeft(2, '0');

    final period =
        dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year • '
        '$hour:$minute $period';
  }

  static String _formatShortDate(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[dateTime.month - 1]} '
        '${dateTime.day}, ${dateTime.year}';
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  PdfDocument copyWith({
    String? id,
    String? fileName,
    String? filePath,
    int? fileSizeBytes,
    int? pageCount,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return PdfDocument(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileSizeBytes:
          fileSizeBytes ?? this.fileSizeBytes,
      pageCount: pageCount ?? this.pageCount,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt:
          modifiedAt ?? this.modifiedAt,
    );
  }

  // ============================================================
  // MAP
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'fileSizeBytes': fileSizeBytes,
      'pageCount': pageCount,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }

  // ============================================================
  // FROM MAP
  // ============================================================

  factory PdfDocument.fromMap(
    Map<String, dynamic> map,
  ) {
    return PdfDocument(
      id: map['id']?.toString() ?? '',
      fileName:
          map['fileName']?.toString() ?? '',
      filePath:
          map['filePath']?.toString() ?? '',
      fileSizeBytes:
          (map['fileSizeBytes'] as num?)
                  ?.toInt() ??
              0,
      pageCount:
          (map['pageCount'] as num?)
                  ?.toInt() ??
              1,
      createdAt:
          _parseDateTime(
        map['createdAt'],
      ),
      modifiedAt:
          _parseDateTime(
        map['modifiedAt'],
      ),
    );
  }

  static DateTime _parseDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return DateTime.now();
    }

    return DateTime.tryParse(
          value.toString(),
        ) ??
        DateTime.now();
  }

  // ============================================================
  // JSON
  // ============================================================

  String toJson() {
    return json.encode(toMap());
  }

  factory PdfDocument.fromJson(
    String source,
  ) {
    final decoded = json.decode(source);

    if (decoded is! Map) {
      throw const FormatException(
        'Invalid PdfDocument JSON.',
      );
    }

    return PdfDocument.fromMap(
      Map<String, dynamic>.from(decoded),
    );
  }

  // ============================================================
  // EQUALITY
  // ============================================================

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PdfDocument &&
        other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // ============================================================
  // DEBUG
  // ============================================================

  @override
  String toString() {
    return 'PdfDocument('
        'id: $id, '
        'fileName: $fileName, '
        'type: ${documentType.shortName}, '
        'pages: $pageCount, '
        'size: $formattedFileSize'
        ')';
  }
}