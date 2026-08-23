import 'dart:io';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import '../../models/conversion_type.dart';
import '../../models/pdf_result.dart';
import '../utils/file_utils.dart';

class DocxGenerationService {
  DocxGenerationService();

  /// Generates a Microsoft Word (.docx) document containing the given images
  Future<DocumentResult> generateDocxFromImages(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      throw Exception('Cannot generate Word document: no images provided.');
    }

    final startTimestamp = DateTime.now();
    final tempDir = await FileUtils.getTempDirectory();
    final sessionDir = Directory(
      '${tempDir.path}/docx_${DateTime.now().millisecondsSinceEpoch}',
    );
    await sessionDir.create(recursive: true);

    final archive = Archive();

    // 1. [Content_Types].xml
    final contentTypesXml = _buildContentTypesXml(imagePaths.length);
    archive.addFile(
      ArchiveFile(
        '[Content_Types].xml',
        contentTypesXml.length,
        contentTypesXml.codeUnits,
      ),
    );

    // 2. _rels/.rels
    final rootRelsXml = _buildRootRelsXml();
    archive.addFile(
      ArchiveFile('_rels/.rels', rootRelsXml.length, rootRelsXml.codeUnits),
    );

    // 3. word/_rels/document.xml.rels
    final documentRelsXml = _buildDocumentRelsXml(imagePaths.length);
    archive.addFile(
      ArchiveFile(
        'word/_rels/document.xml.rels',
        documentRelsXml.length,
        documentRelsXml.codeUnits,
      ),
    );

