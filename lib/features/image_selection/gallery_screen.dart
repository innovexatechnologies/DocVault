import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/gallery_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/providers/image_selection_provider.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final GalleryService _galleryService = GalleryService();

  bool _isLoading = false;
  String? _errorMessage;

  // ==========================================================
  // PICK IMAGES
  // ==========================================================

  Future<void> _pickImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final imagePaths = await _galleryService.pickImages();

      if (!mounted) return;

      // User cancelled gallery
      if (imagePaths.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Add selected images to provider
      context.read<ImageSelectionProvider>().addImages(
        imagePaths,
        'gallery',
      );

      // Go to review screen
      Navigator.of(context).pushReplacementNamed('/review');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to pick images';
      });
    }
  }

  // ==========================================================
  // GO TO CAMERA
  // ==========================================================

  void _goToCamera() {
    Navigator.of(context).pushReplacementNamed('/camera');
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final responsivePadding =
        ResponsiveHelper.getResponsivePadding(context);

    final buttonHeight =
        ResponsiveHelper.getResponsiveButtonHeight(context);

    final titleFontSize =
        ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 22,
      tabletSize: 26,
      desktopSize: 28,
    );

    final descriptionFontSize =
        ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 13,
      tabletSize: 14,
      desktopSize: 15,
    );

    final buttonLabelFontSize =
        ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 14,
      tabletSize: 16,
      desktopSize: 18,
    );

    final iconSize =
        ResponsiveHelper.isTablet(context) ? 70.0 : 60.0;

    // ========================================================
    // THEME
    // ========================================================

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,

      // ======================================================
      // APP BAR
      // ======================================================

      appBar: AppBar(
        automaticallyImplyLeading: true,

        title: const Text(
          AppConstants.gallery,
        ),

        backgroundColor: colorScheme.surface,

        foregroundColor: colorScheme.onSurface,

        elevation: 0,

        scrolledUnderElevation: 0,

        centerTitle: true,
      ),

      // ======================================================
      // BODY
      // ======================================================

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),

          padding: EdgeInsets.all(
            responsivePadding,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,

            children: [
              SizedBox(
                height: ResponsiveHelper.isMobile(context)
                    ? 20
                    : 40,
              ),

              // ==================================================
              // GALLERY ICON
              // ==================================================

              Center(
                child: Container(
                  width:
                      ResponsiveHelper.isTablet(context)
                          ? 120
                          : 100,

                  height:
                      ResponsiveHelper.isTablet(context)
                          ? 120
                          : 100,

                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(
                      alpha: isDark ? 0.14 : 0.09,
                    ),

                    borderRadius:
                        BorderRadius.circular(24),

                    border: Border.all(
                      color: AppTheme.primaryColor
                          .withValues(
                        alpha: isDark ? 0.22 : 0.12,
                      ),
                    ),
                  ),

                  child: Icon(
                    Icons.photo_library_rounded,

                    size: iconSize,

                    color: AppTheme.primaryColor,
                  ),
                ),
              ),

              SizedBox(
                height: responsivePadding,
              ),

              // ==================================================
              // TITLE
              // ==================================================

              Text(
                'Select Images',

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: titleFontSize,

                  fontWeight: FontWeight.w800,

                  letterSpacing: -0.5,

                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 8),

              // ==================================================
              // DESCRIPTION
              // ==================================================

              Text(
                'Choose one or multiple images from your gallery',

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: descriptionFontSize,

                  height: 1.5,

                  color: colorScheme.onSurface
                      .withValues(alpha: 0.60),
                ),
              ),

              // ==================================================
              // ERROR MESSAGE
              // ==================================================

              if (_errorMessage != null) ...[
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(
                      alpha: isDark ? 0.14 : 0.08,
                    ),

                    borderRadius:
                        BorderRadius.circular(14),

                    border: Border.all(
                      color: AppTheme.errorColor
                          .withValues(
                        alpha: isDark ? 0.45 : 0.30,
                      ),
                    ),
                  ),

                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,

                        color: AppTheme.errorColor,

                        size: 22,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          _errorMessage!,

                          textAlign: TextAlign.center,

                          style: const TextStyle(
                            color: AppTheme.errorColor,

                            fontSize: 13,

                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(
                height: responsivePadding * 1.5,
              ),

              // ==================================================
              // PICK IMAGES BUTTON
              // ==================================================

              SizedBox(
                height: buttonHeight,

                child: ElevatedButton(
                  onPressed:
                      _isLoading ? null : _pickImages,

                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        colorScheme.primary,

                    foregroundColor:
                        colorScheme.onPrimary,

                    disabledBackgroundColor:
                        colorScheme.onSurface
                            .withValues(
                      alpha: 0.12,
                    ),

                    disabledForegroundColor:
                        colorScheme.onSurface
                            .withValues(
                      alpha: 0.38,
                    ),

                    elevation: 0,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),

                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,

                          child:
                              CircularProgressIndicator(
                            color:
                                colorScheme.onPrimary,

                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,

                          children: [
                            const Icon(
                              Icons
                                  .add_photo_alternate_rounded,
                            ),

                            SizedBox(
                              width:
                                  responsivePadding *
                                      0.33,
                            ),

                            Text(
                              'Pick Images',

                              style: TextStyle(
                                fontSize:
                                    buttonLabelFontSize,

                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // CAMERA BUTTON
              // ==================================================

              SizedBox(
                height: buttonHeight,

                child: OutlinedButton(
                  onPressed: _goToCamera,

                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        colorScheme.primary,

                    side: BorderSide(
                      color: colorScheme.primary,

                      width: 1.4,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),

                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [
                      const Icon(
                        Icons.camera_alt_rounded,
                      ),

                      SizedBox(
                        width:
                            responsivePadding *
                                0.33,
                      ),

                      Text(
                        'Use Camera Instead',

                        style: TextStyle(
                          fontSize:
                              buttonLabelFontSize,

                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // INFO CARD
              // ==================================================

              Container(
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.surfaceDark
                      : AppTheme.surfaceLight,

                  borderRadius:
                      BorderRadius.circular(18),

                  border: Border.all(
                    color: isDark
                        ? AppTheme.dividerDark
                        : AppTheme.dividerColor,
                  ),
                ),

                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Container(
                      width: 42,
                      height: 42,

                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor
                            .withValues(
                          alpha: isDark
                              ? 0.14
                              : 0.09,
                        ),

                        borderRadius:
                            BorderRadius.circular(12),
                      ),

                      child: const Icon(
                        Icons
                            .collections_outlined,

                        color:
                            AppTheme.primaryColor,

                        size: 22,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Text(
                            'Multiple images supported',

                            style: TextStyle(
                              fontSize: 13,

                              fontWeight:
                                  FontWeight.w700,

                              color:
                                  colorScheme
                                      .onSurface,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            'Select multiple images and combine them into one PDF document.',

                            style: TextStyle(
                              fontSize: 11,

                              height: 1.5,

                              color: colorScheme
                                  .onSurface
                                  .withValues(
                                alpha: 0.58,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}