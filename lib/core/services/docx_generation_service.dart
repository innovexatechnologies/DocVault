import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import '../../models/conversion_type.dart';
import '../../models/pdf_result.dart';
import '../utils/file_utils.dart';

class DocxGenerationService {
  DocxGenerationService();

  /// Generates a Microsoft Word (.docx) document
  /// containing one image per page.
  ///
  /// The generated DOCX uses:
  /// - Letter page size: 8.5 x 11 inches
  /// - 1-inch margins
  /// - One image per page
  /// - JPEG images inside word/media/
  /// - Correct DOCX relationships
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

      final contentTypesBytes = utf8.encode(
        contentTypesXml,
      );

      archive.addFile(
        ArchiveFile(
          '[Content_Types].xml',
          contentTypesBytes.length,
          contentTypesBytes,
        ),
      );

      // ============================================================
      // 2. _rels/.rels
      // ============================================================

      final rootRelsXml = _buildRootRelsXml();

      final rootRelsBytes = utf8.encode(
        rootRelsXml,
      );

      archive.addFile(
        ArchiveFile(
          '_rels/.rels',
          rootRelsBytes.length,
          rootRelsBytes,
        ),
      );

      // ============================================================
      // 3. Process images
      // ============================================================

      final imageDimensions =
          <(int widthEmu, int heightEmu)>[];

      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];

        final imageFile = File(imagePath);

        if (!await imageFile.exists()) {
          throw Exception(
            'Image file not found: $imagePath',
          );
        }

        // ----------------------------------------------------------
        // Read original image
        // ----------------------------------------------------------

        final originalBytes =
            await imageFile.readAsBytes();

        if (originalBytes.isEmpty) {
          throw Exception(
            'Image file is empty: $imagePath',
          );
        }

        // ----------------------------------------------------------
        // Decode image
        // ----------------------------------------------------------

        final decodedImage =
            img.decodeImage(originalBytes);

        if (decodedImage == null) {
          throw Exception(
            'Failed to decode image: $imagePath',
          );
        }

        // ----------------------------------------------------------
        // Convert every image to JPEG
        //
        // This guarantees that:
        //
        // word/media/image1.jpeg
        // word/media/image2.jpeg
        // ...
        //
        // always contain actual JPEG data.
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

        final widthPx = decodedImage.width;
        final heightPx = decodedImage.height;

        // ----------------------------------------------------------
        // Calculate Word image dimensions
        //
        // Word uses EMU:
        //
        // 1 inch = 914400 EMU
        //
        // At 96 DPI:
        //
        // 1 pixel ≈ 9525 EMU
        // ----------------------------------------------------------

        int widthEmu = widthPx * 9525;
        int heightEmu = heightPx * 9525;

        // ----------------------------------------------------------
        // Letter page:
        //
        // Width  = 8.5 inches
        // Height = 11 inches
        //
        // 1-inch margins:
        //
        // Usable width:
        // 8.5 - 2 = 6.5 inches
        //
        // Usable height:
        // 11 - 2 = 9 inches
        // ----------------------------------------------------------

        const int maxUsableWidthEmu = 5791200;
        const int maxUsableHeightEmu = 8229600;

        // ----------------------------------------------------------
        // Fit width
        // ----------------------------------------------------------

        if (widthEmu > maxUsableWidthEmu) {
          final scale =
              maxUsableWidthEmu / widthEmu;

          widthEmu = maxUsableWidthEmu;

          heightEmu =
              (heightEmu * scale).round();
        }

        // ----------------------------------------------------------
        // Fit height
        // ----------------------------------------------------------

        if (heightEmu > maxUsableHeightEmu) {
          final scale =
              maxUsableHeightEmu / heightEmu;

          heightEmu = maxUsableHeightEmu;

          widthEmu =
              (widthEmu * scale).round();
        }

        imageDimensions.add(
          (
            widthEmu,
            heightEmu,
          ),
        );

        // ----------------------------------------------------------
        // Add JPEG to DOCX archive
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
      // 4. word/_rels/document.xml.rels
      // ============================================================

      final documentRelsXml =
          _buildDocumentRelsXml(
        imagePaths.length,
      );

      final documentRelsBytes =
          utf8.encode(documentRelsXml);

      archive.addFile(
        ArchiveFile(
          'word/_rels/document.xml.rels',
          documentRelsBytes.length,
          documentRelsBytes,
        ),
      );

      // ============================================================
      // 5. word/document.xml
      // ============================================================

      final documentXml =
          _buildDocumentXml(
        imageDimensions,
      );

      final documentBytes =
          utf8.encode(documentXml);

      archive.addFile(
        ArchiveFile(
          'word/document.xml',
          documentBytes.length,
          documentBytes,
        ),
      );

      // ============================================================
      // 6. Encode ZIP archive
      // ============================================================

      final zipEncoder = ZipEncoder();

      final docxBytes =
          zipEncoder.encode(archive);

      if (docxBytes.isEmpty) {
        throw Exception(
          'Failed to encode Word (.docx) archive.',
        );
      }

      // ============================================================
      // 7. Generate output filename
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
      // 8. Verify generated file
      // ============================================================

      if (!await targetFile.exists()) {
        throw Exception(
          'Failed to create Word document.',
        );
      }

      final generatedSize =
          await targetFile.length();

      if (generatedSize == 0) {
        throw Exception(
          'Generated Word document is empty.',
        );
      }

      // ============================================================
      // 9. Return result
      // ============================================================

      return DocumentResult(
        filePath: destinationPath,
        fileName: fileName,
        pageCount: imagePaths.length,
        generatedAt: startTimestamp,
        conversionType: ConversionType.docs,
      );
    } finally {
      // ============================================================
      // Cleanup temporary session directory
      // ============================================================

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
  // [Content_Types].xml
  // ==============================================================

  String _buildContentTypesXml() {
    final sb = StringBuffer();

    sb.writeln(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    );

    sb.writeln(
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
    );

    // Relationships files.
    sb.writeln(
      '  <Default '
      'Extension="rels" '
      'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
    );

    // XML files.
    sb.writeln(
      '  <Default '
      'Extension="xml" '
      'ContentType="application/xml"/>',
    );

    // JPEG images.
    sb.writeln(
      '  <Default '
      'Extension="jpeg" '
      'ContentType="image/jpeg"/>',
    );

    // Main Word document.
    sb.writeln(
      '  <Override '
      'PartName="/word/document.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>',
    );

    sb.writeln(
      '</Types>',
    );

    return sb.toString();
  }

  // ==============================================================
  // _rels/.rels
  // ==============================================================

  String _buildRootRelsXml() {
    final sb = StringBuffer();

    sb.writeln(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    );

    sb.writeln(
      '<Relationships '
      'xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    );

    sb.writeln(
      '  <Relationship '
      'Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/>',
    );

    sb.writeln(
      '</Relationships>',
    );

    return sb.toString();
  }

  // ==============================================================
  // word/_rels/document.xml.rels
  // ==============================================================

  String _buildDocumentRelsXml(
    int count,
  ) {
    final sb = StringBuffer();

    sb.writeln(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    );

    sb.writeln(
      '<Relationships '
      'xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    );

    for (int i = 1; i <= count; i++) {
      sb.writeln(
        '  <Relationship '
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

  // ==============================================================
  // word/document.xml
  // ==============================================================

  String _buildDocumentXml(
    List<(int widthEmu, int heightEmu)> dimensions,
  ) {
    final sb = StringBuffer();

    sb.writeln(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    );

    // --------------------------------------------------------------
    // Document root + namespaces
    // --------------------------------------------------------------

    sb.writeln(
      '<w:document '
      'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">',
    );

    sb.writeln(
      '  <w:body>',
    );

    // ============================================================
    // Add each image as one page
    // ============================================================

    for (int i = 0; i < dimensions.length; i++) {
      final relId = 'rId${i + 1}';

      final (
        widthEmu,
        heightEmu,
      ) = dimensions[i];

      final docPrId = i + 1;

      // ----------------------------------------------------------
      // Paragraph
      // ----------------------------------------------------------

      sb.writeln(
        '    <w:p>',
      );

      // Center image horizontally.
      sb.writeln(
        '      <w:pPr>',
      );

      sb.writeln(
        '        <w:jc w:val="center"/>',
      );

      sb.writeln(
        '      </w:pPr>',
      );

      // ----------------------------------------------------------
      // Run
      // ----------------------------------------------------------

      sb.writeln(
        '      <w:r>',
      );

      sb.writeln(
        '        <w:drawing>',
      );

      // ----------------------------------------------------------
      // Inline drawing
      // ----------------------------------------------------------

      sb.writeln(
        '          <wp:inline '
        'distT="0" '
        'distB="0" '
        'distL="0" '
        'distR="0">',
      );

      // ----------------------------------------------------------
      // Image size
      // ----------------------------------------------------------

      sb.writeln(
        '            <wp:extent '
        'cx="$widthEmu" '
        'cy="$heightEmu"/>',
      );

      // ----------------------------------------------------------
      // Document properties
      // ----------------------------------------------------------

      sb.writeln(
        '            <wp:docPr '
        'id="$docPrId" '
        'name="Picture $docPrId"/>',
      );

      // ----------------------------------------------------------
      // Graphic
      // ----------------------------------------------------------

      sb.writeln(
        '            <a:graphic>',
      );

      sb.writeln(
        '              <a:graphicData '
        'uri="http://schemas.openxmlformats.org/drawingml/2006/picture">',
      );

      // ----------------------------------------------------------
      // Picture
      // ----------------------------------------------------------

      sb.writeln(
        '                <pic:pic>',
      );

      // ==========================================================
      // Non-visual picture properties
      // ==========================================================

      sb.writeln(
        '                  <pic:nvPicPr>',
      );

      sb.writeln(
        '                    <pic:cNvPr '
        'id="$docPrId" '
        'name="Image $docPrId"/>',
      );

      sb.writeln(
        '                    <pic:cNvPicPr/>',
      );

      sb.writeln(
        '                  </pic:nvPicPr>',
      );

      // ==========================================================
      // Image fill
      // ==========================================================

      sb.writeln(
        '                  <pic:blipFill>',
      );

      sb.writeln(
        '                    <a:blip '
        'r:embed="$relId"/>',
      );

      sb.writeln(
        '                    <a:stretch>',
      );

      sb.writeln(
        '                      <a:fillRect/>',
      );

      sb.writeln(
        '                    </a:stretch>',
      );

      sb.writeln(
        '                  </pic:blipFill>',
      );

      // ==========================================================
      // Shape properties
      // ==========================================================

      sb.writeln(
        '                  <pic:spPr>',
      );

      sb.writeln(
        '                    <a:xfrm>',
      );

      sb.writeln(
        '                      <a:off '
        'x="0" '
        'y="0"/>',
      );

      sb.writeln(
        '                      <a:ext '
        'cx="$widthEmu" '
        'cy="$heightEmu"/>',
      );

      sb.writeln(
        '                    </a:xfrm>',
      );

      sb.writeln(
        '                    <a:prstGeom '
        'prst="rect">',
      );

      sb.writeln(
        '                      <a:avLst/>',
      );

      sb.writeln(
        '                    </a:prstGeom>',
      );

      sb.writeln(
        '                  </pic:spPr>',
      );

      // ----------------------------------------------------------
      // Close picture
      // ----------------------------------------------------------

      sb.writeln(
        '                </pic:pic>',
      );

      sb.writeln(
        '              </a:graphicData>',
      );

      sb.writeln(
        '            </a:graphic>',
      );

      sb.writeln(
        '          </wp:inline>',
      );

      sb.writeln(
        '        </w:drawing>',
      );

      sb.writeln(
        '      </w:r>',
      );

      sb.writeln(
        '    </w:p>',
      );

      // ==========================================================
      // Page break
      // ==========================================================

      if (i < dimensions.length - 1) {
        sb.writeln(
          '    <w:p>',
        );

        sb.writeln(
          '      <w:r>',
        );

        sb.writeln(
          '        <w:br w:type="page"/>',
        );

        sb.writeln(
          '      </w:r>',
        );

        sb.writeln(
          '    </w:p>',
        );
      }
    }

    // ============================================================
    // Section properties
    //
    // Letter:
    // 8.5 x 11 inches
    //
    // Twips:
    // Width  = 12240
    // Height = 15840
    //
    // Margins:
    // 1 inch = 1440 twips
    // ============================================================

    sb.writeln(
      '    <w:sectPr>',
    );

    sb.writeln(
      '      <w:pgSz '
      'w:w="12240" '
      'w:h="15840"/>',
    );

    sb.writeln(
      '      <w:pgMar '
      'w:top="1440" '
      'w:right="1440" '
      'w:bottom="1440" '
      'w:left="1440"/>',
    );

    sb.writeln(
      '    </w:sectPr>',
    );

    // ============================================================
    // Close document
    // ============================================================

    sb.writeln(
      '  </w:body>',
    );

    sb.writeln(
      '</w:document>',
    );

    return sb.toString();
  }
}