import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/image_selection_provider.dart';
import '../../core/services/gallery_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';

class SourceSelectionScreen extends StatelessWidget {
  const SourceSelectionScreen({super.key});

  // ==========================================================
  // PERMISSION SERVICE
  // ==========================================================

  static final PermissionService _permissionService =
      PermissionService();

  // ==========================================================
  // CAMERA
  // ==========================================================

  Future<void> _handleCamera(BuildContext context) async {
    try {
      final status =
          await _permissionService.requestCameraPermission();

      if (!context.mounted) return;

      if (status.isGranted) {
        Navigator.of(context).pushNamed('/camera');
      } else {
        _showDeniedMessage(
          context,
          'Camera permission was denied.',
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      _showDeniedMessage(
        context,
        'Unable to access the camera.',
      );
    }
  }

  // ==========================================================
  // GALLERY
  // ==========================================================

  Future<void> _handleGallery(BuildContext context) async {
    try {
      final status =
          await _permissionService.requestGalleryPermission();

      if (!context.mounted) return;

      if (status.isGranted) {
        final galleryService = GalleryService();
        final imagePaths = await galleryService.pickImages();

        if (!context.mounted) return;

        if (imagePaths.isNotEmpty) {
          context.read<ImageSelectionProvider>().addImages(
                imagePaths,
                'gallery',
              );
          Navigator.of(context).pushNamed('/review');
        }
      } else {
        _showDeniedMessage(
          context,
          'Gallery permission was denied.',
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      _showDeniedMessage(
        context,
        'Unable to access the gallery.',
      );
    }
  }

  // ==========================================================
  // DENIED MESSAGE
  // ==========================================================

  void _showDeniedMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.errorColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final padding =
        ResponsiveHelper.getResponsivePadding(context);

    final isMobile =
        ResponsiveHelper.isMobile(context);

    final isTablet =
        ResponsiveHelper.isTablet(context);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDark =
        theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          AppConstants.createPdf,
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: IconButton(
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
          tooltip: 'Back',
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),

          child: Padding(
            padding: EdgeInsets.all(padding),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,

              children: [
                SizedBox(
                  height:
                      isMobile ? 20 : 40,
                ),

                // ==================================================
                // HEADER
                // ==================================================

                Text(
                  'Choose Source',
                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize:
                        ResponsiveHelper
                            .getResponsiveFontSize(
                      context,
                      mobileSize: 24,
                      tabletSize: 28,
                      desktopSize: 32,
                    ),
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: -0.5,
                    color:
                        colorScheme.onSurface,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  'Select where to get your documents',
                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize:
                        ResponsiveHelper
                            .getResponsiveFontSize(
                      context,
                      mobileSize: 13,
                      tabletSize: 15,
                      desktopSize: 16,
                    ),
                    color: colorScheme
                        .onSurface
                        .withValues(
                      alpha: 0.58,
                    ),
                  ),
                ),

                SizedBox(
                  height:
                      isMobile ? 32 : 50,
                ),

                // ==================================================
                // SOURCE OPTIONS
                // ==================================================

                if (isTablet)
                  Row(
                    children: [
                      // ==================================================
                      // CAMERA
                      // ==================================================

                      Expanded(
                        child:
                            _buildSourceOption(
                          context,
                          title:
                              AppConstants.camera,
                          subtitle:
                              'Capture new documents with camera',
                          icon: Icons
                              .camera_alt_rounded,
                          color:
                              AppTheme.primaryColor,
                          isDark: isDark,

                          onTap: () {
                            _handleCamera(
                              context,
                            );
                          },
                        ),
                      ),

                      SizedBox(
                        width: padding,
                      ),

                      // ==================================================
                      // GALLERY
                      // ==================================================

                      Expanded(
                        child:
                            _buildSourceOption(
                          context,
                          title:
                              AppConstants.gallery,
                          subtitle:
                              'Select existing images from gallery',
                          icon: Icons
                              .photo_library_rounded,
                          color:
                              AppTheme.primaryColor,
                          isDark: isDark,

                          onTap: () {
                            _handleGallery(
                              context,
                            );
                          },
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      // ==================================================
                      // CAMERA
                      // ==================================================

                      _buildSourceOption(
                        context,
                        title:
                            AppConstants.camera,
                        subtitle:
                            'Capture new documents with camera',
                        icon:
                            Icons.camera_alt_rounded,
                        color:
                            AppTheme.primaryColor,
                        isDark: isDark,

                        onTap: () {
                          _handleCamera(
                            context,
                          );
                        },
                      ),

                      SizedBox(
                        height:
                            isMobile ? 16 : 24,
                      ),

                      // ==================================================
                      // GALLERY
                      // ==================================================

                      _buildSourceOption(
                        context,
                        title:
                            AppConstants.gallery,
                        subtitle:
                            'Select existing images from gallery',
                        icon:
                            Icons.photo_library_rounded,
                        color:
                            AppTheme.primaryColor,
                        isDark: isDark,

                        onTap: () {
                          _handleGallery(
                            context,
                          );
                        },
                      ),
                    ],
                  ),

                SizedBox(
                  height:
                      isMobile ? 28 : 40,
                ),

                // ==================================================
                // INFO CARD
                // ==================================================

                Container(
                  padding: EdgeInsets.all(
                    isMobile ? 16 : 20,
                  ),

                  decoration:
                      BoxDecoration(
                    color: isDark
                        ? AppTheme.surfaceDark
                        : AppTheme.surfaceLight,

                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),

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

                        decoration:
                            BoxDecoration(
                          color: AppTheme
                              .primaryColor
                              .withValues(
                            alpha: isDark
                                ? 0.14
                                : 0.09,
                          ),

                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),

                        child: const Icon(
                          Icons
                              .info_outline_rounded,
                          color: AppTheme
                              .primaryColor,
                          size: 22,
                        ),
                      ),

                      const SizedBox(
                        width: 14,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            Text(
                              'Choose your source',
                              style:
                                  TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    FontWeight
                                        .w700,
                                color:
                                    colorScheme
                                        .onSurface,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Text(
                              'Scan a new document using your camera or select existing images from your gallery.',
                              style:
                                  TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color:
                                    colorScheme
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

                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SOURCE OPTION CARD
  // ============================================================

  Widget _buildSourceOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final isMobile =
        ResponsiveHelper.isMobile(context);

    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,

        borderRadius:
            BorderRadius.circular(22),

        child: Ink(
          width: double.infinity,

          padding: EdgeInsets.all(
            isMobile ? 20 : 28,
          ),

          decoration:
              BoxDecoration(
            color: isDark
                ? AppTheme.surfaceDark
                : AppTheme.surfaceLight,

            borderRadius:
                BorderRadius.circular(22),

            border: Border.all(
              color: isDark
                  ? AppTheme.dividerDark
                  : AppTheme.dividerColor,
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha:
                      isDark
                          ? 0.15
                          : 0.04,
                ),
                blurRadius: 18,
                offset:
                    const Offset(0, 8),
              ),
            ],
          ),

          child: Column(
            children: [
              // ==================================================
              // ICON
              // ==================================================

              Container(
                width:
                    isMobile ? 68 : 80,
                height:
                    isMobile ? 68 : 80,

                decoration:
                    BoxDecoration(
                  color: color
                      .withValues(
                    alpha:
                        isDark
                            ? 0.15
                            : 0.09,
                  ),

                  borderRadius:
                      BorderRadius
                          .circular(20),
                ),

                child: Icon(
                  icon,
                  size:
                      isMobile
                          ? 34
                          : 40,
                  color: color,
                ),
              ),

              SizedBox(
                height:
                    isMobile ? 16 : 20,
              ),

              // ==================================================
              // TITLE
              // ==================================================

              Text(
                title,
                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  fontSize:
                      ResponsiveHelper
                          .getResponsiveFontSize(
                    context,
                    mobileSize: 18,
                    tabletSize: 20,
                    desktopSize: 22,
                  ),
                  fontWeight:
                      FontWeight.w800,
                  color:
                      colorScheme
                          .onSurface,
                ),
              ),

              const SizedBox(
                height: 7,
              ),

              // ==================================================
              // SUBTITLE
              // ==================================================

              Text(
                subtitle,
                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  fontSize:
                      ResponsiveHelper
                          .getResponsiveFontSize(
                    context,
                    mobileSize: 12,
                    tabletSize: 13,
                    desktopSize: 14,
                  ),
                  height: 1.45,
                  color: colorScheme
                      .onSurface
                      .withValues(
                    alpha: 0.55,
                  ),
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              // ==================================================
              // BUTTON
              // ==================================================

              SizedBox(
                width:
                    double.infinity,

                height:
                    isMobile
                        ? 46
                        : 50,

                child:
                    ElevatedButton(
                  onPressed: onTap,

                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        color,
                    foregroundColor:
                        Colors.white,
                    elevation: 0,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                  ),

                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 19,
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Text(
                          title == AppConstants.camera
                              ? 'Scan Document'
                              : 'Choose Images',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }
}