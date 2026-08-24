import 'dart:io';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import '../../models/conversion_type.dart';
import '../../models/pdf_result.dart';
import '../utils/file_utils.dart';

class PptxGenerationService {
  PptxGenerationService();

  /// Generates a PowerPoint presentation from images.
  ///
  /// Each image becomes one slide.
  /// The slide size is calculated from the image's actual aspect ratio
  /// instead of forcing every presentation to 16:9.
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

      // ------------------------------------------------------------
      // Read the first image.
      //
      // PowerPoint uses one presentation-wide slide size, therefore
      // the first image determines the slide/page ratio.
      // ------------------------------------------------------------
      final firstImageFile = File(imagePaths.first);

      if (!await firstImageFile.exists()) {
        throw Exception(
          'Image file not found: ${imagePaths.first}',
        );
      }

      final firstBytes = await firstImageFile.readAsBytes();
      final firstDecoded = img.decodeImage(firstBytes);

      final firstWidthPx = firstDecoded?.width ?? 800;
      final firstHeightPx = firstDecoded?.height ?? 600;

      if (firstWidthPx <= 0 || firstHeightPx <= 0) {
        throw Exception('Invalid first image dimensions.');
      }

      // ------------------------------------------------------------
      // Calculate presentation dimensions from the actual image ratio.
      //
      // PowerPoint EMU:
      // 1 inch = 914400 EMU
      //
      // We use a maximum presentation size of 13.333 x 7.5 inches
      // while preserving the original aspect ratio.
      //
      // This means:
      //  - 16:9 images -> normal widescreen
      //  - 4:3 images  -> 4:3 slide
      //  - portrait    -> portrait slide
      //  - other ratios -> matching custom slide ratio
      // ------------------------------------------------------------

      const maxWidthEmu = 12192000; // 13.333 inches
      const maxHeightEmu = 6858000; // 7.5 inches

      final imageAspectRatio =
          firstWidthPx / firstHeightPx;

      int slideWidthEmu;
      int slideHeightEmu;

      if (imageAspectRatio >= 1.0) {
        // Landscape
        slideWidthEmu = maxWidthEmu;
        slideHeightEmu =
            (slideWidthEmu / imageAspectRatio).round();

        if (slideHeightEmu > maxHeightEmu) {
          slideHeightEmu = maxHeightEmu;
          slideWidthEmu =
              (slideHeightEmu * imageAspectRatio).round();
        }
      } else {
        // Portrait
        slideHeightEmu = maxHeightEmu;
        slideWidthEmu =
            (slideHeightEmu * imageAspectRatio).round();

        if (slideWidthEmu > maxWidthEmu) {
          slideWidthEmu = maxWidthEmu;
          slideHeightEmu =
              (slideWidthEmu / imageAspectRatio).round();
        }
      }

      // Minimum valid PPTX dimensions.
      if (slideWidthEmu < 914400) {
        slideWidthEmu = 914400;
      }

      if (slideHeightEmu < 914400) {
        slideHeightEmu = 914400;
      }

      // ------------------------------------------------------------
      // 1. [Content_Types].xml
      // ------------------------------------------------------------
      final contentTypesXml = _buildContentTypesXml(slideCount);

      archive.addFile(
        ArchiveFile(
          '[Content_Types].xml',
          contentTypesXml.codeUnits.length,
          contentTypesXml.codeUnits,
        ),
      );

      // ------------------------------------------------------------
      // 2. _rels/.rels
      // ------------------------------------------------------------
      final rootRelsXml = _buildRootRelsXml();

      archive.addFile(
        ArchiveFile(
          '_rels/.rels',
          rootRelsXml.codeUnits.length,
          rootRelsXml.codeUnits,
        ),
      );

      // ------------------------------------------------------------
      // 3. ppt/presentation.xml
      // ------------------------------------------------------------
      final presentationXml = _buildPresentationXml(
        slideCount,
        slideWidthEmu,
        slideHeightEmu,
      );

      archive.addFile(
        ArchiveFile(
          'ppt/presentation.xml',
          presentationXml.codeUnits.length,
          presentationXml.codeUnits,
        ),
      );

      // ------------------------------------------------------------
      // 4. ppt/_rels/presentation.xml.rels
      // ------------------------------------------------------------
      final presentationRelsXml =
          _buildPresentationRelsXml(slideCount);

      archive.addFile(
        ArchiveFile(
          'ppt/_rels/presentation.xml.rels',
          presentationRelsXml.codeUnits.length,
          presentationRelsXml.codeUnits,
        ),
      );

      // ------------------------------------------------------------
      // 5. PowerPoint boilerplate
      // ------------------------------------------------------------
      _addPptTemplateBoilerplate(archive);

