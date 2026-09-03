import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/document_edge_detector.dart';
import '../../core/services/gallery_service.dart';
import '../../core/providers/image_selection_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/conversion_type.dart';
import '../pdf_generation/review_screen.dart';

class CameraScreen extends StatefulWidget {
  final ConversionType conversionType;

  const CameraScreen({
    super.key,
    this.conversionType = ConversionType.pdf,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraService _cameraService;

  bool _isInitializing = true;
  String? _errorMessage;
  int _captureCount = 0;
  bool _isCapturing = false;

  // Live document-edge overlay (drawn while the camera is pointed at
  // the document, before capture). `null` means nothing confident
  // enough has been detected in the most recent frame.
  LiveDetectedQuad? _liveQuad;

  @override
  void initState() {
    super.initState();

    // The live-detection rotation math (see CameraService /
    // _rotateNormalizedCW) assumes a fixed portrait sensor
    // orientation. Scanner apps conventionally shoot in portrait
    // anyway, so this locks orientation only for the lifetime of
    // this screen -- the smallest change that makes the overlay
    // math well-defined, per the "don't change existing UX" rule
    // this only constrains an already-camera-specific screen.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    _cameraService = CameraService();

    _initializeCamera();
  }

  // ==========================================================
  // INITIALIZE CAMERA
  // ==========================================================

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initializeCamera();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });

