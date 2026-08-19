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
    try {
      final image = await _cameraService.capturePhoto();

      if (mounted && image != null) {
        context.read<ImageSelectionProvider>().addImages(
          [
            image.path,
          ],
          'camera',
        );

        setState(() {
          _captureCount++;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo captured ($_captureCount)',
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to capture photo'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ==========================================================
  // NAVIGATION
  // ==========================================================

  ConversionType get _effectiveType {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is ConversionType) {
      return routeArgs;
    }
    return widget.conversionType;
  }

  void _goToReview() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(conversionType: _effectiveType),
      ),
    );
  }

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
            builder: (_) => ReviewScreen(conversionType: _effectiveType),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open gallery'),
            backgroundColor: AppTheme.errorColor,
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
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // ========================================================
    // CAMERA INITIALIZING
    // ========================================================

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(
            color: colorScheme.primary,
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
                // ==================================================
                // ERROR ICON
                // ==================================================

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

                // ==================================================
                // ERROR MESSAGE
                // ==================================================

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

                // ==================================================
                // GALLERY BUTTON
                // ==================================================

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
                        borderRadius: BorderRadius.circular(12),
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

    // ==========================================================
    // CAMERA SCREEN
    // ==========================================================

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        // Camera preview naturally remains dark/black.
        backgroundColor: Colors.black,

        body: Stack(
          children: [
            // ====================================================
            // CAMERA PREVIEW
            // ====================================================

            CameraPreview(
              _cameraService.controller,
            ),

            // ====================================================
            // TOP BAR
            // ====================================================

            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(
                  ResponsiveHelper.getGridSpacing(context),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    // =================================================
                    // BACK BUTTON
                    // =================================================

                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).maybePop();
                      },

                      child: Container(
                        padding: EdgeInsets.all(
                          ResponsiveHelper.isMobile(context)
                              ? 8.0
                              : 10.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius:
                              BorderRadius.circular(12),

                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size:
                              ResponsiveHelper.isMobile(context)
                                  ? 24.0
                                  : 28.0,
                        ),
                      ),
                    ),

                    // =================================================
                    // PHOTO COUNT
                    // =================================================

                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            ResponsiveHelper.isMobile(context)
                                ? 12.0
                                : 16.0,
                        vertical:
                            ResponsiveHelper.isMobile(context)
                                ? 6.0
                                : 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius:
                            BorderRadius.circular(20),

                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor
                                .withValues(
                              alpha: 0.30,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'Photos: $_captureCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize:
                              ResponsiveHelper
                                  .getResponsiveFontSize(
                            context,
                            mobileSize: 13,
                            tabletSize: 14,
                            desktopSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==========================================================
            // BOTTOM CONTROLS
            // ==========================================================

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: 0.78,
                    ),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(
                          alpha: 0.08,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ==================================================
                      // GALLERY SHORTCUT
                      // ==================================================
                      Flexible(
                        child: Center(
                          child: InkWell(
                            onTap: _goToGallery,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.20),
                                ),
                              ),
                              child: const Icon(
                                Icons.photo_library_outlined,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ==================================================
                      // SHUTTER CAPTURE BUTTON
                      // ==================================================
                      GestureDetector(
                        onTap: _capturePhoto,
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.90),
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.50),
                                blurRadius: 18,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),

                      // ==================================================
                      // DONE / REVIEW BUTTON
                      // ==================================================
                      Flexible(
                        child: Center(
                          child: InkWell(
                            onTap: _captureCount > 0 ? _goToReview : null,
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _captureCount > 0
                                    ? AppTheme.successColor
                                    : Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _captureCount > 0
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.successColor.withValues(alpha: 0.4),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    color: _captureCount > 0
                                        ? Colors.white
                                        : Colors.white38,
                                    size: 22,
                                  ),
                                  if (_captureCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_captureCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
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