      // ------------------------------------------------------------
      // 6. Slides + images
      // ------------------------------------------------------------
      for (int i = 0; i < slideCount; i++) {
        final slideNum = i + 1;

        final imageFile = File(imagePaths[i]);

        if (!await imageFile.exists()) {
          throw Exception(
            'Image file not found: ${imagePaths[i]}',
          );
        }

        final bytes = await imageFile.readAsBytes();

        final decoded = img.decodeImage(bytes);

        final widthPx = decoded?.width ?? firstWidthPx;
        final heightPx = decoded?.height ?? firstHeightPx;

        if (widthPx <= 0 || heightPx <= 0) {
          throw Exception(
            'Invalid image dimensions for image $slideNum.',
          );
        }

        // ----------------------------------------------------------
        // Fit image inside the actual slide without distortion.
        // ----------------------------------------------------------
        final imageWidthEmu =
            widthPx * 9525.0;

        final imageHeightEmu =
            heightPx * 9525.0;

        final scaleX =
            slideWidthEmu / imageWidthEmu;

        final scaleY =
            slideHeightEmu / imageHeightEmu;

        final scale =
            scaleX < scaleY ? scaleX : scaleY;

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

        // ----------------------------------------------------------
        // Store image.
        //
        // Keep the original bytes instead of unnecessarily
        // converting the image.
        // ----------------------------------------------------------
        final extension =
            _getImageExtension(imagePaths[i]);

        final mediaPath =
            'ppt/media/image$slideNum.$extension';

        archive.addFile(
          ArchiveFile(
            mediaPath,
            bytes.length,
            bytes,
          ),
        );

        // ----------------------------------------------------------
        // Slide XML
        // ----------------------------------------------------------
        final slideXml = _buildSlideXml(
          widthEmu: renderedWidthEmu,
          heightEmu: renderedHeightEmu,
          offsetX: offsetX,
          offsetY: offsetY,
        );

        archive.addFile(
          ArchiveFile(
            'ppt/slides/slide$slideNum.xml',
            slideXml.codeUnits.length,
            slideXml.codeUnits,
          ),
        );

        // ----------------------------------------------------------
        // Slide relationships
        // ----------------------------------------------------------
        final slideRelsXml = _buildSlideRelsXml(
          slideNum,
          extension,
        );

        archive.addFile(
          ArchiveFile(
            'ppt/slides/_rels/slide$slideNum.xml.rels',
            slideRelsXml.codeUnits.length,
            slideRelsXml.codeUnits,
          ),
        );
      }

      // ------------------------------------------------------------
      // Encode PPTX ZIP archive
      // ------------------------------------------------------------
      final zipEncoder = ZipEncoder();
      final pptxBytes = zipEncoder.encode(archive);

      if (pptxBytes.isEmpty) {
        throw Exception(
          'Failed to encode PowerPoint (.pptx) archive.',
        );
      }

      // ------------------------------------------------------------
      // Save file
      // ------------------------------------------------------------
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

