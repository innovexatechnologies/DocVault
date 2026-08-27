import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import '../../models/conversion_type.dart';
import '../../models/pdf_result.dart';
import '../utils/file_utils.dart';

class DocxGenerationService {
  DocxGenerationService();

  /// Generates a valid Microsoft Word (.docx) document.
  ///
  /// Each selected image becomes one Word page.
  ///
  /// Page:
  /// - Letter size: 8.5 x 11 inches
  /// - 1 inch margins
  /// - Image centered on page
  /// - Image aspect ratio preserved
  /// - Images stored as JPEG
  Future<DocumentResult> generateDocxFromImages(
    List<String> imagePaths,
  ) async {
    if (imagePaths.isEmpty) {
      throw Exception(
        'Cannot generate Word document: no images provided.',
      );
    }

    final startTimestamp = DateTime.now();

    final tempDir = await FileUtils.getTempDirectory();

    final sessionDir = Directory(
      '${tempDir.path}/docx_${DateTime.now().millisecondsSinceEpoch}',
    );

    await sessionDir.create(recursive: true);

    try {
      final archive = Archive();

      // ============================================================
      // 1. [Content_Types].xml
      // ============================================================

      final contentTypesXml = _buildContentTypesXml();

      _addTextFile(
        archive,
        '[Content_Types].xml',
        contentTypesXml,
      );

      // ============================================================
      // 2. _rels/.rels
      // ============================================================

      final rootRelsXml = _buildRootRelsXml();

      _addTextFile(
        archive,
        '_rels/.rels',
        rootRelsXml,
      );

      // ============================================================
      // 3. word/document.xml.rels
      // ============================================================

      final documentRelsXml = _buildDocumentRelsXml(
        imagePaths.length,
      );

      _addTextFile(
        archive,
        'word/_rels/document.xml.rels',
        documentRelsXml,
      );

      // ============================================================
      // 4. word/styles.xml
      // ============================================================

      final stylesXml = _buildStylesXml();

      _addTextFile(
        archive,
        'word/styles.xml',
        stylesXml,
      );

      // ============================================================
      // 5. word/settings.xml
      // ============================================================

      final settingsXml = _buildSettingsXml();

      _addTextFile(
        archive,
        'word/settings.xml',
        settingsXml,
      );

      // ============================================================
      // 6. Process images
      // ============================================================

      final imageDimensions = <({int widthEmu, int heightEmu})>[];

      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];

        final imageFile = File(imagePath);

        if (!await imageFile.exists()) {
          throw Exception(
            'Image file not found: $imagePath',
          );
        }

        final originalBytes = await imageFile.readAsBytes();

        if (originalBytes.isEmpty) {
          throw Exception(
            'Image file is empty: $imagePath',
          );
        }

        final decodedImage = img.decodeImage(
          originalBytes,
        );

        if (decodedImage == null) {
          throw Exception(
            'Failed to decode image: $imagePath',
          );
        }

        // ----------------------------------------------------------
        // Convert every image to JPEG.
        // ----------------------------------------------------------

        final jpegBytes = img.encodeJpg(
          decodedImage,
          quality: 95,
        );

        if (jpegBytes.isEmpty) {
          throw Exception(
            'Failed to encode image as JPEG: $imagePath',
          );
        }

        // ----------------------------------------------------------
        // Image dimensions
        //
        // 1 pixel ≈ 9525 EMU at 96 DPI
        // ----------------------------------------------------------

        int widthEmu = decodedImage.width * 9525;
        int heightEmu = decodedImage.height * 9525;

        // ----------------------------------------------------------
        // Letter page
        //
        // Page width  = 8.5 inches
        // Page height = 11 inches
        //
        // Margins = 1 inch
        //
        // Usable width  = 6.5 inches
        // Usable height = 9 inches
        // ----------------------------------------------------------

        const maxUsableWidthEmu = 5943600;
        const maxUsableHeightEmu = 8229600;

        // ----------------------------------------------------------
        // Fit width
        // ----------------------------------------------------------

        if (widthEmu > maxUsableWidthEmu) {
          final scale = maxUsableWidthEmu / widthEmu;

          widthEmu = maxUsableWidthEmu;
          heightEmu = (heightEmu * scale).round();
        }

        // ----------------------------------------------------------
        // Fit height
        // ----------------------------------------------------------

        if (heightEmu > maxUsableHeightEmu) {
          final scale = maxUsableHeightEmu / heightEmu;

          heightEmu = maxUsableHeightEmu;
          widthEmu = (widthEmu * scale).round();
        }

        imageDimensions.add(
          (
            widthEmu: widthEmu,
            heightEmu: heightEmu,
          ),
        );

        // ----------------------------------------------------------
        // Store image inside word/media/
        // ----------------------------------------------------------

        final imageFileName =
            'word/media/image${i + 1}.jpeg';

        archive.addFile(
          ArchiveFile(
            imageFileName,
            jpegBytes.length,
            jpegBytes,
          ),
        );
      }

      // ============================================================
      // 7. word/document.xml
      // ============================================================

      final documentXml = _buildDocumentXml(
        imageDimensions,
      );

      _addTextFile(
        archive,
        'word/document.xml',
        documentXml,
      );

      // ============================================================
      // 8. Encode DOCX
      // ============================================================

      final zipEncoder = ZipEncoder();

      final docxBytes = zipEncoder.encode(
        archive,
      );

      if (docxBytes.isEmpty) {
        throw Exception(
          'Failed to encode Word (.docx) archive.',
        );
      }

      // ============================================================
      // 9. Save file
      // ============================================================

      final fileName =
          await FileUtils.generatePdfFileName(
        ConversionType.docs,
      );

