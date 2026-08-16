class PdfResult {
  final String filePath;
  final String fileName;
  final int pageCount;
  final DateTime generatedAt;

  PdfResult({
    required this.filePath,
    required this.fileName,
    required this.pageCount,
    required this.generatedAt,
  });
}
