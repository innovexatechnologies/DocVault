import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import '../../models/conversion_type.dart';
import '../../models/pdf_result.dart';
import '../utils/file_utils.dart';

class PptxGenerationService {
  PptxGenerationService();

  /// Generates a valid PowerPoint (.pptx) presentation.
  ///
  /// Each selected image becomes one slide.
  ///
  /// The presentation slide size is based on the first image's
  /// aspect ratio.
  Future<DocumentResult> generatePptxFromImages(
    List<String> imagePaths,
  ) async {
    if (imagePaths.isEmpty) {
      throw Exception(
        'Cannot generate PowerPoint presentation: no images provided.',
      );
    }

    final startTimestamp = DateTime.now();

    final tempDir = await FileUtils.getTempDirectory();

    final sessionDir = Directory(
      '${tempDir.path}/pptx_${DateTime.now().millisecondsSinceEpoch}',
    );

    await sessionDir.create(recursive: true);

    try {
      final archive = Archive();

      final slideCount = imagePaths.length;

      // ============================================================
      // FIRST IMAGE
      // ============================================================

      final firstImageFile = File(
        imagePaths.first,
      );

      if (!await firstImageFile.exists()) {
        throw Exception(
          'Image file not found: ${imagePaths.first}',
        );
      }

      final firstBytes =
          await firstImageFile.readAsBytes();

      final firstDecoded =
          img.decodeImage(firstBytes);

      if (firstDecoded == null) {
        throw Exception(
          'Failed to decode first image.',
        );
      }

      final firstWidth = firstDecoded.width;
      final firstHeight = firstDecoded.height;

      if (firstWidth <= 0 ||
          firstHeight <= 0) {
        throw Exception(
          'Invalid first image dimensions.',
        );
      }

      // ============================================================
      // PRESENTATION SIZE
      //
      // Maximum:
      // 13.333 x 7.5 inches
      //
      // 1 inch = 914400 EMU
      // ============================================================

      const maxWidthEmu = 12192000;
      const maxHeightEmu = 6858000;

      final aspectRatio =
          firstWidth / firstHeight;

      int slideWidthEmu;
      int slideHeightEmu;

      if (aspectRatio >= 1.0) {
        // Landscape.

        slideWidthEmu = maxWidthEmu;

        slideHeightEmu =
            (slideWidthEmu / aspectRatio).round();

        if (slideHeightEmu > maxHeightEmu) {
          slideHeightEmu = maxHeightEmu;

          slideWidthEmu =
              (slideHeightEmu * aspectRatio).round();
        }
      } else {
        // Portrait.

        slideHeightEmu = maxHeightEmu;

        slideWidthEmu =
            (slideHeightEmu * aspectRatio).round();

        if (slideWidthEmu > maxWidthEmu) {
          slideWidthEmu = maxWidthEmu;

          slideHeightEmu =
              (slideWidthEmu / aspectRatio).round();
        }
      }

      // Minimum size.
      const minimumSize = 914400;

      if (slideWidthEmu < minimumSize) {
        slideWidthEmu = minimumSize;
      }

      if (slideHeightEmu < minimumSize) {
        slideHeightEmu = minimumSize;
      }

      // ============================================================
      // 1. [Content_Types].xml
      // ============================================================

      _addTextFile(
        archive,
        '[Content_Types].xml',
        _buildContentTypesXml(slideCount),
      );

      // ============================================================
      // 2. _rels/.rels
      // ============================================================

      _addTextFile(
        archive,
        '_rels/.rels',
        _buildRootRelsXml(),
      );

      // ============================================================
      // 3. ppt/presentation.xml
      // ============================================================

      _addTextFile(
        archive,
        'ppt/presentation.xml',
        _buildPresentationXml(
          slideCount,
          slideWidthEmu,
          slideHeightEmu,
        ),
      );

      // ============================================================
      // 4. ppt/_rels/presentation.xml.rels
      // ============================================================

      _addTextFile(
        archive,
        'ppt/_rels/presentation.xml.rels',
        _buildPresentationRelsXml(
          slideCount,
        ),
      );

      // ============================================================
      // 5. PowerPoint boilerplate
      // ============================================================

      _addPptTemplateBoilerplate(
        archive,
      );

      // ============================================================
      // 6. Slides + images
      // ============================================================

      for (int i = 0; i < slideCount; i++) {
        final slideNumber = i + 1;

        final imageFile = File(
          imagePaths[i],
        );

        if (!await imageFile.exists()) {
          throw Exception(
            'Image file not found: ${imagePaths[i]}',
          );
        }

        final bytes =
            await imageFile.readAsBytes();

        if (bytes.isEmpty) {
          throw Exception(
            'Image file is empty: ${imagePaths[i]}',
          );
        }

        final decoded =
            img.decodeImage(bytes);

        if (decoded == null) {
          throw Exception(
            'Failed to decode image: ${imagePaths[i]}',
          );
        }

        final widthPx = decoded.width;
        final heightPx = decoded.height;

        if (widthPx <= 0 ||
            heightPx <= 0) {
          throw Exception(
            'Invalid image dimensions for image $slideNumber.',
          );
        }

        // ==========================================================
        // Convert image size to EMU.
        // ==========================================================

        final imageWidthEmu =
            widthPx * 9525.0;

        final imageHeightEmu =
            heightPx * 9525.0;

        // ==========================================================
        // Fit image into slide without distortion.
        // ==========================================================

        final scaleX =
            slideWidthEmu / imageWidthEmu;

        final scaleY =
            slideHeightEmu / imageHeightEmu;

        final scale =
            scaleX < scaleY
                ? scaleX
                : scaleY;

        final renderedWidthEmu =
            (imageWidthEmu * scale).round();

        final renderedHeightEmu =
            (imageHeightEmu * scale).round();

        final offsetX =
            ((slideWidthEmu - renderedWidthEmu) / 2)
                .round();

        final offsetY =
            ((slideHeightEmu - renderedHeightEmu) / 2)
                .round();

        // ==========================================================
        // Image extension.
        // ==========================================================

        final extension =
            _getImageExtension(
          imagePaths[i],
        );

        final mediaPath =
            'ppt/media/image$slideNumber.$extension';

        // ==========================================================
        // Add image.
        // ==========================================================

        archive.addFile(
          ArchiveFile(
            mediaPath,
            bytes.length,
            bytes,
          ),
        );

        // ==========================================================
        // Slide XML.
        // ==========================================================

        final slideXml =
            _buildSlideXml(
          widthEmu: renderedWidthEmu,
          heightEmu: renderedHeightEmu,
          offsetX: offsetX,
          offsetY: offsetY,
        );

        _addTextFile(
          archive,
          'ppt/slides/slide$slideNumber.xml',
          slideXml,
        );

        // ==========================================================
        // Slide relationships.
        // ==========================================================

        _addTextFile(
          archive,
          'ppt/slides/_rels/slide$slideNumber.xml.rels',
          _buildSlideRelsXml(
            slideNumber,
            extension,
          ),
        );
      }

      // ============================================================
      // 7. Encode PPTX
      // ============================================================

      final zipEncoder = ZipEncoder();

      final pptxBytes =
          zipEncoder.encode(archive);

      if (pptxBytes.isEmpty) {
        throw Exception(
          'Failed to encode PowerPoint (.pptx) archive.',
        );
      }

      // ============================================================
      // 8. Save file
      // ============================================================

      final fileName =
          await FileUtils.generatePdfFileName(
        ConversionType.ppt,
      );

      final appDocDir =
          await FileUtils.getAppDocumentsDirectory();

      final destinationPath =
          '${appDocDir.path}/$fileName';

      final targetFile =
          File(destinationPath);

      await targetFile.writeAsBytes(
        pptxBytes,
        flush: true,
      );

      // ============================================================
      // 9. Verify
      // ============================================================

      if (!await targetFile.exists()) {
        throw Exception(
          'Failed to create PowerPoint presentation.',
        );
      }

      final fileSize =
          await targetFile.length();

      if (fileSize <= 0) {
        throw Exception(
          'Generated PowerPoint presentation is empty.',
        );
      }

      // ============================================================
      // 10. Return result
      // ============================================================

      return DocumentResult(
        filePath: destinationPath,
        fileName: fileName,
        pageCount: slideCount,
        generatedAt: startTimestamp,
        conversionType: ConversionType.ppt,
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
  // IMAGE EXTENSION
  // ==============================================================

  String _getImageExtension(
    String path,
  ) {
    final lower =
        path.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'png';
    }

    if (lower.endsWith('.jpg')) {
      return 'jpg';
    }

    if (lower.endsWith('.jpeg')) {
      return 'jpeg';
    }

    // If unknown, convert to JPEG.
    return 'jpeg';
  }

  // ==============================================================
  // CONTENT TYPES
  // ==============================================================

  String _buildContentTypesXml(
    int slideCount,
  ) {
    final sb = StringBuffer();

    sb.writeln(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    );

    sb.writeln(
      '<Types '
      'xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
    );

    sb.writeln(
      '<Default '
      'Extension="rels" '
      'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
    );

    sb.writeln(
      '<Default '
      'Extension="xml" '
      'ContentType="application/xml"/>',
    );

    sb.writeln(
      '<Default '
      'Extension="jpeg" '
      'ContentType="image/jpeg"/>',
    );

    sb.writeln(
      '<Default '
      'Extension="jpg" '
      'ContentType="image/jpeg"/>',
    );

    sb.writeln(
      '<Default '
      'Extension="png" '
      'ContentType="image/png"/>',
    );

    sb.writeln(
      '<Override '
      'PartName="/ppt/presentation.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>',
    );

    sb.writeln(
      '<Override '
      'PartName="/ppt/slideMasters/slideMaster1.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>',
    );

    sb.writeln(
      '<Override '
      'PartName="/ppt/slideLayouts/slideLayout1.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>',
    );

    sb.writeln(
      '<Override '
      'PartName="/ppt/theme/theme1.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>',
    );

    for (int i = 1; i <= slideCount; i++) {
      sb.writeln(
        '<Override '
        'PartName="/ppt/slides/slide$i.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
      );
    }

    sb.writeln('</Types>');

    return sb.toString();
  }

  // ==============================================================
  // ROOT RELATIONSHIPS
  // ==============================================================

  String _buildRootRelsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships
  xmlns="http://schemas.openxmlformats.org/package/2006/relationships">

  <Relationship
    Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
    Target="ppt/presentation.xml"/>

</Relationships>''';
  }

  // ==============================================================
  // PRESENTATION XML
  // ==============================================================

  String _buildPresentationXml(
    int slideCount,
    int slideWidthEmu,
    int slideHeightEmu,
  ) {
    final sb = StringBuffer();

    sb.writeln(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    );

    sb.writeln(
      '<p:presentation '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">',
    );

    // ==========================================================
    // Slide master
    // ==========================================================

    sb.writeln('<p:sldMasterIdLst>');

    sb.writeln(
      '<p:sldMasterId '
      'id="2147483648" '
      'r:id="rIdMaster1"/>',
    );

    sb.writeln('</p:sldMasterIdLst>');

    // ==========================================================
    // Slides
    // ==========================================================

    sb.writeln('<p:sldIdLst>');

    for (int i = 1; i <= slideCount; i++) {
      final slideId = 255 + i;

      sb.writeln(
        '<p:sldId '
        'id="$slideId" '
        'r:id="rIdSlide$i"/>',
      );
    }

    sb.writeln('</p:sldIdLst>');

    // ==========================================================
    // Slide size
    // ==========================================================

    sb.writeln(
      '<p:sldSz '
      'cx="$slideWidthEmu" '
      'cy="$slideHeightEmu"/>',
    );

    // ==========================================================
    // Notes size
    // ==========================================================

    sb.writeln(
      '<p:notesSz '
      'cx="6858000" '
      'cy="9144000"/>',
    );

    sb.writeln('</p:presentation>');

    return sb.toString();
  }

  // ==============================================================
  // PRESENTATION RELATIONSHIPS
  // ==============================================================

  String _buildPresentationRelsXml(
    int slideCount,
  ) {
    final sb = StringBuffer();

    sb.writeln(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    );

    sb.writeln(
      '<Relationships '
      'xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    );

    // Master.
    sb.writeln(
      '<Relationship '
      'Id="rIdMaster1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" '
      'Target="slideMasters/slideMaster1.xml"/>',
    );

    // Theme.
    sb.writeln(
      '<Relationship '
      'Id="rIdTheme1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" '
      'Target="theme/theme1.xml"/>',
    );

    // Slides.
    for (int i = 1; i <= slideCount; i++) {
      sb.writeln(
        '<Relationship '
        'Id="rIdSlide$i" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" '
        'Target="slides/slide$i.xml"/>',
      );
    }

    sb.writeln('</Relationships>');

    return sb.toString();
  }

  // ==============================================================
  // SLIDE XML
  // ==============================================================

  String _buildSlideXml({
    required int widthEmu,
    required int heightEmu,
    required int offsetX,
    required int offsetY,
  }) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">

  <p:cSld>

    <p:spTree>

      <p:nvGrpSpPr>

        <p:cNvPr
          id="1"
          name=""/>

        <p:cNvGrpSpPr/>

        <p:nvPr/>

      </p:nvGrpSpPr>

      <p:grpSpPr>

        <a:xfrm>

          <a:off
            x="0"
            y="0"/>

          <a:ext
            cx="0"
            cy="0"/>

          <a:chOff
            x="0"
            y="0"/>

          <a:chExt
            cx="0"
            cy="0"/>

        </a:xfrm>

      </p:grpSpPr>

      <p:pic>

        <p:nvPicPr>

          <p:cNvPr
            id="2"
            name="Picture 1"/>

          <p:cNvPicPr>

            <a:picLocks
              noChangeAspect="1"
              noChangeArrowheads="1"/>

          </p:cNvPicPr>

          <p:nvPr/>

        </p:nvPicPr>

        <p:blipFill>

          <a:blip
            r:embed="rIdImage"/>

          <a:stretch>

            <a:fillRect/>

          </a:stretch>

        </p:blipFill>

        <p:spPr>

          <a:xfrm>

            <a:off
              x="$offsetX"
              y="$offsetY"/>

            <a:ext
              cx="$widthEmu"
              cy="$heightEmu"/>

          </a:xfrm>

          <a:prstGeom
            prst="rect">

            <a:avLst/>

          </a:prstGeom>

        </p:spPr>

      </p:pic>

    </p:spTree>

  </p:cSld>

  <p:clrMapOvr>

    <a:masterClrMapping/>

  </p:clrMapOvr>

</p:sld>''';
  }

  // ==============================================================
  // SLIDE RELATIONSHIPS
  // ==============================================================

  String _buildSlideRelsXml(
    int slideNumber,
    String extension,
  ) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships
  xmlns="http://schemas.openxmlformats.org/package/2006/relationships">

  <Relationship
    Id="rIdLayout"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout"
    Target="../slideLayouts/slideLayout1.xml"/>

  <Relationship
    Id="rIdImage"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"
    Target="../media/image$slideNumber.$extension"/>

</Relationships>''';
  }

  // ==============================================================
  // POWERPOINT BOILERPLATE
  // ==============================================================

  void _addPptTemplateBoilerplate(
    Archive archive,
  ) {
    // ============================================================
    // slideLayout1.xml
    // ============================================================

    const slideLayoutXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
  type="blank"
  preserve="1">

  <p:cSld
    name="Blank">

    <p:spTree>

      <p:nvGrpSpPr>

        <p:cNvPr
          id="1"
          name=""/>

        <p:cNvGrpSpPr/>

        <p:nvPr/>

      </p:nvGrpSpPr>

      <p:grpSpPr/>

    </p:spTree>

  </p:cSld>

  <p:clrMapOvr>

    <a:masterClrMapping/>

  </p:clrMapOvr>

</p:sldLayout>''';

    _addTextFile(
      archive,
      'ppt/slideLayouts/slideLayout1.xml',
      slideLayoutXml,
    );

    // ============================================================
    // slideLayout1.xml.rels
    // ============================================================

    const slideLayoutRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships
  xmlns="http://schemas.openxmlformats.org/package/2006/relationships">

  <Relationship
    Id="rIdMaster"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster"
    Target="../slideMasters/slideMaster1.xml"/>

</Relationships>''';

    _addTextFile(
      archive,
      'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
      slideLayoutRelsXml,
    );

    // ============================================================
    // slideMaster1.xml
    // ============================================================

    const slideMasterXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">

  <p:cSld>

    <p:spTree>

      <p:nvGrpSpPr>

        <p:cNvPr
          id="1"
          name=""/>

        <p:cNvGrpSpPr/>

        <p:nvPr/>

      </p:nvGrpSpPr>

      <p:grpSpPr/>

    </p:spTree>

  </p:cSld>

  <p:clrMap
    bg1="lt1"
    tx1="dk1"
    bg2="lt2"
    tx2="dk2"
    accent1="accent1"
    accent2="accent2"
    accent3="accent3"
    accent4="accent4"
    accent5="accent5"
    accent6="accent6"
    hlink="hlink"
    folHlink="folHlink"/>

  <p:sldLayoutIdLst>

    <p:sldLayoutId
      id="2147483649"
      r:id="rIdLayout1"/>

  </p:sldLayoutIdLst>

</p:sldMaster>''';

    _addTextFile(
      archive,
      'ppt/slideMasters/slideMaster1.xml',
      slideMasterXml,
    );

    // ============================================================
    // slideMaster1.xml.rels
    // ============================================================

    const slideMasterRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships
  xmlns="http://schemas.openxmlformats.org/package/2006/relationships">

  <Relationship
    Id="rIdLayout1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout"
    Target="../slideLayouts/slideLayout1.xml"/>

  <Relationship
    Id="rIdTheme"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme"
    Target="../theme/theme1.xml"/>

</Relationships>''';

    _addTextFile(
      archive,
      'ppt/slideMasters/_rels/slideMaster1.xml.rels',
      slideMasterRelsXml,
    );

    // ============================================================
    // theme1.xml
    // ============================================================

    const themeXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  name="Office Theme">

  <a:themeElements>

    <a:clrScheme
      name="Office">

      <a:dk1>
        <a:sysClr
          val="windowText"
          lastClr="000000"/>
      </a:dk1>

      <a:lt1>
        <a:sysClr
          val="window"
          lastClr="FFFFFF"/>
      </a:lt1>

      <a:dk2>
        <a:srgbClr
          val="1F497D"/>
      </a:dk2>

      <a:lt2>
        <a:srgbClr
          val="EEECE1"/>
      </a:lt2>

      <a:accent1>
        <a:srgbClr
          val="4F81BD"/>
      </a:accent1>

      <a:accent2>
        <a:srgbClr
          val="C0504D"/>
      </a:accent2>

      <a:accent3>
        <a:srgbClr
          val="9BBB59"/>
      </a:accent3>

      <a:accent4>
        <a:srgbClr
          val="8064A2"/>
      </a:accent4>

      <a:accent5>
        <a:srgbClr
          val="4BACC6"/>
      </a:accent5>

      <a:accent6>
        <a:srgbClr
          val="F79646"/>
      </a:accent6>

      <a:hlink>
        <a:srgbClr
          val="0000FF"/>
      </a:hlink>

      <a:folHlink>
        <a:srgbClr
          val="800080"/>
      </a:folHlink>

    </a:clrScheme>

    <a:fontScheme
      name="Office">

      <a:majorFont>
        <a:latin
          typeface="Calibri"/>
      </a:majorFont>

      <a:minorFont>
        <a:latin
          typeface="Calibri"/>
      </a:minorFont>

    </a:fontScheme>

    <a:fmtScheme
      name="Office">

      <a:fillStyleLst/>

      <a:lnStyleLst/>

      <a:effectStyleLst/>

      <a:bgFillStyleLst/>

    </a:fmtScheme>

  </a:themeElements>

</a:theme>''';

    _addTextFile(
      archive,
      'ppt/theme/theme1.xml',
      themeXml,
    );
  }
}