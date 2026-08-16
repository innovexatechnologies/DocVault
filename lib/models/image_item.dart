class ImageItem {
  final String id;
  final String filePath;
  final DateTime capturedAt;
  final String source; // 'camera' or 'gallery'

  ImageItem({
    required this.id,
    required this.filePath,
    required this.capturedAt,
    required this.source,
  });

  ImageItem copyWith({
    String? id,
    String? filePath,
    DateTime? capturedAt,
    String? source,
  }) {
    return ImageItem(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      capturedAt: capturedAt ?? this.capturedAt,
      source: source ?? this.source,
    );
  }
}
