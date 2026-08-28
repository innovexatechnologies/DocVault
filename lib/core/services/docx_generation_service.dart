import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import '../../models/conversion_type.dart';
import '../../models/pdf_result.dart';
import '../utils/file_utils.dart';

class DocxGenerationService {
  DocxGenerationService();

  /// Generates a DOCX file from selected images.
  ///
  /// Every image becomes one Word page.
  ///
  /// IMPORTANT:
  /// Each Word section gets its own page size based on the
  /// image aspect ratio.
  ///
  /// Therefore:
  ///
  ///     image ratio == Word page ratio
  ///
  /// No fixed Letter/A4 page is used.
  Future<DocumentResult> generateDocxFromImages(
    List<String> imagePaths,
  ) async {
    if (imagePaths.isEmpty) {
      throw Exception(
        'Cannot generate Word document: no images provided.',
      );
    }

    final startTimestamp = DateTime.now();

    final paths = List<String>.from(imagePaths);

    // ============================================================
    // BACKGROUND GENERATION
    // ============================================================

    final Uint8List docxBytes = await Isolate.run(
      () => _generateDocxInBackground(paths),
    );

    if (docxBytes.isEmpty) {
      throw Exception(
        'Generated Word document is empty.',
      );
    }

    // ============================================================
    // FILE NAME
    // ============================================================

    final fileName = await FileUtils.generatePdfFileName(
      ConversionType.docs,
    );

    // ============================================================
    // APP DOCUMENT DIRECTORY
    // ============================================================

    final appDocDir =
        await FileUtils.getAppDocumentsDirectory();

    final destinationPath =
        '${appDocDir.path}/$fileName';

    // ============================================================
    // SAVE FILE
    // ============================================================

    final targetFile = File(destinationPath);

    await targetFile.writeAsBytes(
      docxBytes,
      flush: false,
    );

    // ============================================================
    // VERIFY
    // ============================================================

    if (!await targetFile.exists()) {
      throw Exception(
        'Failed to create Word document.',
      );
    }

    final fileSize = await targetFile.length();

    if (fileSize <= 0) {
      throw Exception(
        'Generated Word document is empty.',
      );
    }

    // ============================================================
    // RESULT
    // ============================================================

    return DocumentResult(
      filePath: destinationPath,
      fileName: fileName,
      pageCount: imagePaths.length,
      generatedAt: startTimestamp,
      conversionType: ConversionType.docs,
    );
  }
}

// ============================================================================
// BACKGROUND DOCX GENERATION
// ============================================================================