        _cameraService.startLiveDetection(
          onQuadDetected: (quad) {
            if (!mounted) return;

            setState(() {
              _liveQuad = quad;
            });
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = AppConstants.cameraInitFailed;
        });
      }
    }
  }

  // ==========================================================
  // CAPTURE PHOTO
  // ==========================================================

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;

    try {
      setState(() {
        _isCapturing = true;
      });

      // Some camera-plugin versions don't support taking a still
      // photo while an image stream is active. Pausing/resuming
      // around the capture keeps the (already working) capture flow
      // exactly as reliable as before this feature was added.
      await _cameraService.stopLiveDetection();

      final image =
          await _cameraService.capturePhoto();

      if (mounted) {
        _cameraService.startLiveDetection(
          onQuadDetected: (quad) {
            if (!mounted) return;

            setState(() {
              _liveQuad = quad;
            });
          },
        );
      }

      if (image != null && mounted) {
        context
            .read<ImageSelectionProvider>()
            .addImages(
          [
            image.path,
          ],
          'camera',
        );

        setState(() {
          _captureCount++;
          _isCapturing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Text(
                  'Photo captured ($_captureCount)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(16),
            ),
          ),
        );
      } else {
        if (mounted) {
          setState(() {
            _isCapturing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });

        // Capture failed -- make sure the live overlay comes back
        // instead of staying frozen from the pre-capture pause.
        _cameraService.startLiveDetection(
          onQuadDetected: (quad) {
            if (!mounted) return;

            setState(() {
              _liveQuad = quad;
            });
          },
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'Failed to capture photo',
                ),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(16),
            ),
          ),
        );
      }
    }
  }

  // ==========================================================
  // EFFECTIVE CONVERSION TYPE
  // ==========================================================

  ConversionType get _effectiveType {
    final routeArgs =
        ModalRoute.of(context)?.settings.arguments;

    if (routeArgs is ConversionType) {
      return routeArgs;
    }

    return widget.conversionType;
  }

  // ==========================================================
  // GO TO REVIEW
  // ==========================================================

  void _goToReview() {
    if (_captureCount <= 0) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          conversionType: _effectiveType,
        ),
      ),
    );
  }

  // ==========================================================
  // GO TO GALLERY
  // ==========================================================

  Future<void> _goToGallery() async {
    try {
      final galleryService =
          GalleryService();

      final imagePaths =
          await galleryService.pickImages();

      if (!mounted) return;

      if (imagePaths.isNotEmpty) {
        context
            .read<ImageSelectionProvider>()
            .addImages(
          imagePaths,
          'gallery',
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ReviewScreen(
              conversionType: _effectiveType,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'Failed to open gallery',
                ),
              ],
            ),
            backgroundColor:
                AppTheme.errorColor,
            behavior:
                SnackBarBehavior.floating,
            margin:
                const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(16),
            ),
          ),
        );
      }
    }
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _cameraService.dispose();

    // Restore the device's normal orientation behavior once this
    // screen is gone.
    SystemChrome.setPreferredOrientations(
      DeviceOrientation.values,
    );

    super.dispose();
  }

  // ==========================================================
  // LIVE DOCUMENT-EDGE OVERLAY
  // ==========================================================
  //
  // Draws whatever quad the background detector most recently found
  // (see CameraService.startLiveDetection), mapped through the same
  // BoxFit.cover math `_buildCameraPreview` uses so the outline
  // lines up with what's actually visible on screen.

  Widget _buildLiveDetectionOverlay() {
    final controller = _cameraService.controller;

    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final previewSize = controller.value.previewSize;

    // Matches the width/height swap in _buildCameraPreview.
    final double sourceWidth = previewSize?.height ?? 1.0;
    final double sourceHeight = previewSize?.width ?? 1.0;

    final quad = _liveQuad;

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _LiveQuadPainter(
            quad: quad,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            color: quad != null && quad.score >= 0.55
                ? const Color(0xFF00E5A0)
                : Colors.white,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // CAMERA PREVIEW
  // ==========================================================

  Widget _buildCameraPreview() {
    final controller =
        _cameraService.controller;

    if (!controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
      );
    }

    return Positioned.fill(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width:
              controller.value.previewSize?.height ??
                  1,
          height:
              controller.value.previewSize?.width ??
                  1,
          child:
              CameraPreview(controller),
        ),
      ),
    );
  }

  // ==========================================================
  // GLASS BUTTON
  // ==========================================================

  Widget _glassButton({
    required Widget child,
    required VoidCallback onTap,
    double padding = 12,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(18),
        child: Container(
          padding:
              EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: 0.42,
            ),
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.16,
              ),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.25,
                ),
                blurRadius: 15,
                offset:
                    const Offset(0, 5),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    final isDark =
        theme.brightness ==
            Brightness.dark;

    // ========================================================
    // INITIALIZING
    // ========================================================

    if (_isInitializing) {
      return Scaffold(
        backgroundColor:
            colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.accentColor,
                    ],
                  ),
                  shape:
                      BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor
                          .withValues(
                        alpha: 0.35,
                      ),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              Text(
                'Starting Camera',
                style: TextStyle(
                  color:
                      colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                'Please wait...',
                style: TextStyle(
                  color: colorScheme.onSurface
                      .withValues(
                    alpha: 0.55,
                  ),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ========================================================
    // CAMERA ERROR
    // ========================================================

    if (_errorMessage != null) {
      final responsivePadding =
          ResponsiveHelper
              .getResponsivePadding(
        context,
      );

      final buttonHeight =
          ResponsiveHelper
              .getResponsiveButtonHeight(
        context,
      );

      final errorIconSize =
          ResponsiveHelper.isTablet(context)
              ? 70.0
              : 60.0;

      final errorTextSize =
          ResponsiveHelper
              .getResponsiveFontSize(
        context,
        mobileSize: 15,
        tabletSize: 16,
        desktopSize: 17,
      );

      return Scaffold(
        backgroundColor:
            colorScheme.surface,
        appBar: AppBar(
          title: const Text(
            AppConstants.camera,
          ),
          backgroundColor:
              colorScheme.surface,
          foregroundColor:
              colorScheme.onSurface,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(
              responsivePadding,
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width:
                      errorIconSize + 30,
                  height:
                      errorIconSize + 30,
                  decoration:
                      BoxDecoration(
                    color: AppTheme.errorColor
                        .withValues(
                      alpha:
                          isDark ? 0.14 : 0.08,
                    ),
                    shape:
                        BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size:
                        errorIconSize,
                    color:
                        AppTheme.errorColor,
                  ),
                ),

                SizedBox(
                  height:
                      responsivePadding,
                ),

                Text(
                  _errorMessage!,
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize:
                        errorTextSize,
                    height: 1.5,
                    color:
                        colorScheme.onSurface,
                  ),
                ),

                SizedBox(
                  height:
                      responsivePadding * 1.33,
                ),

                SizedBox(
                  height:
                      buttonHeight,
                  width:
                      double.infinity,
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        _goToGallery,
                    icon: const Icon(
                      Icons
                          .photo_library_outlined,
                    ),
                    label: const Text(
                      'Use Gallery Instead',
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          colorScheme.primary,
                      foregroundColor:
                          colorScheme.onPrimary,
                      elevation: 0,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ========================================================
    // CAMERA UI
    // ========================================================

    return PopScope(
      canPop: true,
      onPopInvokedWithResult:
          (didPop, result) {
        if (!didPop) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        backgroundColor:
            Colors.black,
        body: Stack(
          fit:
              StackFit.expand,
          children: [
            _buildCameraPreview(),

            // ==================================================
            // LIVE DOCUMENT-EDGE OVERLAY
            // ==================================================

            _buildLiveDetectionOverlay(),

            // ==================================================
            // DARK OVERLAY
            // ==================================================

            Positioned.fill(
              child:
                  IgnorePointer(
                child:
                    DecoratedBox(
                  decoration:
                      BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topCenter,
                      end:
                          Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(
                          alpha: 0.48,
                        ),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(
                          alpha: 0.82,
                        ),
                      ],
                      stops: const [
                        0.0,
                        0.25,
                        0.55,
                        1.0,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ==================================================
            // TOP BAR
            // ==================================================

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child:
                  SafeArea(
                child:
                    Padding(
                  padding:
                      EdgeInsets.fromLTRB(
                    ResponsiveHelper
                            .isMobile(context)
                        ? 18
                        : 26,
                    12,
                    ResponsiveHelper
                            .isMobile(context)
                        ? 18
                        : 26,
                    0,
                  ),
                  child: Row(
                    children: [
                      _glassButton(
                        onTap: () {
                          Navigator.of(context)
                              .maybePop();
                        },
                        padding:
                            ResponsiveHelper
                                    .isMobile(
                          context,
                        )
                                ? 10
                                : 12,
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color:
                              Colors.white,
                          size:
                              ResponsiveHelper
                                      .isMobile(
                            context,
                          )
                                  ? 24
                                  : 28,
                        ),
                      ),

                      const SizedBox(
                        width: 14,
                      ),

                      Expanded(
                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'Scan Document',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 19,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),

                            const SizedBox(
                              height: 2,
                            ),

                            Text(
                              'Capture multiple images',
                              style:
                                  TextStyle(
                                color: Colors.white
                                    .withValues(
                                  alpha: 0.68,
                                ),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      AnimatedContainer(
                        duration:
                            const Duration(
                          milliseconds: 250,
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration:
                            BoxDecoration(
                          gradient:
                              LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.accentColor,
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            22,
                          ),
                        ),
                        child: Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons
                                  .collections_rounded,
                              color:
                                  Colors.white,
                              size: 17,
                            ),

                            const SizedBox(
                              width: 6,
                            ),

                            Text(
                              '$_captureCount',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ==================================================
            // BOTTOM CONTROLS
            // ==================================================

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child:
                  SafeArea(
                top: false,
                child:
                    Container(
                  padding:
                      EdgeInsets.fromLTRB(
                    22,
                    22,
                    22,
                    ResponsiveHelper
                            .isMobile(context)
                        ? 18
                        : 24,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.black.withValues(
                      alpha: 0.68,
                    ),
                  ),
                  child:
                      Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Text(
                        _captureCount == 0
                            ? 'Capture all pages, then tap Done'
                            : '$_captureCount photo${_captureCount == 1 ? '' : 's'} captured',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color:
                              Colors.white
                                  .withValues(
                            alpha: 0.70,
                          ),
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.center,
                        children: [
                          // GALLERY

                          Expanded(
                            child:
                                Align(
                              alignment:
                                  Alignment.centerLeft,
                              child:
                                  _glassButton(
                                onTap:
                                    _goToGallery,
                                padding:
                                    13,
                                child:
                                    const Icon(
                                  Icons
                                      .photo_library_outlined,
                                  color:
                                      Colors.white,
                                  size: 27,
                                ),
                              ),
                            ),
                          ),

                          // CAMERA BUTTON

                          GestureDetector(
                            onTap:
                                _isCapturing
                                    ? null
                                    : _capturePhoto,
                            child:
                                AnimatedContainer(
                              duration:
                                  const Duration(
                                milliseconds: 180,
                              ),
                              width: 82,
                              height: 82,
                              decoration:
                                  BoxDecoration(
                                shape:
                                    BoxShape.circle,
                                gradient:
                                    LinearGradient(
                                  begin:
                                      Alignment
                                          .topLeft,
                                  end:
                                      Alignment
                                          .bottomRight,
                                  colors: [
                                    AppTheme
                                        .primaryColor,
                                    AppTheme
                                        .accentColor,
                                  ],
                                ),
                                border:
                                    Border.all(
                                  color:
                                      Colors.white,
                                  width: 4,
                                ),
                              ),
                              child:
                                  Center(
                                child:
                                    _isCapturing
                                        ? const SizedBox(
                                            width:
                                                29,
                                            height:
                                                29,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth:
                                                  3,
                                              color:
                                                  Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons
                                                .camera_alt_rounded,
                                            color:
                                                Colors.white,
                                            size:
                                                34,
                                          ),
                              ),
                            ),
                          ),

                          // DONE

                          Expanded(
                            child:
                                Align(
                              alignment:
                                  Alignment.centerRight,
                              child:
                                  Material(
                                color:
                                    Colors.transparent,
                                child:
                                    InkWell(
                                  onTap:
                                      _captureCount > 0
                                          ? _goToReview
                                          : null,
                                  borderRadius:
                                      BorderRadius.circular(
                                    18,
                                  ),
                                  child:
                                      AnimatedContainer(
                                    duration:
                                        const Duration(
                                      milliseconds:
                                          220,
                                    ),
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal:
                                          15,
                                      vertical:
                                          13,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          _captureCount > 0
                                              ? AppTheme
                                                  .successColor
                                              : Colors
                                                  .white
                                                  .withValues(
                                                  alpha:
                                                      0.09,
                                                ),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        18,
                                      ),
                                    ),
                                    child:
                                        Row(
                                      mainAxisSize:
                                          MainAxisSize
                                              .min,
                                      children: [
                                        Icon(
                                          Icons
                                              .check_rounded,
                                          color:
                                              _captureCount > 0
                                                  ? Colors
                                                      .white
                                                  : Colors
                                                      .white38,
                                          size:
                                              22,
                                        ),

                                        if (_captureCount >
                                            0) ...[
                                          const SizedBox(
                                            width:
                                                5,
                                          ),
                                          const Text(
                                            'Done',
                                            style:
                                                TextStyle(
                                              color:
                                                  Colors
                                                      .white,
                                              fontSize:
                                                  14,
                                              fontWeight:
                                                  FontWeight
                                                      .w800,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LIVE QUAD PAINTER
// ============================================================

class _LiveQuadPainter extends CustomPainter {
  final LiveDetectedQuad? quad;
  final double sourceWidth;
  final double sourceHeight;
  final Color color;

  const _LiveQuadPainter({
    required this.quad,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final q = quad;

    if (q == null ||
        sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    // Reproduce the same BoxFit.cover crop `_buildCameraPreview`
    // renders with, so the outline lines up with the visible image
    // instead of the full (partly off-screen) sensor frame.
    final srcAspect = sourceWidth / sourceHeight;
    final dstAspect = size.width / size.height;

    var uMin = 0.0, uMax = 1.0, vMin = 0.0, vMax = 1.0;

    if (srcAspect > dstAspect) {
      final visibleFraction = dstAspect / srcAspect;
      uMin = (1 - visibleFraction) / 2;
      uMax = 1 - uMin;
    } else if (srcAspect < dstAspect) {
      final visibleFraction = srcAspect / dstAspect;
      vMin = (1 - visibleFraction) / 2;
      vMax = 1 - vMin;
    }

    Offset toCanvas(EdgePoint p) {
      final u = uMax > uMin ? (p.x - uMin) / (uMax - uMin) : p.x;
      final v = vMax > vMin ? (p.y - vMin) / (vMax - vMin) : p.y;

      return Offset(u * size.width, v * size.height);
    }

    final topLeft = toCanvas(q.topLeft);
    final topRight = toCanvas(q.topRight);
    final bottomRight = toCanvas(q.bottomRight);
    final bottomLeft = toCanvas(q.bottomLeft);

    final path = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    final dotPaint = Paint()..color = color;

    for (final corner in [
      topLeft,
      topRight,
      bottomRight,
      bottomLeft,
    ]) {
      canvas.drawCircle(corner, 6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(
    covariant _LiveQuadPainter oldDelegate,
  ) {
    return oldDelegate.quad != quad ||
        oldDelegate.color != color ||
        oldDelegate.sourceWidth != sourceWidth ||
        oldDelegate.sourceHeight != sourceHeight;
  }
}