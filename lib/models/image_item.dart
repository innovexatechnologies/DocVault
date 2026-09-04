class ImageItem {
  // ==========================================================================
  // BASIC INFORMATION
  // ==========================================================================

  final String id;

  final String filePath;

  final DateTime capturedAt;

  /// Image source:
  /// camera, gallery, existing_doc
  final String source;

  // ==========================================================================
  // CONSTRUCTOR
  // ==========================================================================

  const ImageItem({
    required this.id,
    required this.filePath,
    required this.capturedAt,
    required this.source,
  });

  // ==========================================================================
  // SOURCE HELPERS
  // ==========================================================================

  bool get isFromCamera {
    return source.toLowerCase() == 'camera';
  }

  bool get isFromGallery {
    return source.toLowerCase() == 'gallery';
  }

  bool get isExistingDocument {
    return source.toLowerCase() == 'existing_doc';
  }

  // ==========================================================================
  // SOURCE LABEL
  // ==========================================================================

  String get sourceLabel {
    switch (source.toLowerCase()) {
      case 'camera':
        return 'Camera';

      case 'gallery':
        return 'Gallery';

      case 'existing_doc':
        return 'Document';

      default:
        return 'Image';
    }
  }

  // ==========================================================================
  // COPY WITH
  // ==========================================================================

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

  // ==========================================================================
  // EQUALITY
  // ==========================================================================

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ImageItem &&
        other.id == id &&
        other.filePath == filePath &&
        other.capturedAt == capturedAt &&
        other.source == source;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      filePath,
      capturedAt,
      source,
    );
  }

  // ==========================================================================
  // DEBUG / LOGGING
  // ==========================================================================

  @override
  String toString() {
    return 'ImageItem('
        'id: $id, '
        'filePath: $filePath, '
        'capturedAt: $capturedAt, '
        'source: $source'
        ')';
  }
}