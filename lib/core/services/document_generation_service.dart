import '../../models/conversion_type.dart';
import '../../models/pdf_result.dart';
import 'docx_generation_service.dart';
import 'pdf_generation_service.dart';
import 'pptx_generation_service.dart';

class DocumentGenerationService {
  final PdfGenerationService _pdfService;
  final DocxGenerationService _docxService;
  final PptxGenerationService _pptxService;

  DocumentGenerationService({
    PdfGenerationService? pdfService,
    DocxGenerationService? docxService,
    PptxGenerationService? pptxService,
  })  : _pdfService = pdfService ?? PdfGenerationService(),
        _docxService = docxService ?? DocxGenerationService(),
        _pptxService = pptxService ?? PptxGenerationService();

  /// Generates a document of the specified conversion type from the given images
  Future<DocumentResult> generateDocument({
    required List<String> imagePaths,
    required ConversionType conversionType,
  }) async {
    switch (conversionType) {
      case ConversionType.pdf:
        return await _pdfService.generatePdfFromImages(imagePaths);
      case ConversionType.docs:
        return await _docxService.generateDocxFromImages(imagePaths);
      case ConversionType.ppt:
        return await _pptxService.generatePptxFromImages(imagePaths);
    }
  }
}
