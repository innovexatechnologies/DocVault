import 'dart:io';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import '../../models/conversion_type.dart';
import '../../models/pdf_result.dart';
import '../utils/file_utils.dart';

class PptxGenerationService {
  PptxGenerationService();

  /// Generates a Microsoft PowerPoint (.pptx) presentation containing the given images
  Future<DocumentResult> generatePptxFromImages(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      throw Exception('Cannot generate PowerPoint presentation: no images provided.');
    }

    final startTimestamp = DateTime.now();
    final tempDir = await FileUtils.getTempDirectory();
    final sessionDir = Directory(
      '${tempDir.path}/pptx_${DateTime.now().millisecondsSinceEpoch}',
    );
    await sessionDir.create(recursive: true);

    final archive = Archive();
    final slideCount = imagePaths.length;

    // 1. [Content_Types].xml
    final contentTypesXml = _buildContentTypesXml(slideCount);
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

    // 3. ppt/presentation.xml & ppt/_rels/presentation.xml.rels
    final presentationXml = _buildPresentationXml(slideCount);
    archive.addFile(
      ArchiveFile(
        'ppt/presentation.xml',
        presentationXml.length,
        presentationXml.codeUnits,
      ),
    );

    final presentationRelsXml = _buildPresentationRelsXml(slideCount);
    archive.addFile(
      ArchiveFile(
        'ppt/_rels/presentation.xml.rels',
        presentationRelsXml.length,
        presentationRelsXml.codeUnits,
      ),
    );

    // 4. Slide layouts, masters, themes
    _addPptTemplateBoilerplate(archive);

    // 5. Slides, Slide Rels, and Media
    // 16:9 Widescreen slide dimensions in EMU: 12192000 x 6858000
    const slideWidthEmu = 12192000;
    const slideHeightEmu = 6858000;