      return DocumentResult(
        filePath: destinationPath,
        fileName: fileName,
        pageCount: slideCount,
        generatedAt: startTimestamp,
        conversionType: ConversionType.ppt,
      );
    } finally {
      // ------------------------------------------------------------
      // Clean temporary session directory
      // ------------------------------------------------------------
      try {
        if (await sessionDir.exists()) {
          await sessionDir.delete(
            recursive: true,
          );
        }
      } catch (_) {}
    }
  }

  // ==============================================================
  // IMAGE EXTENSION
  // ==============================================================

  String _getImageExtension(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'png';
    }

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return 'jpeg';
    }

    // PPTX media will normally be JPEG/PNG.
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
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
    );

    sb.writeln(
      '<Default Extension="rels" '
      'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
    );

    sb.writeln(
      '<Default Extension="xml" '
      'ContentType="application/xml"/>',
    );

    sb.writeln(
      '<Default Extension="jpeg" '
      'ContentType="image/jpeg"/>',
    );

    sb.writeln(
      '<Default Extension="jpg" '
      'ContentType="image/jpeg"/>',
    );

    sb.writeln(
      '<Default Extension="png" '
      'ContentType="image/png"/>',
    );

    sb.writeln(
      '<Override PartName="/ppt/presentation.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>',
    );

    sb.writeln(
      '<Override PartName="/ppt/slideMasters/slideMaster1.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>',
    );

    sb.writeln(
      '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>',
    );

    sb.writeln(
      '<Override PartName="/ppt/theme/theme1.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>',
    );

    for (int i = 1; i <= slideCount; i++) {
      sb.writeln(
        '<Override PartName="/ppt/slides/slide$i.xml" '
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
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships '
        'xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '<Relationship '
        'Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="ppt/presentation.xml"/>\n'
        '</Relationships>';
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

    sb.writeln('<p:sldMasterIdLst>');

    sb.writeln(
      '<p:sldMasterId '
      'id="2147483648" '
      'r:id="rIdMaster1"/>',
    );

    sb.writeln('</p:sldMasterIdLst>');

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

    // IMPORTANT:
    // Use calculated actual slide dimensions.
    sb.writeln(
      '<p:sldSz '
      'cx="$slideWidthEmu" '
      'cy="$slideHeightEmu"/>',
    );

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

    sb.writeln(
      '<Relationship '
      'Id="rIdMaster1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" '
      'Target="slideMasters/slideMaster1.xml"/>',
    );

    sb.writeln(
      '<Relationship '
      'Id="rIdTheme1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" '
      'Target="theme/theme1.xml"/>',
    );

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
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<p:sld '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\n'
        '<p:cSld>\n'
        '<p:spTree>\n'
        '<p:nvGrpSpPr>\n'
        '<p:cNvPr id="1" name=""/>\n'
        '<p:cNvGrpSpPr/>\n'
        '<p:nvPr/>\n'
        '</p:nvGrpSpPr>\n'
        '<p:grpSpPr>\n'
        '<a:xfrm>\n'
        '<a:off x="0" y="0"/>\n'
        '<a:ext cx="0" cy="0"/>\n'
        '<a:chOff x="0" y="0"/>\n'
        '<a:chExt cx="0" cy="0"/>\n'
        '</a:xfrm>\n'
        '</p:grpSpPr>\n'
        '<p:pic>\n'
        '<p:nvPicPr>\n'
        '<p:cNvPr id="2" name="Picture 1"/>\n'
        '<p:cNvPicPr>\n'
        '<a:picLocks noChangeAspect="1"/>\n'
        '</p:cNvPicPr>\n'
        '<p:nvPr/>\n'
        '</p:nvPicPr>\n'
        '<p:blipFill>\n'
        '<a:blip r:embed="rIdImage"/>\n'
        '<a:stretch>\n'
        '<a:fillRect/>\n'
        '</a:stretch>\n'
        '</p:blipFill>\n'
        '<p:spPr>\n'
        '<a:xfrm>\n'
        '<a:off '
        'x="$offsetX" '
        'y="$offsetY"/>\n'
        '<a:ext '
        'cx="$widthEmu" '
        'cy="$heightEmu"/>\n'
        '</a:xfrm>\n'
        '<a:prstGeom prst="rect">\n'
        '<a:avLst/>\n'
        '</a:prstGeom>\n'
        '</p:spPr>\n'
        '</p:pic>\n'
        '</p:spTree>\n'
        '</p:cSld>\n'
        '<p:clrMapOvr>\n'
        '<a:masterClrMapping/>\n'
        '</p:clrMapOvr>\n'
        '</p:sld>';
  }

  // ==============================================================
  // SLIDE RELATIONSHIPS
  // ==============================================================

  String _buildSlideRelsXml(
    int slideNum,
    String extension,
  ) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships '
        'xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '<Relationship '
        'Id="rIdLayout" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" '
        'Target="../slideLayouts/slideLayout1.xml"/>\n'
        '<Relationship '
        'Id="rIdImage" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
        'Target="../media/image$slideNum.$extension"/>\n'
        '</Relationships>';
  }

  // ==============================================================
  // PPT TEMPLATE BOILERPLATE
  // ==============================================================

  void _addPptTemplateBoilerplate(
    Archive archive,
  ) {
    // ------------------------------------------------------------
    // slideLayout1.xml
    // ------------------------------------------------------------
    const slideLayoutXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<p:sldLayout '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
        'type="blank" '
        'preserve="1">\n'
        '<p:cSld name="Blank">\n'
        '<p:spTree>\n'
        '<p:nvGrpSpPr>\n'
        '<p:cNvPr id="1" name=""/>\n'
        '<p:cNvGrpSpPr/>\n'
        '<p:nvPr/>\n'
        '</p:nvGrpSpPr>\n'
        '<p:grpSpPr/>\n'
        '</p:spTree>\n'
        '</p:cSld>\n'
        '<p:clrMapOvr>\n'
        '<a:masterClrMapping/>\n'
        '</p:clrMapOvr>\n'
        '</p:sldLayout>';

    archive.addFile(
      ArchiveFile(
        'ppt/slideLayouts/slideLayout1.xml',
        slideLayoutXml.codeUnits.length,
        slideLayoutXml.codeUnits,
      ),
    );

    // ------------------------------------------------------------
    // slideLayout1.xml.rels
    // ------------------------------------------------------------
    const slideLayoutRelsXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships '
        'xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '<Relationship '
        'Id="rIdMaster" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" '
        'Target="../slideMasters/slideMaster1.xml"/>\n'
        '</Relationships>';

    archive.addFile(
      ArchiveFile(
        'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
        slideLayoutRelsXml.codeUnits.length,
        slideLayoutRelsXml.codeUnits,
      ),
    );

    // ------------------------------------------------------------
    // slideMaster1.xml
    // ------------------------------------------------------------
    const slideMasterXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<p:sldMaster '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\n'
        '<p:cSld>\n'
        '<p:spTree>\n'
        '<p:nvGrpSpPr>\n'
        '<p:cNvPr id="1" name=""/>\n'
        '<p:cNvGrpSpPr/>\n'
        '<p:nvPr/>\n'
        '</p:nvGrpSpPr>\n'
        '<p:grpSpPr/>\n'
        '</p:spTree>\n'
        '</p:cSld>\n'
        '<p:clrMap '
        'bg1="lt1" '
        'tx1="dk1" '
        'bg2="lt2" '
        'tx2="dk2" '
        'accent1="accent1" '
        'accent2="accent2" '
        'accent3="accent3" '
        'accent4="accent4" '
        'accent5="accent5" '
        'accent6="accent6" '
        'hlink="hlink" '
        'folHlink="folHlink"/>\n'
        '<p:sldLayoutIdLst>\n'
        '<p:sldLayoutId '
        'id="2147483649" '
        'r:id="rIdLayout1"/>\n'
        '</p:sldLayoutIdLst>\n'
        '</p:sldMaster>';

    archive.addFile(
      ArchiveFile(
        'ppt/slideMasters/slideMaster1.xml',
        slideMasterXml.codeUnits.length,
        slideMasterXml.codeUnits,
      ),
    );

    // ------------------------------------------------------------
    // slideMaster1.xml.rels
    // ------------------------------------------------------------
    const slideMasterRelsXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships '
        'xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '<Relationship '
        'Id="rIdLayout1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" '
        'Target="../slideLayouts/slideLayout1.xml"/>\n'
        '<Relationship '
        'Id="rIdTheme" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" '
        'Target="../theme/theme1.xml"/>\n'
        '</Relationships>';

    archive.addFile(
      ArchiveFile(
        'ppt/slideMasters/_rels/slideMaster1.xml.rels',
        slideMasterRelsXml.codeUnits.length,
        slideMasterRelsXml.codeUnits,
      ),
    );

    // ------------------------------------------------------------
    // theme1.xml
    // ------------------------------------------------------------
    const themeXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<a:theme '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'name="Office Theme">\n'
        '<a:themeElements>\n'
        '<a:clrScheme name="Office">\n'
        '<a:dk1>\n'
        '<a:sysClr val="windowText" lastClr="000000"/>\n'
        '</a:dk1>\n'
        '<a:lt1>\n'
        '<a:sysClr val="window" lastClr="FFFFFF"/>\n'
        '</a:lt1>\n'
        '<a:dk2>\n'
        '<a:srgbClr val="1F497D"/>\n'
        '</a:dk2>\n'
        '<a:lt2>\n'
        '<a:srgbClr val="EEECE1"/>\n'
        '</a:lt2>\n'
        '<a:accent1>\n'
        '<a:srgbClr val="4F81BD"/>\n'
        '</a:accent1>\n'
        '<a:accent2>\n'
        '<a:srgbClr val="C0504D"/>\n'
        '</a:accent2>\n'
        '<a:accent3>\n'
        '<a:srgbClr val="9BBB59"/>\n'
        '</a:accent3>\n'
        '<a:accent4>\n'
        '<a:srgbClr val="8064A2"/>\n'
        '</a:accent4>\n'
        '<a:accent5>\n'
        '<a:srgbClr val="4BACC6"/>\n'
        '</a:accent5>\n'
        '<a:accent6>\n'
        '<a:srgbClr val="F79646"/>\n'
        '</a:accent6>\n'
        '<a:hlink>\n'
        '<a:srgbClr val="0000FF"/>\n'
        '</a:hlink>\n'
        '<a:folHlink>\n'
        '<a:srgbClr val="800080"/>\n'
        '</a:folHlink>\n'
        '</a:clrScheme>\n'
        '<a:fontScheme name="Office">\n'
        '<a:majorFont>\n'
        '<a:latin typeface="Calibri"/>\n'
        '</a:majorFont>\n'
        '<a:minorFont>\n'
        '<a:latin typeface="Calibri"/>\n'
        '</a:minorFont>\n'
        '</a:fontScheme>\n'
        '<a:fmtScheme name="Office">\n'
        '<a:fillStyleLst/>\n'
        '<a:lnStyleLst/>\n'
        '<a:effectStyleLst/>\n'
        '<a:bgFillStyleLst/>\n'
        '</a:fmtScheme>\n'
        '</a:themeElements>\n'
        '</a:theme>';

    archive.addFile(
      ArchiveFile(
        'ppt/theme/theme1.xml',
        themeXml.codeUnits.length,
        themeXml.codeUnits,
      ),
    );
  }
}