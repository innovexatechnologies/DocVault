import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/gallery_service.dart';
import '../../core/providers/image_selection_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/conversion_type.dart';
import 'filter_screen.dart';
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

  @override
  void initState() {
    super.initState();

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

      final image = await _cameraService.capturePhoto();

      if (image != null && mounted) {
        final scannedBytes = await image.readAsBytes();

        if (!mounted) return;

        final filteredBytes = await Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(
            builder: (_) => FilterScreen(
              scannedImageBytes: scannedBytes,
            ),
          ),
        );

        if (!mounted) return;

        if (filteredBytes == null) {
          setState(() {
            _isCapturing = false;
          });
          return;
        }

        await XFile.fromData(
          filteredBytes,
          name: image.name,
        ).saveTo(image.path);

        if (!mounted) return;

        context.read<ImageSelectionProvider>().addImages(
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
              borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(16),
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
    final routeArgs = ModalRoute.of(context)?.settings.arguments;

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
      final galleryService = GalleryService();

      final imagePaths = await galleryService.pickImages();

      if (!mounted) return;

      if (imagePaths.isNotEmpty) {
        context.read<ImageSelectionProvider>().addImages(
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
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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

    super.dispose();
  }

  // ==========================================================
  // CAMERA PREVIEW
  // ==========================================================

  Widget _buildCameraPreview() {
    final controller = _cameraService.controller;

    if (!controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
      );
    }

    return Positioned.fill(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 1,
          height: controller.value.previewSize?.width ?? 1,
          child: CameraPreview(controller),
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
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 15,
                offset: const Offset(0, 5),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // ========================================================
    // INITIALIZING
    // ========================================================

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.accentColor,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(
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
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Starting Camera',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait...',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(
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
          ResponsiveHelper.getResponsivePadding(context);

      final buttonHeight =
          ResponsiveHelper.getResponsiveButtonHeight(context);

      final errorIconSize =
          ResponsiveHelper.isTablet(context) ? 70.0 : 60.0;

      final errorTextSize =
          ResponsiveHelper.getResponsiveFontSize(
        context,
        mobileSize: 15,
        tabletSize: 16,
        desktopSize: 17,
      );

      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: const Text(
            AppConstants.camera,
          ),
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(
              responsivePadding,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ERROR ICON

                Container(
                  width: errorIconSize + 30,
                  height: errorIconSize + 30,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(
                      alpha: isDark ? 0.14 : 0.08,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: errorIconSize,
                    color: AppTheme.errorColor,
                  ),
                ),

                SizedBox(
                  height: responsivePadding,
                ),

                // ERROR MESSAGE

                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: errorTextSize,
                    height: 1.5,
                    color: colorScheme.onSurface,
                  ),
                ),

                SizedBox(
                  height: responsivePadding * 1.33,
                ),

                // GALLERY BUTTON

                SizedBox(
                  height: buttonHeight,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _goToGallery,
                    icon: const Icon(
                      Icons.photo_library_outlined,
                    ),
                    label: const Text(
                      'Use Gallery Instead',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ====================================================
            // CAMERA PREVIEW
            // ====================================================

            _buildCameraPreview(),

            // ====================================================
            // CAMERA DARK GRADIENT OVERLAY
            // ====================================================

            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.48),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.82),
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

            // ====================================================
            // TOP BAR
            // ====================================================

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    ResponsiveHelper.isMobile(context)
                        ? 18
                        : 26,
                    12,
                    ResponsiveHelper.isMobile(context)
                        ? 18
                        : 26,
                    0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // BACK BUTTON

                      _glassButton(
                        onTap: () {
                          Navigator.of(context).maybePop();
                        },
                        padding: ResponsiveHelper.isMobile(context)
                            ? 10
                            : 12,
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: ResponsiveHelper.isMobile(context)
                              ? 24
                              : 28,
                        ),
                      ),

                      const SizedBox(width: 14),

                      // TITLE

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Scan Document',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Capture high-quality images',
                              style: TextStyle(
                                color: Colors.white.withValues(
                                  alpha: 0.68,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // PHOTO COUNTER

                      AnimatedContainer(
                        duration: const Duration(
                          milliseconds: 250,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.accentColor,
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.35),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.collections_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$_captureCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
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

            // ====================================================
            // SCAN FRAME
            // ====================================================

            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 150,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: 0.28,
                          ),
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // TOP LEFT

                          Positioned(
                            top: -1,
                            left: -1,
                            child: _corner(
                              top: true,
                              left: true,
                            ),
                          ),

                          // TOP RIGHT

                          Positioned(
                            top: -1,
                            right: -1,
                            child: _corner(
                              top: true,
                              left: false,
                            ),
                          ),

                          // BOTTOM LEFT

                          Positioned(
                            bottom: -1,
                            left: -1,
                            child: _corner(
                              top: false,
                              left: true,
                            ),
                          ),

                          // BOTTOM RIGHT

                          Positioned(
                            bottom: -1,
                            right: -1,
                            child: _corner(
                              top: false,
                              left: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ====================================================
            // BOTTOM CONTROL AREA
            // ====================================================

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    22,
                    22,
                    ResponsiveHelper.isMobile(context)
                        ? 18
                        : 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: 0.68,
                    ),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(
                          alpha: 0.08,
                        ),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ==================================================
                      // HELPER TEXT
                      // ==================================================

                      Text(
                        _captureCount == 0
                            ? 'Position your document inside the frame'
                            : '$_captureCount photo${_captureCount == 1 ? '' : 's'} captured',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: 0.70,
                          ),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ==================================================
                      // CONTROLS
                      // ==================================================

                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.center,
                        children: [
                          // ==================================================
                          // GALLERY
                          // ==================================================

                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _glassButton(
                                onTap: _goToGallery,
                                padding: 13,
                                child: const Icon(
                                  Icons.photo_library_outlined,
                                  color: Colors.white,
                                  size: 27,
                                ),
                              ),
                            ),
                          ),

                          // ==================================================
                          // CAPTURE BUTTON
                          // ==================================================

                          GestureDetector(
                            onTap: _isCapturing
                                ? null
                                : _capturePhoto,
                            child: AnimatedContainer(
                              duration: const Duration(
                                milliseconds: 180,
                              ),
                              width: 82,
                              height: 82,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.accentColor,
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: 0.95,
                                  ),
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.55),
                                    blurRadius: 25,
                                    spreadRadius: 4,
                                  ),
                                  BoxShadow(
                                    color: AppTheme.accentColor
                                        .withValues(alpha: 0.25),
                                    blurRadius: 40,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isCapturing
                                    ? const SizedBox(
                                        width: 29,
                                        height: 29,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 34,
                                      ),
                              ),
                            ),
                          ),

                          // ==================================================
                          // DONE BUTTON
                          // ==================================================

                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _captureCount > 0
                                      ? _goToReview
                                      : null,
                                  borderRadius:
                                      BorderRadius.circular(18),
                                  child: AnimatedContainer(
                                    duration: const Duration(
                                      milliseconds: 220,
                                    ),
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 13,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: _captureCount > 0
                                          ? LinearGradient(
                                              colors: [
                                                AppTheme.successColor,
                                                const Color(
                                                  0xFF35C979,
                                                ),
                                              ],
                                            )
                                          : null,
                                      color: _captureCount == 0
                                          ? Colors.white.withValues(
                                              alpha: 0.09,
                                            )
                                          : null,
                                      borderRadius:
                                          BorderRadius.circular(18),
                                      border: Border.all(
                                        color: _captureCount > 0
                                            ? Colors.white.withValues(
                                                alpha: 0.12,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.10,
                                              ),
                                      ),
                                      boxShadow:
                                          _captureCount > 0
                                              ? [
                                                  BoxShadow(
                                                    color: AppTheme
                                                        .successColor
                                                        .withValues(
                                                      alpha: 0.30,
                                                    ),
                                                    blurRadius: 16,
                                                    offset:
                                                        const Offset(
                                                      0,
                                                      5,
                                                    ),
                                                  ),
                                                ]
                                              : null,
                                    ),
                                    child: Row(
                                      mainAxisSize:
                                          MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_rounded,
                                          color: _captureCount > 0
                                              ? Colors.white
                                              : Colors.white38,
                                          size: 22,
                                        ),
                                        if (_captureCount > 0) ...[
                                          const SizedBox(width: 5),
                                          Text(
                                            'Done',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight.w800,
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

  // ==========================================================
  // SCAN FRAME CORNER
  // ==========================================================

  Widget _corner({
    required bool top,
    required bool left,
  }) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter: _CornerPainter(
          color: AppTheme.accentColor,
          top: top,
          left: left,
        ),
      ),
    );
  }
}

// ============================================================
// CORNER PAINTER
// ============================================================

class _CornerPainter extends CustomPainter {
  final Color color;
  final bool top;
  final bool left;

  _CornerPainter({
    required this.color,
    required this.top,
    required this.left,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (top && left) {
      path.moveTo(2, size.height);
      path.lineTo(2, 7);
      path.quadraticBezierTo(
        2,
        2,
        7,
        2,
      );
      path.lineTo(size.width, 2);
    } else if (top && !left) {
      path.moveTo(0, 2);
      path.lineTo(size.width - 7, 2);
      path.quadraticBezierTo(
        size.width - 2,
        2,
        size.width - 2,
        7,
      );
      path.lineTo(size.width - 2, size.height);
    } else if (!top && left) {
      path.moveTo(2, 0);
      path.lineTo(2, size.height - 7);
      path.quadraticBezierTo(
        2,
        size.height - 2,
        7,
        size.height - 2,
      );
      path.lineTo(size.width, size.height - 2);
    } else {
      path.moveTo(0, size.height - 2);
      path.lineTo(size.width - 7, size.height - 2);
      path.quadraticBezierTo(
        size.width - 2,
        size.height - 2,
        size.width - 2,
        size.height - 7,
      );
      path.lineTo(size.width - 2, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
    covariant _CornerPainter oldDelegate,
  ) {
    return oldDelegate.color != color ||
        oldDelegate.top != top ||
        oldDelegate.left != left;
  }
}