Uint8List _generateDocxInBackground(
  List<String> imagePaths,
) {
  final archive = Archive();

  final imageCount = imagePaths.length;

  // ==========================================================================
  // IMAGE PROCESSING SETTINGS
  // ==========================================================================

  const int maxImageWidth = 1800;
  const int maxImageHeight = 2400;

  const int jpegQuality = 80;

  // ==========================================================================
  // DOCX BASIC FILES
  // ==========================================================================

  _addTextFile(
    archive,
    '[Content_Types].xml',
    _buildContentTypesXml(),
  );

  _addTextFile(
    archive,
    '_rels/.rels',
    _buildRootRelsXml(),
  );

  _addTextFile(
    archive,
    'word/_rels/document.xml.rels',
    _buildDocumentRelsXml(imageCount),
  );

  _addTextFile(
    archive,
    'word/styles.xml',
    _buildStylesXml(),
  );

  _addTextFile(
    archive,
    'word/settings.xml',
    _buildSettingsXml(),
  );

  // ==========================================================================
  // IMAGE INFORMATION
  // ==========================================================================

  final dimensions = <_ImageDimension>[];

  // ==========================================================================
  // PROCESS IMAGES
  // ==========================================================================

  for (int i = 0; i < imagePaths.length; i++) {
    final imagePath = imagePaths[i];

    final imageFile = File(imagePath);

    if (!imageFile.existsSync()) {
      throw Exception(
        'Image file not found: $imagePath',
      );
    }

    // ------------------------------------------------------------------------
    // READ IMAGE
    // ------------------------------------------------------------------------

    final originalBytes =
        imageFile.readAsBytesSync();

    if (originalBytes.isEmpty) {
      throw Exception(
        'Image file is empty: $imagePath',
      );
    }

    // ------------------------------------------------------------------------
    // DECODE IMAGE
    // ------------------------------------------------------------------------

    final decodedImage =
        img.decodeImage(originalBytes);

    if (decodedImage == null) {
      throw Exception(
        'Failed to decode image: $imagePath',
      );
    }

    if (decodedImage.width <= 0 ||
        decodedImage.height <= 0) {
      throw Exception(
        'Invalid image dimensions: $imagePath',
      );
    }

    // ------------------------------------------------------------------------
    // RESIZE
    // ------------------------------------------------------------------------

    img.Image processedImage =
        decodedImage;

    final bool needsResize =
        decodedImage.width > maxImageWidth ||
        decodedImage.height > maxImageHeight;

    if (needsResize) {
      final double widthScale =
          maxImageWidth / decodedImage.width;

      final double heightScale =
          maxImageHeight / decodedImage.height;

      final double scale =
          widthScale < heightScale
              ? widthScale
              : heightScale;

      final int newWidth =
          (decodedImage.width * scale).round();

      final int newHeight =
          (decodedImage.height * scale).round();

      processedImage = img.copyResize(
        decodedImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    // ------------------------------------------------------------------------
    // JPEG
    // ------------------------------------------------------------------------

    final List<int> jpegBytes =
        img.encodeJpg(
      processedImage,
      quality: jpegQuality,
    );

    if (jpegBytes.isEmpty) {
      throw Exception(
        'Failed to encode image: $imagePath',
      );
    }

    // ==========================================================================
    // IMAGE → WORD PAGE DIMENSIONS
    // ==========================================================================
    //
    // Word uses:
    //
    //   twips = 1/1440 inch
    //
    //   EMU   = 914400 per inch
    //
    // We use a fixed physical width of 8.5 inches.
    //
    // The height is calculated from the EXACT image aspect ratio.
    //
    // Example:
    //
    // image = 1080 x 1920
    //
    // page width  = 8.5 inch
    // page height = 8.5 * 1920 / 1080
    //             = 15.111 inch
    //
    // Therefore:
    //
    // image ratio == page ratio
    //
    // --------------------------------------------------------------------------

    const double pageWidthInches = 8.5;

    final double imageWidth =
        processedImage.width.toDouble();

    final double imageHeight =
        processedImage.height.toDouble();

    final double pageHeightInches =
        pageWidthInches *
        imageHeight /
        imageWidth;

    // ------------------------------------------------------------------------
    // Convert page size to TWIPS.
    // ------------------------------------------------------------------------

    final int pageWidthTwips =
        _inchesToTwips(pageWidthInches);

    final int pageHeightTwips =
        _inchesToTwips(pageHeightInches);

    // ------------------------------------------------------------------------
    // Convert page size to EMU.
    // ------------------------------------------------------------------------

    final int imageWidthEmu =
        _inchesToEmu(pageWidthInches);

    final int imageHeightEmu =
        _inchesToEmu(pageHeightInches);

    dimensions.add(
      _ImageDimension(
        pageWidthTwips: pageWidthTwips,
        pageHeightTwips: pageHeightTwips,
        widthEmu: imageWidthEmu,
        heightEmu: imageHeightEmu,
      ),
    );

    // ------------------------------------------------------------------------
    // ADD IMAGE TO DOCX
    // ------------------------------------------------------------------------
    //
    // JPEG is already compressed.
    // Therefore no ZIP compression is applied to the JPEG.
    //

    archive.addFile(
      ArchiveFile.noCompress(
        'word/media/image${i + 1}.jpeg',
        jpegBytes.length,
        jpegBytes,
      ),
    );
  }

  // ==========================================================================
  // DOCUMENT XML
  // ==========================================================================

  _addTextFile(
    archive,
    'word/document.xml',
    _buildDocumentXml(dimensions),
  );

  // ==========================================================================
  // ZIP
  // ==========================================================================

  final zipEncoder = ZipEncoder();

  final List<int> encoded =
      zipEncoder.encode(
    archive,
    level: DeflateLevel.bestSpeed,
  );

  if (encoded.isEmpty) {
    throw Exception(
      'Failed to encode DOCX archive.',
    );
  }

  return Uint8List.fromList(
    encoded,
  );
}

// ============================================================================
// UNIT CONVERSION
// ============================================================================

int _inchesToTwips(
  double inches,
) {
  return (inches * 1440).round();
}

int _inchesToEmu(
  double inches,
) {
  return (inches * 914400).round();
}

// ============================================================================
// ADD TEXT FILE
// ============================================================================

void _addTextFile(
  Archive archive,
  String path,
  String content,
) {
  final bytes = utf8.encode(content);

  archive.addFile(
    ArchiveFile(
      path,
      bytes.length,
      bytes,
    ),
  );
}

// ============================================================================
// CONTENT TYPES
// ============================================================================

String _buildContentTypesXml() {
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">

  <Default
    Extension="rels"
    ContentType="application/vnd.openxmlformats-package.relationships+xml"/>

  <Default
    Extension="xml"
    ContentType="application/xml"/>

  <Default
    Extension="jpeg"
    ContentType="image/jpeg"/>

  <Override
    PartName="/word/document.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>

  <Override
    PartName="/word/styles.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>

  <Override
    PartName="/word/settings.xml"
    ContentType="application/vnd.openxmlformats-officedocument.word.settings+xml"/>

</Types>''';
}

// ============================================================================
// ROOT RELATIONSHIPS
// ============================================================================

String _buildRootRelsXml() {
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships
  xmlns="http://schemas.openxmlformats.org/package/2006/relationships">

  <Relationship
    Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
    Target="word/document.xml"/>

</Relationships>''';
}

// ============================================================================
// DOCUMENT RELATIONSHIPS
// ============================================================================

String _buildDocumentRelsXml(
  int imageCount,
) {
  final sb = StringBuffer();

  sb.writeln(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
  );

  sb.writeln(
    '<Relationships '
    'xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
  );

  sb.writeln(
    '<Relationship '
    'Id="rIdStyles" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
    'Target="styles.xml"/>',
  );

  sb.writeln(
    '<Relationship '
    'Id="rIdSettings" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" '
    'Target="settings.xml"/>',
  );

  for (int i = 1; i <= imageCount; i++) {
    sb.writeln(
      '<Relationship '
      'Id="rId$i" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
      'Target="media/image$i.jpeg"/>',
    );
  }

  sb.writeln(
    '</Relationships>',
  );

  return sb.toString();
}

// ============================================================================
// STYLES
// ============================================================================

String _buildStylesXml() {
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">

  <w:docDefaults>

    <w:rPrDefault>

      <w:rPr>

        <w:rFonts
          w:ascii="Calibri"
          w:hAnsi="Calibri"
          w:eastAsia="Calibri"
          w:cs="Calibri"/>

      </w:rPr>

    </w:rPrDefault>

    <w:pPrDefault>
      <w:pPr/>
    </w:pPrDefault>

  </w:docDefaults>

  <w:style
    w:type="paragraph"
    w:default="1"
    w:styleId="Normal">

    <w:name w:val="Normal"/>

    <w:qFormat/>

  </w:style>

</w:styles>''';
}

// ============================================================================
// SETTINGS
// ============================================================================

String _buildSettingsXml() {
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">

  <w:zoom w:percent="100"/>

  <w:compat/>

  <w:doNotTrackMoves/>

  <w:doNotTrackFormatting/>

</w:settings>''';
}

// ============================================================================
// DOCUMENT XML
// ============================================================================

String _buildDocumentXml(
  List<_ImageDimension> dimensions,
) {
  final sb = StringBuffer();

  sb.writeln(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
  );

  sb.writeln(
    '<w:document '
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
    'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
    'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
    'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">',
  );

  sb.writeln(
    '<w:body>',
  );

  // ==========================================================================
  // EACH IMAGE = ONE WORD SECTION / PAGE
  // ==========================================================================

  for (int i = 0; i < dimensions.length; i++) {
    final dimension = dimensions[i];

    final String relId =
        'rId${i + 1}';

    final int widthEmu =
        dimension.widthEmu;

    final int heightEmu =
        dimension.heightEmu;

    final int docPrId =
        i + 1;

    // ------------------------------------------------------------------------
    // IMAGE PARAGRAPH
    // ------------------------------------------------------------------------

    sb.writeln(
      '<w:p>',
    );

    // Remove paragraph spacing.
    sb.writeln(
      '<w:pPr>',
    );

    sb.writeln(
      '<w:spacing '
      'w:before="0" '
      'w:after="0" '
      'w:line="240" '
      'w:lineRule="auto"/>',
    );

    sb.writeln(
      '<w:jc w:val="center"/>',
    );

    sb.writeln(
      '</w:pPr>',
    );

    // ------------------------------------------------------------------------
    // RUN
    // ------------------------------------------------------------------------

    sb.writeln(
      '<w:r>',
    );

    sb.writeln(
      '<w:drawing>',
    );

    // ------------------------------------------------------------------------
    // INLINE IMAGE
    // ------------------------------------------------------------------------

    sb.writeln(
      '<wp:inline '
      'distT="0" '
      'distB="0" '
      'distL="0" '
      'distR="0">',
    );

    sb.writeln(
      '<wp:extent '
      'cx="$widthEmu" '
      'cy="$heightEmu"/>',
    );

    sb.writeln(
      '<wp:effectExtent '
      'l="0" '
      't="0" '
      'r="0" '
      'b="0"/>',
    );

    sb.writeln(
      '<wp:docPr '
      'id="$docPrId" '
      'name="Picture $docPrId"/>',
    );

    sb.writeln(
      '<wp:cNvGraphicFramePr>',
    );

    sb.writeln(
      '<a:graphicFrameLocks '
      'noChangeAspect="1"/>',
    );

    sb.writeln(
      '</wp:cNvGraphicFramePr>',
    );

    // ------------------------------------------------------------------------
    // GRAPHIC
    // ------------------------------------------------------------------------

    sb.writeln(
      '<a:graphic>',
    );

    sb.writeln(
      '<a:graphicData '
      'uri="http://schemas.openxmlformats.org/drawingml/2006/picture">',
    );

    // ------------------------------------------------------------------------
    // PICTURE
    // ------------------------------------------------------------------------

    sb.writeln(
      '<pic:pic>',
    );

    // ------------------------------------------------------------------------
    // NON-VISUAL PROPERTIES
    // ------------------------------------------------------------------------

    sb.writeln(
      '<pic:nvPicPr>',
    );

    sb.writeln(
      '<pic:cNvPr '
      'id="$docPrId" '
      'name="Image $docPrId.jpeg"/>',
    );

    sb.writeln(
      '<pic:cNvPicPr>',
    );

    sb.writeln(
      '<a:picLocks '
      'noChangeAspect="1" '
      'noChangeArrowheads="1"/>',
    );

    sb.writeln(
      '</pic:cNvPicPr>',
    );

    sb.writeln(
      '</pic:nvPicPr>',
    );

    // ------------------------------------------------------------------------
    // IMAGE FILL
    // ------------------------------------------------------------------------

    sb.writeln(
      '<pic:blipFill>',
    );

    sb.writeln(
      '<a:blip '
      'r:embed="$relId"/>',
    );

    sb.writeln(
      '<a:stretch>',
    );

    sb.writeln(
      '<a:fillRect/>',
    );

    sb.writeln(
      '</a:stretch>',
    );

    sb.writeln(
      '</pic:blipFill>',
    );

    // ------------------------------------------------------------------------
    // SHAPE
    // ------------------------------------------------------------------------

    sb.writeln(
      '<pic:spPr>',
    );

    sb.writeln(
      '<a:xfrm>',
    );

    sb.writeln(
      '<a:off '
      'x="0" '
      'y="0"/>',
    );

    sb.writeln(
      '<a:ext '
      'cx="$widthEmu" '
      'cy="$heightEmu"/>',
    );

    sb.writeln(
      '</a:xfrm>',
    );

    sb.writeln(
      '<a:prstGeom '
      'prst="rect">',
    );

    sb.writeln(
      '<a:avLst/>',
    );

    sb.writeln(
      '</a:prstGeom>',
    );

    sb.writeln(
      '</pic:spPr>',
    );

    // ------------------------------------------------------------------------
    // CLOSE IMAGE
    // ------------------------------------------------------------------------

    sb.writeln(
      '</pic:pic>',
    );

    sb.writeln(
      '</a:graphicData>',
    );

    sb.writeln(
      '</a:graphic>',
    );

    sb.writeln(
      '</wp:inline>',
    );

    sb.writeln(
      '</w:drawing>',
    );

    sb.writeln(
      '</w:r>',
    );

    sb.writeln(
      '</w:p>',
    );

    // ==========================================================================
    // SECTION BREAK
    // ==========================================================================
    //
    // This is the important part.
    //
    // Every image gets its own Word section.
    //
    // The section has:
    //
    //     page width  = image ratio width
    //     page height = image ratio height
    //     margins     = 0
    //
    // "nextPage" makes the following image start on a new page.
    //
    // ==========================================================================

    sb.writeln(
      '<w:p>',
    );

    sb.writeln(
      '<w:pPr>',
    );

    sb.writeln(
      '<w:sectPr>',
    );

    sb.writeln(
      '<w:type w:val="nextPage"/>',
    );

    sb.writeln(
      '<w:pgSz '
      'w:w="${dimension.pageWidthTwips}" '
      'w:h="${dimension.pageHeightTwips}"/>',
    );

    // ------------------------------------------------------------------------
    // ZERO MARGINS
    // ------------------------------------------------------------------------

    sb.writeln(
      '<w:pgMar '
      'w:top="0" '
      'w:right="0" '
      'w:bottom="0" '
      'w:left="0" '
      'w:header="0" '
      'w:footer="0" '
      'w:gutter="0"/>',
    );

    sb.writeln(
      '</w:sectPr>',
    );

    sb.writeln(
      '</w:pPr>',
    );

    sb.writeln(
      '</w:p>',
    );
  }

  // ==========================================================================
  // FINAL SECTION PROPERTIES
  // ==========================================================================

  //
  // The last section must also have sectPr at body level.
  //
  // We repeat the dimensions of the last image here because Word requires
  // the final section properties to exist at the end of <w:body>.
  //

  if (dimensions.isNotEmpty) {
    final last =
        dimensions.last;

    sb.writeln(
      '<w:sectPr>',
    );

    sb.writeln(
      '<w:pgSz '
      'w:w="${last.pageWidthTwips}" '
      'w:h="${last.pageHeightTwips}"/>',
    );

    sb.writeln(
      '<w:pgMar '
      'w:top="0" '
      'w:right="0" '
      'w:bottom="0" '
      'w:left="0" '
      'w:header="0" '
      'w:footer="0" '
      'w:gutter="0"/>',
    );

    sb.writeln(
      '</w:sectPr>',
    );
  }

  sb.writeln(
    '</w:body>',
  );

  sb.writeln(
    '</w:document>',
  );

  return sb.toString();
}

// ============================================================================
// IMAGE DIMENSION MODEL
// ============================================================================

class _ImageDimension {
  final int pageWidthTwips;
  final int pageHeightTwips;

  final int widthEmu;
  final int heightEmu;

  const _ImageDimension({
    required this.pageWidthTwips,
    required this.pageHeightTwips,
    required this.widthEmu,
    required this.heightEmu,
  });
}