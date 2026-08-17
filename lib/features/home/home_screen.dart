import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/permission_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ==========================================================
  // PERMISSION SERVICE
  // ==========================================================

  static final PermissionService _permissionService =
      PermissionService();

  // ==========================================================
  // CAMERA QUICK ACTION
  // ==========================================================

  Future<void> _handleCamera(BuildContext context) async {
    final shouldContinue = await _showPermissionDialog(
      context,
      title: 'Camera Access',
      icon: Icons.camera_alt_rounded,
      description:
          'DocVault needs access to your camera to scan documents and convert them into PDF.',
    );

    if (!shouldContinue || !context.mounted) return;

    final status =
        await _permissionService.requestCameraPermission();

    if (!context.mounted) return;

    if (status.isGranted) {
      Navigator.of(context).pushNamed('/camera');
    } else if (status.isPermanentlyDenied ||
        status.isRestricted) {
      await _showSettingsDialog(
        context,
        title: 'Camera Permission Required',
        message:
            'Camera permission is disabled. Please enable it from your device settings to scan documents.',
      );
    } else {
      _showDeniedMessage(
        context,
        'Camera permission was denied.',
      );
    }
  }

  // ==========================================================
  // GALLERY QUICK ACTION
  // ==========================================================

  Future<void> _handleGallery(BuildContext context) async {
    final shouldContinue = await _showPermissionDialog(
      context,
      title: 'Gallery Access',
      icon: Icons.photo_library_rounded,
      description:
          'DocVault needs access to your photos so you can select images and convert them into PDF.',
    );

    if (!shouldContinue || !context.mounted) return;

    final status =
        await _permissionService.requestGalleryPermission();

    if (!context.mounted) return;

    if (status.isGranted || status.isLimited) {
      Navigator.of(context).pushNamed('/gallery');
    } else if (status.isPermanentlyDenied ||
        status.isRestricted) {
      await _showSettingsDialog(
        context,
        title: 'Gallery Permission Required',
        message:
            'Photo permission is disabled. Please enable it from your device settings to select images.',
      );
    } else {
      _showDeniedMessage(
        context,
        'Gallery permission was denied.',
      );
    }
  }

  // ==========================================================
  // PERMISSION DIALOG
  // ==========================================================

  Future<bool> _showPermissionDialog(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String description,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;
        final isDark =
            theme.brightness == Brightness.dark;

        final screenWidth =
            MediaQuery.sizeOf(dialogContext).width;

        final dialogWidth = screenWidth < 600
            ? screenWidth * 0.86
            : 420.0;

        return Dialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogWidth,
              minWidth: 280,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                24,
                26,
                24,
                22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ==================================================
                  // ICON
                  // ==================================================

                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(
                        alpha: isDark ? 0.16 : 0.10,
                      ),
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                    child: Icon(
                      icon,
                      color: AppTheme.primaryColor,
                      size: 30,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ==================================================
                  // TITLE
                  // ==================================================

                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 9),

                  // ==================================================
                  // DESCRIPTION
                  // ==================================================

                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color:
                          colorScheme.onSurface.withValues(
                        alpha: 0.60,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ==================================================
                  // BUTTONS
                  // ==================================================

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(
                              dialogContext,
                            ).pop(false);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                colorScheme.onSurface,
                            side: BorderSide(
                              color: colorScheme.outline,
                            ),
                            minimumSize:
                                const Size.fromHeight(48),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Not Now',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(
                              dialogContext,
                            ).pop(true);
                          },
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                AppTheme.primaryColor,
                            foregroundColor:
                                Colors.white,
                            elevation: 0,
                            minimumSize:
                                const Size.fromHeight(48),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Allow',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
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
        );
      },
    );

    return result ?? false;
  }

  // ==========================================================
  // SETTINGS DIALOG
  // ==========================================================

  Future<void> _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              height: 1.5,
              color:
                  colorScheme.onSurface.withValues(
                alpha: 0.65,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                await _permissionService.openSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // DENIED MESSAGE
  // ==========================================================

  void _showDeniedMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark =
        theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,

      body: SafeArea(
        child: SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: padding,
              vertical: isMobile ? 20 : 32,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ==========================================================
                // HEADER
                // ==========================================================

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: isMobile ? 44 : 50,
                          height: isMobile ? 44 : 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.accentColor,
                              ],
                              begin:
                                  Alignment.topLeft,
                              end:
                                  Alignment.bottomRight,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme
                                    .primaryColor
                                    .withValues(
                                  alpha:
                                      isDark
                                          ? 0.20
                                          : 0.15,
                                ),
                                blurRadius: 18,
                                offset:
                                    const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons
                                .description_rounded,
                            color: isDark
                                ? AppTheme.bgDark
                                : Colors.white,
                            size:
                                isMobile
                                    ? 24
                                    : 28,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Text(
                          AppConstants.appName,
                          style: TextStyle(
                            fontSize:
                                isMobile
                                    ? 20
                                    : 24,
                            fontWeight:
                                FontWeight.w800,
                            letterSpacing: -0.5,
                            color:
                                colorScheme
                                    .onSurface,
                          ),
                        ),
                      ],
                    ),

                    // ======================================================
                    // THEME TOGGLE
                    // ======================================================

                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.surfaceDark
                            : AppTheme.surfaceLight,
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.dividerDark
                              : AppTheme.dividerColor,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          context
                              .read<ThemeProvider>()
                              .toggleTheme();
                        },
                        icon: Icon(
                          isDark
                              ? Icons
                                  .light_mode_rounded
                              : Icons
                                  .dark_mode_rounded,
                          color:
                              colorScheme.onSurface,
                          size: 21,
                        ),
                        tooltip: isDark
                            ? 'Switch to Light Mode'
                            : 'Switch to Dark Mode',
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  height: isMobile ? 34 : 50,
                ),

                // ==========================================================
                // WELCOME
                // ==========================================================

                Text(
                  'Your documents.',
                  style: TextStyle(
                    fontSize:
                        isMobile ? 30 : 38,
                    fontWeight:
                        FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -1.2,
                    color:
                        colorScheme.onSurface,
                  ),
                ),

                Text(
                  'Simplified.',
                  style: TextStyle(
                    fontSize:
                        isMobile ? 30 : 38,
                    fontWeight:
                        FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -1.2,
                    color:
                        AppTheme.primaryColor,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  AppConstants.appTagline,
                  style: TextStyle(
                    fontSize:
                        isMobile ? 14 : 16,
                    height: 1.5,
                    color: colorScheme.onSurface
                        .withValues(alpha: 0.60),
                  ),
                ),

                SizedBox(
                  height: isMobile ? 30 : 42,
                ),

                // ==========================================================
                // CREATE PDF HERO CARD
                // ==========================================================

                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(
                    isMobile ? 20 : 28,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        isDark
                            ? const Color(
                                0xFF00A77E,
                              )
                            : const Color(
                                0xFF087F73,
                              ),
                      ],
                      begin:
                          Alignment.topLeft,
                      end:
                          Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      isMobile ? 22 : 28,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme
                            .primaryColor
                            .withValues(
                          alpha:
                              isDark ? 0.22 : 0.18,
                        ),
                        blurRadius: 28,
                        offset:
                            const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(
                            alpha: 0.16,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),
                        child: const Icon(
                          Icons
                              .picture_as_pdf_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'Images to PDF',
                        style: TextStyle(
                          fontSize:
                              isMobile
                                  ? 22
                                  : 26,
                          fontWeight:
                              FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Text(
                        'Scan documents with your camera or choose images from your gallery.',
                        style: TextStyle(
                          fontSize:
                              isMobile
                                  ? 13
                                  : 15,
                          height: 1.45,
                          color: Colors.white
                              .withValues(
                            alpha: 0.82,
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        height:
                            isMobile ? 52 : 56,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushNamed(
                              '/source-selection',
                            );
                          },
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                Colors.white,
                            foregroundColor:
                                AppTheme
                                    .primaryDark,
                            elevation: 0,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                15,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              const Icon(
                                Icons.add_rounded,
                                size: 22,
                              ),
                              const SizedBox(
                                  width: 8),
                              Text(
                                AppConstants
                                    .createPdf,
                                style: TextStyle(
                                  fontSize:
                                      isMobile
                                          ? 14
                                          : 16,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: isMobile ? 26 : 34,
                ),

                // ==========================================================
                // QUICK ACTIONS
                // ==========================================================

                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize:
                        isMobile ? 17 : 20,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    // ======================================================
                    // CAMERA
                    // ======================================================

                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons
                            .camera_alt_rounded,
                        title: 'Scan',
                        subtitle: 'Use Camera',
                        onTap: () {
                          _handleCamera(
                            context,
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 12),

                    // ======================================================
                    // GALLERY
                    // ======================================================

                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons
                            .photo_library_rounded,
                        title: 'Gallery',
                        subtitle:
                            'Choose Images',
                        onTap: () {
                          _handleGallery(
                            context,
                          );
                        },
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  height: isMobile ? 30 : 42,
                ),

                // ==========================================================
                // INFO CARD
                // ==========================================================

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(18),
                  decoration: BoxDecoration(
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
                                : 0.10,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),
                        child: const Icon(
                          Icons
                              .verified_user_outlined,
                          color: AppTheme
                              .primaryColor,
                          size: 22,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'Private & Simple',
                              style: TextStyle(
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
                                height: 4),
                            Text(
                              'Your documents can be converted locally without needing an account.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
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
      ),
    );
  }
}

// ==========================================================================
// QUICK ACTION CARD
// ==========================================================================

class _QuickActionCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark =
        theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(18),
        child: Container(
          padding:
              const EdgeInsets.all(16),
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
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(
                  color: AppTheme
                      .primaryColor
                      .withValues(
                    alpha:
                        isDark ? 0.14 : 0.09,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      AppTheme.primaryColor,
                  size: 22,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme
                      .onSurface
                      .withValues(
                    alpha: 0.55,
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