    for (int i = 0; i < slideCount; i++) {
      final slideNum = i + 1;
      final imageFile = File(imagePaths[i]);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found: ${imagePaths[i]}');
      }

      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);

      int widthPx = decoded?.width ?? 800;
      int heightPx = decoded?.height ?? 600;

      // Scale to fit inside widescreen presentation slide while preserving aspect ratio
      double scaleX = slideWidthEmu / (widthPx * 9525);
      double scaleY = slideHeightEmu / (heightPx * 9525);
      double scale = scaleX < scaleY ? scaleX : scaleY;

      int imgWidthEmu = (widthPx * 9525 * scale).round();
      int imgHeightEmu = (heightPx * 9525 * scale).round();

      int offsetX = (slideWidthEmu - imgWidthEmu) ~/ 2;
      int offsetY = (slideHeightEmu - imgHeightEmu) ~/ 2;

      // Add image to ppt/media/
      archive.addFile(
        ArchiveFile('ppt/media/image$slideNum.jpeg', bytes.length, bytes),
      );

      // Add slide XML
      final slideXml = _buildSlideXml(
        slideNum: slideNum,
        widthEmu: imgWidthEmu,
        heightEmu: imgHeightEmu,
        offsetX: offsetX,
        offsetY: offsetY,
      );
      archive.addFile(
        ArchiveFile(
          'ppt/slides/slide$slideNum.xml',
          slideXml.length,
          slideXml.codeUnits,
        ),
      );

      // Add slide rels XML
      final slideRelsXml = _buildSlideRelsXml(slideNum);
      archive.addFile(
        ArchiveFile(
          'ppt/slides/_rels/slide$slideNum.xml.rels',
          slideRelsXml.length,
          slideRelsXml.codeUnits,
        ),
      );
    }

    // Encode ZIP archive
    final zipEncoder = ZipEncoder();
    final pptxBytes = zipEncoder.encode(archive);

    if (pptxBytes.isEmpty) {
      throw Exception('Failed to encode PowerPoint (.pptx) archive.');
    }

    final fileName = await FileUtils.generatePdfFileName(ConversionType.ppt);
    final appDocDir = await FileUtils.getAppDocumentsDirectory();
    final destinationPath = '${appDocDir.path}/$fileName';
    final targetFile = File(destinationPath);

    await targetFile.writeAsBytes(pptxBytes, flush: true);

    // Clean up temporary session dir
    try {
      if (await sessionDir.exists()) {
        await sessionDir.delete(recursive: true);
      }
    } catch (_) {}

    return DocumentResult(
      filePath: destinationPath,
      fileName: fileName,
      pageCount: slideCount,
      generatedAt: startTimestamp,
      conversionType: ConversionType.ppt,
    );
  }

  String _buildContentTypesXml(int slideCount) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');
    sb.writeln('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>');
    sb.writeln('  <Default Extension="xml" ContentType="application/xml"/>');
    sb.writeln('  <Default Extension="jpeg" ContentType="image/jpeg"/>');
    sb.writeln('  <Default Extension="jpg" ContentType="image/jpeg"/>');
    sb.writeln('  <Default Extension="png" ContentType="image/png"/>');
    sb.writeln('  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>');
    sb.writeln('  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>');
    sb.writeln('  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>');
    sb.writeln('  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>');

    for (int i = 1; i <= slideCount; i++) {
      sb.writeln(
        '  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
      );
    }

    sb.writeln('</Types>');
    return sb.toString();
  }

  String _buildRootRelsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>\n'
        '</Relationships>';
  }

  String _buildPresentationXml(int slideCount) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">');
    sb.writeln('  <p:sldMasterIdLst>');
    sb.writeln('    <p:sldMasterId id="2147483648" r:id="rIdMaster1"/>');
    sb.writeln('  </p:sldMasterIdLst>');
    sb.writeln('  <p:sldIdLst>');

    for (int i = 1; i <= slideCount; i++) {
      final sldId = 255 + i;
      sb.writeln('    <p:sldId id="$sldId" r:id="rIdSlide$i"/>');
    }

    sb.writeln('  </p:sldIdLst>');
    // 16:9 Widescreen slide size
    sb.writeln('  <p:sldSz cx="12192000" cy="6858000" type="screen16x9"/>');
    sb.writeln('  <p:notesSz cx="6858000" cy="9144000"/>');
    sb.writeln('</p:presentation>');
    return sb.toString();
  }

  String _buildPresentationRelsXml(int slideCount) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    sb.writeln('  <Relationship Id="rIdMaster1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>');
    sb.writeln('  <Relationship Id="rIdTheme1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>');

    for (int i = 1; i <= slideCount; i++) {
      sb.writeln(
        '  <Relationship Id="rIdSlide$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>',
      );
    }

    sb.writeln('</Relationships>');
    return sb.toString();
  }

  String _buildSlideXml({
    required int slideNum,
    required int widthEmu,
    required int heightEmu,
    required int offsetX,
    required int offsetY,
  }) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\n'
        '  <p:cSld>\n'
        '    <p:spTree>\n'
        '      <p:nvGrpSpPr>\n'
        '        <p:cNvPr id="1" name=""/>\n'
        '        <p:cNvGrpSpPr/>\n'
        '        <p:nvPr/>\n'
        '      </p:nvGrpSpPr>\n'
        '      <p:grpSpPr>\n'
        '        <a:xfrm>\n'
        '          <a:off x="0" y="0"/>\n'
        '          <a:ext cx="0" cy="0"/>\n'
        '          <a:chOff x="0" y="0"/>\n'
        '          <a:chExt cx="0" cy="0"/>\n'
        '        </a:xfrm>\n'
        '      </p:grpSpPr>\n'
        '      <p:pic>\n'
        '        <p:nvPicPr>\n'
        '          <p:cNvPr id="2" name="Picture 1"/>\n'
        '          <p:cNvPicPr>\n'
        '            <a:picLocks noChangeAspect="1"/>\n'
        '          </p:cNvPicPr>\n'
        '          <p:nvPr/>\n'
        '        </p:nvPicPr>\n'
        '        <p:blipFill>\n'
        '          <a:blip r:embed="rIdImage"/>\n'
        '          <a:stretch><a:fillRect/></a:stretch>\n'
        '        </p:blipFill>\n'
        '        <p:spPr>\n'
        '          <a:xfrm>\n'
        '            <a:off x="$offsetX" y="$offsetY"/>\n'
        '            <a:ext cx="$widthEmu" cy="$heightEmu"/>\n'
        '          </a:xfrm>\n'
        '          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\n'
        '        </p:spPr>\n'
        '      </p:pic>\n'
        '    </p:spTree>\n'
        '  </p:cSld>\n'
        '  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>\n'
        '</p:sld>';
  }

  String _buildSlideRelsXml(int slideNum) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rIdLayout" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>\n'
        '  <Relationship Id="rIdImage" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image$slideNum.jpeg"/>\n'
        '</Relationships>';
  }

  void _addPptTemplateBoilerplate(Archive archive) {
    // slideLayout1.xml
    const slideLayoutXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">\n'
        '  <p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld>\n'
        '  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>\n'
        '</p:sldLayout>';
    archive.addFile(
      ArchiveFile(
        'ppt/slideLayouts/slideLayout1.xml',
        slideLayoutXml.length,
        slideLayoutXml.codeUnits,
      ),
    );

    // slideLayout1.xml.rels
    const slideLayoutRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rIdMaster" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>\n'
        '</Relationships>';
    archive.addFile(
      ArchiveFile(
        'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
        slideLayoutRelsXml.length,
        slideLayoutRelsXml.codeUnits,
      ),
    );

    // slideMaster1.xml
    const slideMasterXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\n'
        '  <p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld>\n'
        '  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>\n'
        '  <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rIdLayout1"/></p:sldLayoutIdLst>\n'
        '</p:sldMaster>';
    archive.addFile(
      ArchiveFile(
        'ppt/slideMasters/slideMaster1.xml',
        slideMasterXml.length,
        slideMasterXml.codeUnits,
      ),
    );

    // slideMaster1.xml.rels
    const slideMasterRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rIdLayout1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>\n'
        '  <Relationship Id="rIdTheme" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>\n'
        '</Relationships>';
    archive.addFile(
      ArchiveFile(
        'ppt/slideMasters/_rels/slideMaster1.xml.rels',
        slideMasterRelsXml.length,
        slideMasterRelsXml.codeUnits,
      ),
    );

    // theme1.xml
    const themeXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">\n'
        '  <a:themeElements>\n'
        '    <a:clrScheme name="Office">\n'
        '      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>\n'
        '      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>\n'
        '      <a:dk2><a:srgbClr val="1F497D"/></a:dk2>\n'
        '      <a:lt2><a:srgbClr val="EEECE1"/></a:lt2>\n'
        '      <a:accent1><a:srgbClr val="4F81BD"/></a:accent1>\n'
        '      <a:accent2><a:srgbClr val="C0504D"/></a:accent2>\n'
        '      <a:accent3><a:srgbClr val="9BBB59"/></a:accent3>\n'
        '      <a:accent4><a:srgbClr val="8064A2"/></a:accent4>\n'
        '      <a:accent5><a:srgbClr val="4BACC6"/></a:accent5>\n'
        '      <a:accent6><a:srgbClr val="F79646"/></a:accent6>\n'
        '      <a:hlink><a:srgbClr val="0000FF"/></a:hlink>\n'
        '      <a:folHlink><a:srgbClr val="800080"/></a:folHlink>\n'
        '    </a:clrScheme>\n'
        '    <a:fontScheme name="Office">\n'
        '      <a:majorFont><a:latin typeface="Calibri"/></a:majorFont>\n'
        '      <a:minorFont><a:latin typeface="Calibri"/></a:minorFont>\n'
        '    </a:fontScheme>\n'
        '    <a:fmtScheme name="Office"><a:fillStyleLst/><a:lnStyleLst/><a:effectStyleLst/><a:bgFillStyleLst/></a:fmtScheme>\n'
        '  </a:themeElements>\n'
        '</a:theme>';
    archive.addFile(
      ArchiveFile(
        'ppt/theme/theme1.xml',
        themeXml.length,
        themeXml.codeUnits,
      ),
    );
  }
}
