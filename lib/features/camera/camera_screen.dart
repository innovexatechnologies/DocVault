import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/camera_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/providers/image_selection_provider.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

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

  void _goToReview() {
    Navigator.of(context).pushReplacementNamed('/review');
  }

  void _goToGallery() {
    Navigator.of(context).pop();

    Navigator.of(context).pushNamed('/gallery');
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
                  padding: EdgeInsets.all(
                    ResponsiveHelper.getGridSpacing(context),
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

                  child: Column(
                    children: [
                      // ==================================================
                      // CAPTURE BUTTON
                      // ==================================================

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _capturePhoto,

                            child: Container(
                              width:
                                  ResponsiveHelper.isTablet(
                                    context,
                                  )
                                      ? 80.0
                                      : 70.0,

                              height:
                                  ResponsiveHelper.isTablet(
                                    context,
                                  )
                                      ? 80.0
                                      : 70.0,

                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,

                                border: Border.all(
                                  color: Colors.white
                                      .withValues(
                                    alpha: 0.90,
                                  ),
                                  width: 4,
                                ),

                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor
                                        .withValues(
                                      alpha: 0.50,
                                    ),
                                    blurRadius: 18,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),

                              child: Center(
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size:
                                      ResponsiveHelper.isTablet(
                                    context,
                                  )
                                          ? 36
                                          : 32,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(
                        height:
                            ResponsiveHelper.getGridSpacing(
                              context,
                            ),
                      ),

                      // ==================================================
                      // BOTTOM BUTTONS
                      // ==================================================

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          // ==============================================
                          // GALLERY BUTTON
                          // ==============================================

                          Expanded(
                            child: SizedBox(
                              height:
                                  ResponsiveHelper
                                      .getResponsiveButtonHeight(
                                context,
                              ) *
                                  0.75,

                              child: OutlinedButton.icon(
                                onPressed: _goToGallery,

                                icon: const Icon(
                                  Icons.photo_library_outlined,
                                  color: Colors.white,
                                ),

                                label: Text(
                                  'Gallery',
                                  style: TextStyle(
                                    color: Colors.white,
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

                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.white
                                        .withValues(
                                      alpha: 0.70,
                                    ),
                                  ),

                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(
                            width:
                                ResponsiveHelper
                                        .getGridSpacing(context) *
                                    0.5,
                          ),

                          // ==============================================
                          // DONE BUTTON
                          // ==============================================

                          Expanded(
                            child: SizedBox(
                              height:
                                  ResponsiveHelper
                                      .getResponsiveButtonHeight(
                                context,
                              ) *
                                  0.75,

                              child: ElevatedButton.icon(
                                onPressed: _captureCount > 0
                                    ? _goToReview
                                    : null,

                                icon: const Icon(
                                  Icons.check_rounded,
                                ),

                                label: Text(
                                  AppConstants.done,
                                  style: TextStyle(
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

                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _captureCount > 0
                                          ? AppTheme.successColor
                                          : Colors.grey.shade700,

                                  foregroundColor:
                                      Colors.white,

                                  disabledBackgroundColor:
                                      Colors.grey.shade800,

                                  disabledForegroundColor:
                                      Colors.white54,

                                  elevation: 0,

                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
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