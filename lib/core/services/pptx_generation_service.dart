import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import '../../models/conversion_type.dart';
import '../../models/pdf_result.dart';
import '../utils/file_utils.dart';

class PptxGenerationService {
  PptxGenerationService();

  /// Generates a PowerPoint presentation from images.
  ///
  /// FEATURES:
  /// - Every image becomes one slide.
  /// - 4:3 landscape presentation.
  /// - Images are fitted inside the slide.
  /// - Images are NEVER stretched.
  /// - Images are NEVER cropped.
  /// - Original aspect ratio is preserved.
  /// - Images are centered.
  /// - White slide background is used.
  /// - Large images are resized for performance.
  /// - JPEG quality is optimized for PPTX size/quality.
  /// - Heavy processing runs in a background isolate.
  Future<DocumentResult> generatePptxFromImages(
    List<String> imagePaths,
  ) async {
    if (imagePaths.isEmpty) {
      throw Exception(
        'Cannot generate PowerPoint presentation: no images provided.',
      );
    }

    final startTimestamp = DateTime.now();

    final paths = List<String>.from(imagePaths);

    // ============================================================
    // BACKGROUND GENERATION
    // ============================================================

    final Uint8List pptxBytes = await Isolate.run(
      () => _generatePptxInBackground(paths),
    );

    if (pptxBytes.isEmpty) {
      throw Exception(
        'Generated PowerPoint presentation is empty.',
      );
    }

    // ============================================================
    // FILE NAME
    // ============================================================

    final fileName = await FileUtils.generatePdfFileName(
      ConversionType.ppt,
    );

    // ============================================================
    // APP DOCUMENT DIRECTORY
    // ============================================================

    final appDocDir =
        await FileUtils.getAppDocumentsDirectory();

    final destinationPath =
        '${appDocDir.path}/$fileName';

    // ============================================================
    // SAVE
    // ============================================================

    final targetFile = File(destinationPath);

    await targetFile.writeAsBytes(
      pptxBytes,
      flush: true,
    );

    // ============================================================
    // VERIFY
    // ============================================================

    if (!await targetFile.exists()) {
      throw Exception(
        'Failed to create PowerPoint presentation.',
      );
    }

    final fileSize = await targetFile.length();

    if (fileSize <= 0) {
      throw Exception(
        'Generated PowerPoint presentation is empty.',
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
      conversionType: ConversionType.ppt,
    );
  }
}

// ============================================================================
// BACKGROUND PPTX GENERATION
// ============================================================================

Uint8List _generatePptxInBackground(
  List<String> imagePaths,
) {
  if (imagePaths.isEmpty) {
    throw Exception(
      'No images were provided for PowerPoint generation.',
    );
  }

  final archive = Archive();

  final int slideCount = imagePaths.length;

  // ==========================================================================
  // IMAGE OPTIMIZATION
  // ==========================================================================

  const int maxImageDimension = 2400;

  const int jpegQuality = 90;

  // ==========================================================================
  // POWERPOINT SLIDE SIZE
  //
  // 4:3 LANDSCAPE
  //
  // 10 x 7.5 inches
  //
  // This gives:
  //
  // 10 / 7.5 = 1.333333...
  //
  // Same aspect ratio as the screenshot/view the user wants.
  // ==========================================================================

  const double presentationWidth = 10.0;

  const double presentationHeight = 7.5;

  final int slideWidthEmu =
      _inchesToEmu(presentationWidth);

  final int slideHeightEmu =
      _inchesToEmu(presentationHeight);

  if (slideWidthEmu <= 0 ||
      slideHeightEmu <= 0) {
    throw Exception(
      'Invalid PowerPoint slide dimensions.',
    );
  }

  // ==========================================================================
  // CONTENT TYPES
  // ==========================================================================

  _addTextFile(
    archive,
    '[Content_Types].xml',
    _buildContentTypesXml(slideCount),
  );

  // ==========================================================================
  // ROOT RELATIONSHIPS
  // ==========================================================================

  _addTextFile(
    archive,
    '_rels/.rels',
    _buildRootRelsXml(),
  );

  // ==========================================================================
  // PRESENTATION
  // ==========================================================================

  _addTextFile(
    archive,
    'ppt/presentation.xml',
    _buildPresentationXml(
      slideCount,
      slideWidthEmu,
      slideHeightEmu,
    ),
  );

  // ==========================================================================
  // PRESENTATION RELATIONSHIPS
  // ==========================================================================

  _addTextFile(
    archive,
    'ppt/_rels/presentation.xml.rels',
    _buildPresentationRelsXml(
      slideCount,
    ),
  );

  // ==========================================================================
  // POWERPOINT MASTER / LAYOUT / THEME
  // ==========================================================================

  _addPptTemplateBoilerplate(
    archive,
  );

  // ==========================================================================
  // PROCESS EACH IMAGE
  // ==========================================================================

  for (int i = 0; i < slideCount; i++) {
    final int slideNumber = i + 1;

    final String imagePath = imagePaths[i];

    final File imageFile = File(imagePath);

    // ------------------------------------------------------------------------
    // CHECK FILE
    // ------------------------------------------------------------------------

    if (!imageFile.existsSync()) {
      throw Exception(
        'Image file not found: $imagePath',
      );
    }

    // ------------------------------------------------------------------------
    // READ IMAGE
    //
    // File.readAsBytesSync() returns Uint8List.
    // We explicitly keep the type as Uint8List because image package
    // decodeImage/decodeNamedImage expects Uint8List.
    // ------------------------------------------------------------------------

    final Uint8List bytes =
        imageFile.readAsBytesSync();

    if (bytes.isEmpty) {
      throw Exception(
        'Image file is empty: $imagePath',
      );
    }

    // ------------------------------------------------------------------------
    // DECODE IMAGE
    //
    // decodeNamedImage() uses the file extension to select the decoder.
    //
    // Example:
    // .jpg  -> JPEG decoder
    // .png  -> PNG decoder
    // .webp -> WebP decoder
    //
    // This avoids the List<int> vs Uint8List problem.
    // ------------------------------------------------------------------------

    img.Image? decoded =
        img.decodeNamedImage(
      imagePath,
      bytes,
    );

    // ------------------------------------------------------------------------
    // FALLBACK DECODER
    // ------------------------------------------------------------------------

    if (decoded == null) {
      decoded = img.decodeImage(
        bytes,
      );
    }

    if (decoded == null) {
      throw Exception(
        'Failed to decode image: $imagePath',
      );
    }

    // ------------------------------------------------------------------------
    // VALIDATE DIMENSIONS
    // ------------------------------------------------------------------------

    if (decoded.width <= 0 ||
        decoded.height <= 0) {
      throw Exception(
        'Invalid image dimensions: $imagePath',
      );
    }

    // ==========================================================================
    // RESIZE LARGE IMAGE
    //
    // SAME SCALE FOR WIDTH + HEIGHT
    //
    // This preserves the original aspect ratio.
    // ==========================================================================

    if (decoded.width > maxImageDimension ||
        decoded.height > maxImageDimension) {
      final double widthScale =
          maxImageDimension /
              decoded.width;

      final double heightScale =
          maxImageDimension /
              decoded.height;

      final double resizeScale =
          widthScale < heightScale
              ? widthScale
              : heightScale;

      final int newWidth =
          (decoded.width * resizeScale)
              .round();

      final int newHeight =
          (decoded.height * resizeScale)
              .round();

      decoded = img.copyResize(
        decoded,
        width: newWidth,
        height: newHeight,
        interpolation:
            img.Interpolation.linear,
      );
    }

    // ==========================================================================
    // JPEG ENCODE
    // ==========================================================================

    final Uint8List jpegBytes =
        img.encodeJpg(
      decoded,
      quality: jpegQuality,
    );

    if (jpegBytes.isEmpty) {
      throw Exception(
        'Failed to encode image: $imagePath',
      );
    }

    // ==========================================================================
    // IMAGE DIMENSIONS
    // ==========================================================================

    final double imageWidthPx =
        decoded.width.toDouble();

    final double imageHeightPx =
        decoded.height.toDouble();

    if (imageWidthPx <= 0 ||
        imageHeightPx <= 0) {
      throw Exception(
        'Invalid image size: $imagePath',
      );
    }

    // ==========================================================================
    // PIXELS -> EMU
    //
    // 96 DPI:
    //
    // 1 inch = 96 pixels
    // 1 inch = 914400 EMU
    //
    // Therefore:
    //
    // 1 pixel = 9525 EMU
    // ==========================================================================

    final double imageWidthEmu =
        imageWidthPx * 9525.0;

    final double imageHeightEmu =
        imageHeightPx * 9525.0;

    if (imageWidthEmu <= 0 ||
        imageHeightEmu <= 0) {
      throw Exception(
        'Invalid image EMU dimensions: $imagePath',
      );
    }

    // ==========================================================================
    // CONTAIN / FIT
    //
    // IMPORTANT:
    //
    // NO CROP
    // NO STRETCH
    // NO DISTORTION
    //
    // The smaller scale is selected so the COMPLETE image remains visible.
    // ==========================================================================

    final double scaleX =
        slideWidthEmu /
            imageWidthEmu;

    final double scaleY =
        slideHeightEmu /
            imageHeightEmu;

    final double scale =
        scaleX < scaleY
            ? scaleX
            : scaleY;

    if (scale <= 0) {
      throw Exception(
        'Invalid image scale: $imagePath',
      );
    }

    final int renderedWidthEmu =
        (imageWidthEmu * scale)
            .round();

    final int renderedHeightEmu =
        (imageHeightEmu * scale)
            .round();

    if (renderedWidthEmu <= 0 ||
        renderedHeightEmu <= 0) {
      throw Exception(
        'Invalid rendered image dimensions: $imagePath',
      );
    }

    // ==========================================================================
    // CENTER IMAGE
    // ==========================================================================

    final int offsetX =
        ((slideWidthEmu -
                    renderedWidthEmu) /
                2)
            .round();

    final int offsetY =
        ((slideHeightEmu -
                    renderedHeightEmu) /
                2)
            .round();

    // ==========================================================================
    // SAFETY CHECK
    //
    // Keep image completely inside slide.
    // ==========================================================================

    final int safeOffsetX =
        offsetX < 0 ? 0 : offsetX;

    final int safeOffsetY =
        offsetY < 0 ? 0 : offsetY;

    // ==========================================================================
    // ADD IMAGE TO PPTX
    // ==========================================================================

    final String mediaPath =
        'ppt/media/image$slideNumber.jpeg';

    archive.addFile(
      ArchiveFile.noCompress(
        mediaPath,
        jpegBytes.length,
        jpegBytes,
      ),
    );

    // ==========================================================================
    // SLIDE XML
    // ==========================================================================

    _addTextFile(
      archive,
      'ppt/slides/slide$slideNumber.xml',
      _buildSlideXml(
        slideWidthEmu: slideWidthEmu,
        slideHeightEmu: slideHeightEmu,
        imageWidthEmu: renderedWidthEmu,
        imageHeightEmu: renderedHeightEmu,
        offsetX: safeOffsetX,
        offsetY: safeOffsetY,
      ),
    );

    // ==========================================================================
    // SLIDE RELATIONSHIPS
    // ==========================================================================

    _addTextFile(
      archive,
      'ppt/slides/_rels/slide$slideNumber.xml.rels',
      _buildSlideRelsXml(
        slideNumber,
      ),
    );
  }

  // ==========================================================================
  // ZIP / PPTX ENCODE
  // ==========================================================================

  final ZipEncoder zipEncoder =
      ZipEncoder();

  final List<int> encodedBytes =
      zipEncoder.encode(
    archive,
    level: DeflateLevel.bestSpeed,
  );

  if (encodedBytes.isEmpty) {
    throw Exception(
      'Failed to encode PowerPoint archive.',
    );
  }

  return Uint8List.fromList(
    encodedBytes,
  );
}

// ============================================================================
// UNIT CONVERSION
// ============================================================================

int _inchesToEmu(
  double inches,
) {
  return (inches * 914400).round();
}

// ============================================================================
// ADD TEXT FILE TO ARCHIVE
// ============================================================================

void _addTextFile(
  Archive archive,
  String path,
  String content,
) {
  final List<int> bytes =
      utf8.encode(content);

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

  // --------------------------------------------------------------------------
  // RELATIONSHIPS
  // --------------------------------------------------------------------------

  sb.writeln(
    '<Default '
    'Extension="rels" '
    'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
  );

  // --------------------------------------------------------------------------
  // XML
  // --------------------------------------------------------------------------

  sb.writeln(
    '<Default '
    'Extension="xml" '
    'ContentType="application/xml"/>',
  );

  // --------------------------------------------------------------------------
  // JPEG
  // --------------------------------------------------------------------------

  sb.writeln(
    '<Default '
    'Extension="jpeg" '
    'ContentType="image/jpeg"/>',
  );

  // --------------------------------------------------------------------------
  // PRESENTATION
  // --------------------------------------------------------------------------

  sb.writeln(
    '<Override '
    'PartName="/ppt/presentation.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>',
  );

  // --------------------------------------------------------------------------
  // SLIDE MASTER
  // --------------------------------------------------------------------------

  sb.writeln(
    '<Override '
    'PartName="/ppt/slideMasters/slideMaster1.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>',
  );

  // --------------------------------------------------------------------------
  // SLIDE LAYOUT
  // --------------------------------------------------------------------------

  sb.writeln(
    '<Override '
    'PartName="/ppt/slideLayouts/slideLayout1.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>',
  );

  // --------------------------------------------------------------------------
  // THEME
  // --------------------------------------------------------------------------

  sb.writeln(
    '<Override '
    'PartName="/ppt/theme/theme1.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>',
  );

  // --------------------------------------------------------------------------
  // SLIDES
  // --------------------------------------------------------------------------

  for (int i = 1; i <= slideCount; i++) {
    sb.writeln(
      '<Override '
      'PartName="/ppt/slides/slide$i.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
    );
  }

  sb.writeln(
    '</Types>',
  );

  return sb.toString();
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
    Target="ppt/presentation.xml"/>

</Relationships>''';
}

// ============================================================================
// PRESENTATION XML
// ============================================================================

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

  // ==========================================================================
  // SLIDE MASTER LIST
  // ==========================================================================

  sb.writeln(
    '<p:sldMasterIdLst>',
  );

  sb.writeln(
    '<p:sldMasterId '
    'id="2147483648" '
    'r:id="rIdMaster1"/>',
  );

  sb.writeln(
    '</p:sldMasterIdLst>',
  );

  // ==========================================================================
  // SLIDE LIST
  // ==========================================================================

  sb.writeln(
    '<p:sldIdLst>',
  );

  for (int i = 1; i <= slideCount; i++) {
    sb.writeln(
      '<p:sldId '
      'id="${255 + i}" '
      'r:id="rIdSlide$i"/>',
    );
  }

  sb.writeln(
    '</p:sldIdLst>',
  );

  // ==========================================================================
  // 4:3 LANDSCAPE SLIDE SIZE
  // ==========================================================================

  sb.writeln(
    '<p:sldSz '
    'cx="$slideWidthEmu" '
    'cy="$slideHeightEmu" '
    'type="screen4x3"/>',
  );

  // ==========================================================================
  // NOTES SIZE
  // ==========================================================================

  sb.writeln(
    '<p:notesSz '
    'cx="6858000" '
    'cy="9144000"/>',
  );

  // ==========================================================================
  // DEFAULT TEXT STYLE
  // ==========================================================================

  sb.writeln(
    '<p:defaultTextStyle>',
  );

  sb.writeln(
    '<a:defPPr/>',
  );

  sb.writeln(
    '<a:lvl1pPr '
    'marL="0" '
    'algn="l">',
  );

  sb.writeln(
    '<a:defRPr '
    'sz="1800"/>',
  );

  sb.writeln(
    '</a:lvl1pPr>',
  );

  sb.writeln(
    '</p:defaultTextStyle>',
  );

  sb.writeln(
    '</p:presentation>',
  );

  return sb.toString();
}

// ============================================================================
// PRESENTATION RELATIONSHIPS
// ============================================================================

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

  // ==========================================================================
  // MASTER
  // ==========================================================================

  sb.writeln(
    '<Relationship '
    'Id="rIdMaster1" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" '
    'Target="slideMasters/slideMaster1.xml"/>',
  );

  // ==========================================================================
  // THEME
  // ==========================================================================

  sb.writeln(
    '<Relationship '
    'Id="rIdTheme1" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" '
    'Target="theme/theme1.xml"/>',
  );

  // ==========================================================================
  // SLIDES
  // ==========================================================================

  for (int i = 1; i <= slideCount; i++) {
    sb.writeln(
      '<Relationship '
      'Id="rIdSlide$i" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" '
      'Target="slides/slide$i.xml"/>',
    );
  }

  sb.writeln(
    '</Relationships>',
  );

  return sb.toString();
}

// ============================================================================
// SLIDE XML
// ============================================================================

String _buildSlideXml({
  required int slideWidthEmu,
  required int slideHeightEmu,
  required int imageWidthEmu,
  required int imageHeightEmu,
  required int offsetX,
  required int offsetY,
}) {
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">

  <p:cSld name="">

    <p:spTree>

      <!-- ================================================================ -->
      <!-- GROUP PROPERTIES                                                -->
      <!-- ================================================================ -->

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

      <!-- ================================================================ -->
      <!-- WHITE BACKGROUND                                                -->
      <!-- ================================================================ -->

      <p:sp>

        <p:nvSpPr>

          <p:cNvPr
            id="2"
            name="Background"/>

          <p:cNvSpPr/>

          <p:nvPr/>

        </p:nvSpPr>

        <p:spPr>

          <a:xfrm>

            <a:off
              x="0"
              y="0"/>

            <a:ext
              cx="$slideWidthEmu"
              cy="$slideHeightEmu"/>

          </a:xfrm>

          <a:prstGeom
            prst="rect">

            <a:avLst/>

          </a:prstGeom>

          <a:solidFill>

            <a:srgbClr
              val="FFFFFF"/>

          </a:solidFill>

          <a:ln>

            <a:noFill/>

          </a:ln>

        </p:spPr>

      </p:sp>

      <!-- ================================================================ -->
      <!-- IMAGE                                                           -->
      <!-- ================================================================ -->

      <p:pic>

        <p:nvPicPr>

          <p:cNvPr
            id="3"
            name="Image"/>

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
              cx="$imageWidthEmu"
              cy="$imageHeightEmu"/>

          </a:xfrm>

          <a:prstGeom
            prst="rect">

            <a:avLst/>

          </a:prstGeom>

        </p:spPr>

      </p:pic>

    </p:spTree>

  </p:cSld>

  <!-- ================================================================ -->
  <!-- COLOR MAP                                                       -->
  <!-- ================================================================ -->

  <p:clrMapOvr>

    <a:masterClrMapping/>

  </p:clrMapOvr>

</p:sld>''';
}

// ============================================================================
// SLIDE RELATIONSHIPS
// ============================================================================

String _buildSlideRelsXml(
  int slideNumber,
) {
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships
  xmlns="http://schemas.openxmlformats.org/package/2006/relationships">

  <!-- ================================================================ -->
  <!-- SLIDE LAYOUT                                                     -->
  <!-- ================================================================ -->

  <Relationship
    Id="rIdLayout"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout"
    Target="../slideLayouts/slideLayout1.xml"/>

  <!-- ================================================================ -->
  <!-- IMAGE                                                             -->
  <!-- ================================================================ -->

  <Relationship
    Id="rIdImage"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"
    Target="../media/image$slideNumber.jpeg"/>

</Relationships>''';
}

// ============================================================================
// POWERPOINT BOILERPLATE
// ============================================================================

void _addPptTemplateBoilerplate(
  Archive archive,
) {
  // ==========================================================================
  // SLIDE LAYOUT
  // ==========================================================================

  const String slideLayoutXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
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

  // ==========================================================================
  // SLIDE LAYOUT RELATIONSHIPS
  // ==========================================================================

  const String slideLayoutRelsXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
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

  // ==========================================================================
  // SLIDE MASTER
  // ==========================================================================

  const String slideMasterXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
  preserve="1">

  <!-- ================================================================ -->
  <!-- COMMON SLIDE DATA                                                -->
  <!-- ================================================================ -->

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

  <!-- ================================================================ -->
  <!-- COLOR MAP                                                        -->
  <!-- ================================================================ -->

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

  <!-- ================================================================ -->
  <!-- SLIDE LAYOUT LIST                                                -->
  <!-- ================================================================ -->

  <p:sldLayoutIdLst>

    <p:sldLayoutId
      id="2147483649"
      r:id="rIdLayout1"/>

  </p:sldLayoutIdLst>

  <!-- ================================================================ -->
  <!-- TEXT STYLES                                                       -->
  <!-- ================================================================ -->

  <p:txStyles>

    <p:titleStyle>

      <a:lvl1pPr
        marL="0"
        algn="l">

        <a:defRPr
          sz="4400"/>

      </a:lvl1pPr>

    </p:titleStyle>

    <p:bodyStyle>

      <a:lvl1pPr
        marL="0"
        algn="l">

        <a:defRPr
          sz="2400"/>

      </a:lvl1pPr>

    </p:bodyStyle>

    <p:otherStyle>

      <a:defPPr/>

    </p:otherStyle>

  </p:txStyles>

</p:sldMaster>''';

  _addTextFile(
    archive,
    'ppt/slideMasters/slideMaster1.xml',
    slideMasterXml,
  );

  // ==========================================================================
  // SLIDE MASTER RELATIONSHIPS
  // ==========================================================================

  const String slideMasterRelsXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
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

  // ==========================================================================
  // THEME
  // ==========================================================================

  const String themeXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  name="Office Theme">

  <a:themeElements>

    <!-- ============================================================ -->
    <!-- COLOR SCHEME                                                 -->
    <!-- ============================================================ -->

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

    <!-- ============================================================ -->
    <!-- FONT SCHEME                                                   -->
    <!-- ============================================================ -->

    <a:fontScheme
      name="Office">

      <a:majorFont>

        <a:latin
          typeface="Calibri"/>

        <a:ea
          typeface=""/>

        <a:cs
          typeface=""/>

      </a:majorFont>

      <a:minorFont>

        <a:latin
          typeface="Calibri"/>

        <a:ea
          typeface=""/>

        <a:cs
          typeface=""/>

      </a:minorFont>

    </a:fontScheme>

    <!-- ============================================================ -->
    <!-- FORMAT SCHEME                                                 -->
    <!-- ============================================================ -->

    <a:fmtScheme
      name="Office">

      <!-- ---------------------------------------------------------- -->
      <!-- FILL STYLES                                                -->
      <!-- ---------------------------------------------------------- -->

      <a:fillStyleLst>

        <a:solidFill>

          <a:schemeClr
            val="phClr"/>

        </a:solidFill>

        <a:gradFill
          rotWithShape="1">

          <a:gsLst>

            <a:gs
              pos="0">

              <a:schemeClr
                val="phClr"/>

            </a:gs>

            <a:gs
              pos="100000">

              <a:schemeClr
                val="phClr"/>

            </a:gs>

          </a:gsLst>

          <a:lin
            ang="5400000"
            scaled="1"/>

        </a:gradFill>

        <a:gradFill
          rotWithShape="1">

          <a:gsLst>

            <a:gs
              pos="0">

              <a:schemeClr
                val="phClr"/>

            </a:gs>

            <a:gs
              pos="100000">

              <a:schemeClr
                val="phClr"/>

            </a:gs>

          </a:gsLst>

          <a:lin
            ang="5400000"
            scaled="1"/>

        </a:gradFill>

      </a:fillStyleLst>

      <!-- ---------------------------------------------------------- -->
      <!-- LINE STYLES                                                 -->
      <!-- ---------------------------------------------------------- -->

      <a:lnStyleLst>

        <a:ln
          w="9525"
          cap="flat"
          cmpd="sng"
          algn="ctr">

          <a:solidFill>

            <a:schemeClr
              val="phClr"/>

          </a:solidFill>

          <a:prstDash
            val="solid"/>

        </a:ln>

        <a:ln
          w="25400"
          cap="flat"
          cmpd="sng"
          algn="ctr">

          <a:solidFill>

            <a:schemeClr
              val="phClr"/>

          </a:solidFill>

          <a:prstDash
            val="solid"/>

        </a:ln>

        <a:ln
          w="38100"
          cap="flat"
          cmpd="sng"
          algn="ctr">

          <a:solidFill>

            <a:schemeClr
              val="phClr"/>

          </a:solidFill>

          <a:prstDash
            val="solid"/>

        </a:ln>

      </a:lnStyleLst>

      <!-- ---------------------------------------------------------- -->
      <!-- EFFECT STYLES                                               -->
      <!-- ---------------------------------------------------------- -->

      <a:effectStyleLst>

        <a:effectStyle>

          <a:effectLst/>

        </a:effectStyle>

        <a:effectStyle>

          <a:effectLst/>

        </a:effectStyle>

        <a:effectStyle>

          <a:effectLst/>

        </a:effectStyle>

      </a:effectStyleLst>

      <!-- ---------------------------------------------------------- -->
      <!-- BACKGROUND FILL STYLES                                      -->
      <!-- ---------------------------------------------------------- -->

      <a:bgFillStyleLst>

        <a:solidFill>

          <a:schemeClr
            val="phClr"/>

        </a:solidFill>

        <a:gradFill
          rotWithShape="1">

          <a:gsLst>

            <a:gs
              pos="0">

              <a:schemeClr
                val="phClr"/>

            </a:gs>

            <a:gs
              pos="100000">

              <a:schemeClr
                val="phClr"/>

            </a:gs>

          </a:gsLst>

          <a:lin
            ang="5400000"
            scaled="1"/>

        </a:gradFill>

        <a:gradFill
          rotWithShape="1">

          <a:gsLst>

            <a:gs
              pos="0">

              <a:schemeClr
                val="phClr"/>

            </a:gs>

            <a:gs
              pos="100000">

              <a:schemeClr
                val="phClr"/>

            </a:gs>

          </a:gsLst>

          <a:lin
            ang="5400000"
            scaled="1"/>

        </a:gradFill>

      </a:bgFillStyleLst>

    </a:fmtScheme>

  </a:themeElements>

</a:theme>''';

  _addTextFile(
    archive,
    'ppt/theme/theme1.xml',
    themeXml,
  );
}