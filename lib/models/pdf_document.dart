import 'dart:convert';

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

  /// Base name without `.pdf` extension
  String get baseName {
    if (fileName.toLowerCase().endsWith('.pdf')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  /// Formatted human-readable file size (e.g. 1.25 MB, 450 KB)
  String get formattedFileSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      final kb = fileSizeBytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    } else {
      final mb = fileSizeBytes / (1024 * 1024);
      return '${mb.toStringAsFixed(2)} MB';
    }
  }

  /// Formatted creation date (e.g. "Aug 19, 2026 • 10:45 AM")
  String get formattedCreatedDate {
    return _formatDateTime(createdAt);
  }

  /// Formatted modified date
  String get formattedModifiedDate {
    return _formatDateTime(modifiedAt);
  }

  static String _formatDateTime(DateTime dt) {
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
      'Dec'
    ];
    final month = months[dt.month - 1];
    final day = dt.day;
    final year = dt.year;

    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year • $hour:$minute $period';
  }

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
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      pageCount: pageCount ?? this.pageCount,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

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

  factory PdfDocument.fromMap(Map<String, dynamic> map) {
    return PdfDocument(
      id: map['id']?.toString() ?? '',
      fileName: map['fileName']?.toString() ?? '',
      filePath: map['filePath']?.toString() ?? '',
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      pageCount: (map['pageCount'] as num?)?.toInt() ?? 1,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      modifiedAt: map['modifiedAt'] != null
          ? DateTime.tryParse(map['modifiedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory PdfDocument.fromJson(String source) =>
      PdfDocument.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PdfDocument && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
