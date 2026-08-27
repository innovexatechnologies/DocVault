import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.isExternalPdf = false,
  });

  final bool isExternalPdf;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // ============================================================
    // ANIMATION CONTROLLER
    // ============================================================

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1600,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.75,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _glowAnimation = Tween<double>(
      begin: 0.35,
      end: 0.75,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();

    _navigate();
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _navigate() {
    Future.delayed(
      const Duration(
        milliseconds: 2200,
      ),
      () {
        if (!mounted) return;

        // ========================================================
        // EXTERNAL PDF
        // ========================================================

        if (widget.isExternalPdf) {
          return;
        }

        // ========================================================
        // NORMAL APP START
        // ========================================================

        Navigator.of(context).pushReplacementNamed(
          '/home',
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    final isTablet =
        ResponsiveHelper.isTablet(context);

    final isMobile =
        ResponsiveHelper.isMobile(context);

    final screenWidth =
        MediaQuery.of(context).size.width;

    // ============================================================
    // RESPONSIVE SIZES
    // ============================================================

    final logoSize = isTablet
        ? 138.0
        : isMobile
            ? 112.0
            : 150.0;

    final iconSize = isTablet
        ? 72.0
        : isMobile
            ? 60.0
            : 78.0;

    final appNameSize =
        ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 30,
      tabletSize: 38,
      desktopSize: 44,
    );

    final taglineSize =
        ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 14,
      tabletSize: 17,
      desktopSize: 19,
    );

    // ============================================================
    // COLORS
    // ============================================================

    final backgroundColor = isDark
        ? const Color(0xFF050817)
        : const Color(0xFFF8F9FF);

    final primaryBlue =
        const Color(0xFF3B82F6);

    final purple =
        const Color(0xFF7C3AED);

    final pink =
        const Color(0xFFEC4899);

    final textColor = isDark
        ? Colors.white
        : const Color(0xFF111827);

    final secondaryTextColor = isDark
        ? const Color(0xFFA7B0C5)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: backgroundColor,

      body: Stack(
        children: [
          // ======================================================
          // BACKGROUND GRADIENT
          // ======================================================

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [
                          Color(0xFF03050F),
                          Color(0xFF070B20),
                          Color(0xFF0A0718),
                        ]
                      : const [
                          Color(0xFFFFFFFF),
                          Color(0xFFF5F7FF),
                          Color(0xFFFFF8FC),
                        ],
                ),
              ),
            ),
          ),

          // ======================================================
          // TOP BLUE GLOW
          // ======================================================

          Positioned(
            top: -120,
            left: -100,
            child: _buildGlow(
              size: screenWidth * 0.65,
              color: primaryBlue,
              opacity: isDark ? 0.16 : 0.08,
            ),
          ),

          // ======================================================
          // BOTTOM PURPLE/PINK GLOW
          // ======================================================

          Positioned(
            bottom: -140,
            right: -100,
            child: _buildGlow(
              size: screenWidth * 0.70,
              color: purple,
              opacity: isDark ? 0.18 : 0.07,
            ),
          ),

          // ======================================================
          // MAIN CONTENT
          // ======================================================

          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SingleChildScrollView(
                  physics:
                      const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      // ==========================================
                      // LOGO
                      // ==========================================

                      AnimatedBuilder(
                        animation:
                            _glowAnimation,
                        builder:
                            (context, child) {
                          return Container(
                            width: logoSize,
                            height: logoSize,

                            decoration:
                                BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(
                                isMobile ? 30 : 36,
                              ),

                              gradient:
                                  const LinearGradient(
                                begin:
                                    Alignment.topLeft,
                                end:
                                    Alignment.bottomRight,
                                colors: [
                                  Color(0xFF3B82F6),
                                  Color(0xFF6366F1),
                                  Color(0xFFA855F7),
                                ],
                              ),

                              boxShadow: [
                                BoxShadow(
                                  color: purple
                                      .withValues(
                                    alpha:
                                        _glowAnimation.value,
                                  ),
                                  blurRadius: 45,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),

                            child:
                                _buildLogoIcon(
                              iconSize,
                              isDark,
                            ),
                          );
                        },
                      ),

                      const SizedBox(
                        height: 30,
                      ),

                      // ==========================================
                      // APP NAME
                      // ==========================================

                      ShaderMask(
                        shaderCallback:
                            (bounds) {
                          return const LinearGradient(
                            colors: [
                              Color(0xFF3B82F6),
                              Color(0xFF8B5CF6),
                              Color(0xFFEC4899),
                            ],
                          ).createShader(
                            bounds,
                          );
                        },
                        child: Text(
                          AppConstants.appName,
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize:
                                appNameSize,
                            fontWeight:
                                FontWeight.w800,
                            letterSpacing:
                                -1.0,
                            color:
                                Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      // ==========================================
                      // TAGLINE
                      // ==========================================

                      Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 32,
                        ),
                        child: Text(
                          AppConstants.appTagline,
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize:
                                taglineSize,
                            height: 1.5,
                            fontWeight:
                                FontWeight.w500,
                            color:
                                secondaryTextColor,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 34,
                      ),

                      // ==========================================
                      // FEATURES
                      // ==========================================

                      Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          _buildFeature(
                            icon:
                                Icons.picture_as_pdf_rounded,
                            title: 'PDF',
                            color:
                                const Color(
                              0xFFEF4444,
                            ),
                            isDark:
                                isDark,
                          ),

                          _buildFeatureDivider(
                            isDark,
                          ),

                          _buildFeature(
                            icon:
                                Icons.description_rounded,
                            title: 'DOCX',
                            color:
                                primaryBlue,
                            isDark:
                                isDark,
                          ),

                          _buildFeatureDivider(
                            isDark,
                          ),

                          _buildFeature(
                            icon:
                                Icons.slideshow_rounded,
                            title: 'PPT',
                            color:
                                const Color(
                              0xFFF97316,
                            ),
                            isDark:
                                isDark,
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 42,
                      ),

                      // ==========================================
                      // LOADING INDICATOR
                      // ==========================================

                      SizedBox(
                        width:
                            isMobile ? 130 : 160,
                        child:
                            ClipRRect(
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                          child:
                              LinearProgressIndicator(
                            minHeight: 4,

                            backgroundColor:
                                isDark
                                    ? Colors.white
                                        .withValues(
                                      alpha:
                                          0.08,
                                    )
                                    : Colors.black
                                        .withValues(
                                      alpha:
                                          0.06,
                                    ),

                            valueColor:
                                const AlwaysStoppedAnimation<
                                    Color>(
                              Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      Text(
                        'Preparing your workspace...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w500,
                          color:
                              secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ======================================================
          // VERSION / COPYRIGHT
          // ======================================================

          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Text(
              'Your documents. Your way.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w500,
                color: textColor.withValues(
                  alpha: 0.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGO ICON
  // ============================================================

  Widget _buildLogoIcon(
    double size,
    bool isDark,
  ) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Document shape
          Container(
            width: size * 0.58,
            height: size * 0.72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.96,
              ),
              borderRadius:
                  BorderRadius.circular(
                size * 0.10,
              ),
            ),
          ),

          // Fold
          Positioned(
            top: size * 0.14,
            right: size * 0.21,
            child: CustomPaint(
              size: Size(
                size * 0.18,
                size * 0.18,
              ),
              painter:
                  _DocumentFoldPainter(),
            ),
          ),

          // PDF lines
          Positioned(
            top: size * 0.42,
            child: Column(
              children: [
                Container(
                  width: size * 0.28,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color: const Color(
                      0xFF6366F1,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      5,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Container(
                  width: size * 0.20,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color: const Color(
                      0xFFA855F7,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Small PDF badge
          Positioned(
            bottom: size * 0.08,
            right: size * 0.12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xFFEF4444),
                    Color(0xFFEC4899),
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(
                  5,
                ),
              ),
              child: Text(
                'PDF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.11,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FEATURE
  // ============================================================

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: isDark ? 0.12 : 0.08,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight:
                FontWeight.w700,
            color: isDark
                ? Colors.white
                    .withValues(
                  alpha: 0.65,
                )
                : Colors.black
                    .withValues(
                  alpha: 0.55,
                ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FEATURE DIVIDER
  // ============================================================

  Widget _buildFeatureDivider(
    bool isDark,
  ) {
    return Container(
      width: 1,
      height: 38,
      margin:
          const EdgeInsets.symmetric(
        horizontal: 18,
      ),
      color: isDark
          ? Colors.white.withValues(
              alpha: 0.08,
            )
          : Colors.black.withValues(
              alpha: 0.08,
            ),
    );
  }

  // ============================================================
  // GLOW
  // ============================================================

  Widget _buildGlow({
    required double size,
    required Color color,
    required double opacity,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            RadialGradient(
          colors: [
            color.withValues(
              alpha: opacity,
            ),
            color.withValues(
              alpha: 0.0,
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// DOCUMENT FOLD PAINTER
// ================================================================

class _DocumentFoldPainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFE5E7EB);

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}