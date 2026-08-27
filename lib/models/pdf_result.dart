import 'conversion_type.dart';

class PdfResult {
  final String filePath;
  final String fileName;
  final int pageCount;
  final DateTime generatedAt;
  final ConversionType? type;

  PdfResult({
    required this.filePath,
    required this.fileName,
    required this.pageCount,
    required this.generatedAt,
    ConversionType? type,
    ConversionType? conversionType,
  }) : type = type ?? conversionType;

  ConversionType get conversionType =>
      type ?? ConversionType.fromFileName(fileName);
}

typedef DocumentResult = PdfResult;