      final appDocDir =
          await FileUtils.getAppDocumentsDirectory();

      final destinationPath =
          '${appDocDir.path}/$fileName';

      final targetFile =
          File(destinationPath);

      await targetFile.writeAsBytes(
        docxBytes,
        flush: true,
      );

      // ============================================================
      // 10. Verify
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
      // 11. Return result
      // ============================================================

      return DocumentResult(
        filePath: destinationPath,
        fileName: fileName,
        pageCount: imagePaths.length,
        generatedAt: startTimestamp,
        conversionType: ConversionType.docs,
      );
    } finally {
      try {
        if (await sessionDir.exists()) {
          await sessionDir.delete(
            recursive: true,
          );
        }
      } catch (_) {
        // Ignore cleanup errors.
      }
    }
  }

  // ==============================================================
  // ADD TEXT FILE
  // ==============================================================

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

  // ==============================================================
  // [Content_Types].xml
  // ==============================================================

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
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>

</Types>''';
  }

  // ==============================================================
  // _rels/.rels
  // ==============================================================

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

  // ==============================================================
  // word/_rels/document.xml.rels
  // ==============================================================

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

    sb.writeln('</Relationships>');

    return sb.toString();
  }

  // ==============================================================
  // word/styles.xml
  // ==============================================================

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

  // ==============================================================
  // word/settings.xml
  // ==============================================================

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

  // ==============================================================
  // word/document.xml
  // ==============================================================

  String _buildDocumentXml(
    List<({int widthEmu, int heightEmu})> dimensions,
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

    sb.writeln('<w:body>');

    for (int i = 0; i < dimensions.length; i++) {
      final relId = 'rId${i + 1}';

      final widthEmu = dimensions[i].widthEmu;
      final heightEmu = dimensions[i].heightEmu;

      final docPrId = i + 1;

      // ==========================================================
      // Paragraph
      // ==========================================================

      sb.writeln('<w:p>');

      sb.writeln('<w:pPr>');

      // Center image.
      sb.writeln(
        '<w:jc w:val="center"/>',
      );

      // Keep image paragraph together.
      sb.writeln(
        '<w:keepNext w:val="0"/>',
      );

      sb.writeln('</w:pPr>');

      // ==========================================================
      // Run
      // ==========================================================

      sb.writeln('<w:r>');

      sb.writeln('<w:drawing>');

      // ==========================================================
      // Inline picture
      // ==========================================================

      sb.writeln(
        '<wp:inline '
        'distT="0" '
        'distB="0" '
        'distL="0" '
        'distR="0">',
      );

      // Image size.
      sb.writeln(
        '<wp:extent '
        'cx="$widthEmu" '
        'cy="$heightEmu"/>',
      );

      // Effect extent.
      sb.writeln(
        '<wp:effectExtent '
        'l="0" '
        't="0" '
        'r="0" '
        'b="0"/>',
      );

      // Document properties.
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

      // ==========================================================
      // Graphic
      // ==========================================================

      sb.writeln('<a:graphic>');

      sb.writeln(
        '<a:graphicData '
        'uri="http://schemas.openxmlformats.org/drawingml/2006/picture">',
      );

      // ==========================================================
      // Picture
      // ==========================================================

      sb.writeln('<pic:pic>');

      // Non-visual properties.
      sb.writeln('<pic:nvPicPr>');

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

      sb.writeln('</pic:nvPicPr>');

      // ==========================================================
      // Image fill
      // ==========================================================

      sb.writeln('<pic:blipFill>');

      sb.writeln(
        '<a:blip '
        'r:embed="$relId">',
      );

      sb.writeln('</a:blip>');

      sb.writeln('<a:stretch>');

      sb.writeln('<a:fillRect/>');

      sb.writeln('</a:stretch>');

      sb.writeln('</pic:blipFill>');

      // ==========================================================
      // Shape
      // ==========================================================

      sb.writeln('<pic:spPr>');

      sb.writeln('<a:xfrm>');

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

      sb.writeln('</a:xfrm>');

      sb.writeln(
        '<a:prstGeom prst="rect">',
      );

      sb.writeln('<a:avLst/>');

      sb.writeln('</a:prstGeom>');

      sb.writeln('</pic:spPr>');

      // Close picture.
      sb.writeln('</pic:pic>');

      sb.writeln('</a:graphicData>');

      sb.writeln('</a:graphic>');

      sb.writeln('</wp:inline>');

      sb.writeln('</w:drawing>');

      sb.writeln('</w:r>');

      sb.writeln('</w:p>');

      // ==========================================================
      // Page break
      // ==========================================================

      if (i < dimensions.length - 1) {
        sb.writeln('<w:p>');

        sb.writeln('<w:r>');

        sb.writeln(
          '<w:br w:type="page"/>',
        );

        sb.writeln('</w:r>');

        sb.writeln('</w:p>');
      }
    }

    // ============================================================
    // Section
    //
    // Letter:
    // 8.5 x 11 inches
    //
    // Twips:
    // 12240 x 15840
    //
    // 1 inch margin:
    // 1440 twips
    // ============================================================

    sb.writeln('<w:sectPr>');

    sb.writeln(
      '<w:pgSz '
      'w:w="12240" '
      'w:h="15840"/>',
    );

    sb.writeln(
      '<w:pgMar '
      'w:top="1440" '
      'w:right="1440" '
      'w:bottom="1440" '
      'w:left="1440" '
      'w:header="720" '
      'w:footer="720" '
      'w:gutter="0"/>',
    );

    sb.writeln('</w:sectPr>');

    sb.writeln('</w:body>');

    sb.writeln('</w:document>');

    return sb.toString();
  }
}