    // 4. word/media/image{1..N}.jpeg & word/document.xml
    final imageDimensions = <(int widthEmu, int heightEmu)>[];
    for (int i = 0; i < imagePaths.length; i++) {
      final imageFile = File(imagePaths[i]);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found: ${imagePaths[i]}');
      }

      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);

      int widthPx = decoded?.width ?? 800;
      int heightPx = decoded?.height ?? 600;

      // Fit into standard Word portrait margins:
      // Page width: 8.5 in (7620000 EMU), Margins: 1 in each (914400 EMU) -> usable: 6.5 in (5791200 EMU)
      // Page height: 11 in (9906000 EMU), Margins: 1 in each (914400 EMU) -> usable: 9.0 in (8077200 EMU)
      const maxUsableWidthEmu = 5791200;
      const maxUsableHeightEmu = 8077200;

      // 1 px ≈ 9525 EMU at 96 DPI
      int widthEmu = widthPx * 9525;
      int heightEmu = heightPx * 9525;

      if (widthEmu > maxUsableWidthEmu) {
        heightEmu = (heightEmu * (maxUsableWidthEmu / widthEmu)).round();
        widthEmu = maxUsableWidthEmu;
      }
      if (heightEmu > maxUsableHeightEmu) {
        widthEmu = (widthEmu * (maxUsableHeightEmu / heightEmu)).round();
        heightEmu = maxUsableHeightEmu;
      }

      imageDimensions.add((widthEmu, heightEmu));

      archive.addFile(
        ArchiveFile('word/media/image${i + 1}.jpeg', bytes.length, bytes),
      );
    }

    // 5. word/document.xml
    final documentXml = _buildDocumentXml(imageDimensions);
    archive.addFile(
      ArchiveFile(
        'word/document.xml',
        documentXml.length,
        documentXml.codeUnits,
      ),
    );

    // Encode ZIP archive
    final zipEncoder = ZipEncoder();
    final docxBytes = zipEncoder.encode(archive);

    if (docxBytes.isEmpty) {
      throw Exception('Failed to encode Word (.docx) archive.');
    }

    final fileName = await FileUtils.generatePdfFileName(ConversionType.docs);
    final appDocDir = await FileUtils.getAppDocumentsDirectory();
    final destinationPath = '${appDocDir.path}/$fileName';
    final targetFile = File(destinationPath);

    await targetFile.writeAsBytes(docxBytes, flush: true);

    // Clean up temporary session dir
    try {
      if (await sessionDir.exists()) {
        await sessionDir.delete(recursive: true);
      }
    } catch (_) {}

    return DocumentResult(
      filePath: destinationPath,
      fileName: fileName,
      pageCount: imagePaths.length,
      generatedAt: startTimestamp,
      conversionType: ConversionType.docs,
    );
  }

  String _buildContentTypesXml(int count) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');
    sb.writeln('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>');
    sb.writeln('  <Default Extension="xml" ContentType="application/xml"/>');
    sb.writeln('  <Default Extension="jpeg" ContentType="image/jpeg"/>');
    sb.writeln('  <Default Extension="jpg" ContentType="image/jpeg"/>');
    sb.writeln('  <Default Extension="png" ContentType="image/png"/>');
    sb.writeln('  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>');
    sb.writeln('</Types>');
    return sb.toString();
  }

  String _buildRootRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>\n'
        '</Relationships>';
  }

  String _buildDocumentRelsXml(int count) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (int i = 1; i <= count; i++) {
      sb.writeln(
        '  <Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image$i.jpeg"/>',
      );
    }
    sb.writeln('</Relationships>');
    return sb.toString();
  }

  String _buildDocumentXml(List<(int widthEmu, int heightEmu)> dimensions) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">');
    sb.writeln('  <w:body>');

    for (int i = 0; i < dimensions.length; i++) {
      final relId = 'rId${i + 1}';
      final (widthEmu, heightEmu) = dimensions[i];
      final docPrId = i + 1;

      sb.writeln('    <w:p>');
      sb.writeln('      <w:pPr><w:jc w:val="center"/></w:pPr>');
      sb.writeln('      <w:r>');
      sb.writeln('        <w:drawing>');
      sb.writeln('          <wp:inline distT="0" distB="0" distL="0" distR="0">');
      sb.writeln('            <wp:extent cx="$widthEmu" cy="$heightEmu"/>');
      sb.writeln('            <wp:docPr id="$docPrId" name="Picture $docPrId"/>');
      sb.writeln('            <a:graphic>');
      sb.writeln('              <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">');
      sb.writeln('                <pic:pic>');
      sb.writeln('                  <pic:nvPicPr>');
      sb.writeln('                    <pic:cNvPr id="$docPrId" name="Image $docPrId"/>');
      sb.writeln('                    <pic:cNvPicPr/>');
      sb.writeln('                  </pic:nvPicPr>');
      sb.writeln('                  <pic:blipFill>');
      sb.writeln('                    <a:blip r:embed="$relId"/>');
      sb.writeln('                    <a:stretch><a:fillRect/></a:stretch>');
      sb.writeln('                  </pic:blipFill>');
      sb.writeln('                  <pic:spPr>');
      sb.writeln('                    <a:xfrm>');
      sb.writeln('                      <a:off x="0" y="0"/>');
      sb.writeln('                      <a:ext cx="$widthEmu" cy="$heightEmu"/>');
      sb.writeln('                    </a:xfrm>');
      sb.writeln('                    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>');
      sb.writeln('                  </pic:spPr>');
      sb.writeln('                </pic:pic>');
      sb.writeln('              </a:graphicData>');
      sb.writeln('            </a:graphic>');
      sb.writeln('          </wp:inline>');
      sb.writeln('        </w:drawing>');
      sb.writeln('      </w:r>');
      sb.writeln('    </w:p>');

      // Insert page break between pages except for the last image
      if (i < dimensions.length - 1) {
        sb.writeln('    <w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      }
    }

    sb.writeln('    <w:sectPr>');
    sb.writeln('      <w:pgSz w:w="12240" w:h="15840"/>'); // Letter size in twips (8.5 x 11 in)
    sb.writeln('      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>'); // 1 inch margins
    sb.writeln('    </w:sectPr>');
    sb.writeln('  </w:body>');
    sb.writeln('</w:document>');

    return sb.toString();
  }
}
