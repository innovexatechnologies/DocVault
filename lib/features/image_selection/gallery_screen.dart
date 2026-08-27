import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/gallery_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/providers/image_selection_provider.dart';

import '../../models/conversion_type.dart';
import '../pdf_generation/review_screen.dart';

class GalleryScreen extends StatefulWidget {
  final ConversionType conversionType;

  const GalleryScreen({
    super.key,
    this.conversionType = ConversionType.pdf,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final GalleryService _galleryService = GalleryService();

  bool _isLoading = false;
  String? _errorMessage;

  ConversionType get _effectiveType {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;

    if (routeArgs is ConversionType) {
      return routeArgs;
    }

    return widget.conversionType;
  }

  // ==========================================================
  // PICK IMAGES
  // ==========================================================

  Future<void> _pickImages() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final imagePaths = await _galleryService.pickImages();

      if (!mounted) return;

      if (imagePaths.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final padding =
        ResponsiveHelper.getResponsivePadding(context);

    final isMobile =
        ResponsiveHelper.isMobile(context);

    final titleSize =
        ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 26,
      tabletSize: 30,
      desktopSize: 32,
    );

    final descriptionSize =
        ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 13,
      tabletSize: 14,
      desktopSize: 15,
    );

    final buttonTextSize =
        ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 14,
      tabletSize: 16,
      desktopSize: 17,
    );

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.bgDark
          : AppTheme.bgLight,

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // TOP BAR
            // ==================================================

            Padding(
              padding: EdgeInsets.fromLTRB(
                padding,
                isMobile ? 10 : 18,
                padding,
                10,
              ),
              child: Row(
                children: [
                  // BACK BUTTON
                  _buildTopButton(
                    context,
                    icon: Icons.arrow_back_rounded,
                    onTap: () {
                      Navigator.of(context).maybePop();
                    },
                  ),

                  const SizedBox(width: 14),

                  // TITLE
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.gallery,
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 23,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select images for your document',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.52),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // IMAGE ICON
                  Container(
                    width: isMobile ? 44 : 50,
                    height: isMobile ? 44 : 50,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor
                          .withValues(
                        alpha: isDark ? 0.16 : 0.09,
                      ),
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primaryColor
                            .withValues(
                          alpha: isDark ? 0.25 : 0.14,
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            Expanded(
              child: SingleChildScrollView(
                physics:
                    const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  padding,
                  10,
                  padding,
                  24,
                ),
                child: Column(
                  children: [
                    // ==================================================
                    // MAIN HERO CARD
                    // ==================================================

                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(
                        isMobile ? 22 : 30,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.cardDark
                            : AppTheme.cardLight,
                        borderRadius:
                            BorderRadius.circular(26),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.dividerDark
                              : AppTheme.dividerColor,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.18 : 0.05,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ==================================================
                          // GALLERY ILLUSTRATION
                          // ==================================================

                          Container(
                            width: isMobile ? 115 : 140,
                            height: isMobile ? 115 : 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryColor
                                  .withValues(
                                alpha: isDark
                                    ? 0.13
                                    : 0.08,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: isMobile ? 82 : 98,
                                height: isMobile ? 82 : 98,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.surfaceDark
                                      : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppTheme.primaryColor
                                        .withValues(
                                      alpha: 0.20,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme
                                          .primaryColor
                                          .withValues(
                                        alpha: 0.15,
                                      ),
                                      blurRadius: 20,
                                      offset:
                                          const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons
                                      .add_photo_alternate_rounded,
                                  color:
                                      AppTheme.primaryColor,
                                  size: 42,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // ==================================================
                          // TITLE
                          // ==================================================

                          Text(
                            'Select Images',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                              color:
                                  colorScheme.onSurface,
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
                              fontSize:
                                  descriptionSize,
                              height: 1.5,
                              color: colorScheme
                                  .onSurface
                                  .withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ==================================================
                          // ERROR
                          // ==================================================

                          if (_errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor
                                    .withValues(
                                  alpha:
                                      isDark ? 0.13 : 0.07,
                                ),
                                borderRadius:
                                    BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.errorColor
                                      .withValues(
                                    alpha: 0.30,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons
                                        .error_outline_rounded,
                                    color:
                                        AppTheme.errorColor,
                                    size: 21,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: AppTheme
                                            .errorColor,
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // ==================================================
                          // PICK IMAGES BUTTON
                          // ==================================================

                          SizedBox(
                            width: double.infinity,
                            height: isMobile ? 54 : 58,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _pickImages,
                              style:
                                  ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppTheme.primaryColor,
                                foregroundColor:
                                    Colors.white,
                                disabledBackgroundColor:
                                    colorScheme.onSurface
                                        .withValues(
                                  alpha: 0.12,
                                ),
                                elevation: 0,
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    16,
                                  ),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 23,
                                      height: 23,
                                      child:
                                          CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .center,
                                      children: [
                                        const Icon(
                                          Icons
                                              .photo_library_rounded,
                                          size: 22,
                                        ),
                                        const SizedBox(
                                            width: 9),
                                        Text(
                                          'Pick Images',
                                          style: TextStyle(
                                            fontSize:
                                                buttonTextSize,
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
                            width: double.infinity,
                            height: isMobile ? 54 : 58,
                            child: OutlinedButton(
                              onPressed: _goToCamera,
                              style:
                                  OutlinedButton.styleFrom(
                                foregroundColor:
                                    AppTheme.primaryColor,
                                side: BorderSide(
                                  color:
                                      AppTheme.primaryColor,
                                  width: 1.4,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    16,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons
                                        .camera_alt_rounded,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 9),
                                  Text(
                                    'Use Camera Instead',
                                    style: TextStyle(
                                      fontSize:
                                          buttonTextSize,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // INFORMATION CARD
                    // ==================================================

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.cardDarkSecondary
                            : AppTheme.surfaceLight,
                        borderRadius:
                            BorderRadius.circular(20),
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
                          // ICON
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withValues(
                                alpha:
                                    isDark ? 0.14 : 0.08,
                              ),
                              borderRadius:
                                  BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons
                                  .collections_rounded,
                              color:
                                  AppTheme.primaryColor,
                              size: 22,
                            ),
                          ),

                          const SizedBox(width: 13),

                          // TEXT
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
                                    color: colorScheme
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
                                      alpha: 0.52,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // SUPPORTED FORMAT CARD
                    // ==================================================

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.surfaceDark
                            : const Color(0xFFF7F7FA),
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 19,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.50),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'You can select multiple photos at once.',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme
                                    .onSurface
                                    .withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // TOP BUTTON
  // ==========================================================

  Widget _buildTopButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.cardDark
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? AppTheme.dividerDark
                  : AppTheme.dividerColor,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}