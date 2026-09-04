import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
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
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _scanController;
  late AnimationController _chipController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _scanLineAnimation;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // ============================================================
    // ENTRANCE ANIMATION
    // ============================================================

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // ============================================================
    // SCAN LINE ANIMATION (continuous)
    // ============================================================

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);

    _scanLineAnimation = CurvedAnimation(
      parent: _scanController,
      curve: Curves.easeInOut,
    );

    // ============================================================
    // FORMAT CHIP STAGGER ANIMATION
    // ============================================================

    _chipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _animationController.forward();
    _chipController.forward();

    _navigate();
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _navigate() {
    _navigationTimer = Timer(
      const Duration(milliseconds: 5400),
      () {
        if (!mounted) return;

        if (widget.isExternalPdf) {
          return;
        }

        Navigator.of(context).pushReplacementNamed('/home');
      },
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animationController.dispose();
    _scanController.dispose();
    _chipController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isTablet = ResponsiveHelper.isTablet(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // ============================================================
    // RESPONSIVE SIZES
    // ============================================================

    final frameSize = isTablet
        ? 190.0
        : isMobile
            ? 158.0
            : 210.0;

    final appNameSize = ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 32,
      tabletSize: 40,
      desktopSize: 46,
    );

    final taglineSize = ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 14,
      tabletSize: 17,
      desktopSize: 19,
    );

    // ============================================================
    // COLORS
    // ============================================================

    final backgroundColor =
        isDark ? const Color(0xFF04030A) : const Color(0xFFF8F9FF);

    const magenta = Color(0xFFEC4899);
    const purple = Color(0xFF8B5CF6);
    const violet = Color(0xFFA855F7);
    const primaryBlue = Color(0xFF3B82F6);

    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    final secondaryTextColor =
        isDark ? const Color(0xFFA7B0C5) : const Color(0xFF64748B);

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
                          Color(0xFF03020A),
                          Color(0xFF090616),
                          Color(0xFF0B0714),
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
          // GLOWS
          // ======================================================

          Positioned(
            top: -110,
            left: -100,
            child: _buildGlow(
              size: screenWidth * 0.65,
              color: magenta,
              opacity: isDark ? 0.20 : 0.09,
            ),
          ),

          Positioned(
            bottom: -140,
            right: -100,
            child: _buildGlow(
              size: screenWidth * 0.70,
              color: primaryBlue,
              opacity: isDark ? 0.20 : 0.08,
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
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ==========================================
                      // FLOATING FORMAT CHIPS (PDF / DOCX / PPT)
                      // ==========================================

                      _buildFormatChipRow(isMobile: isMobile),

                      const SizedBox(height: 22),

                      // ==========================================
                      // SCAN VIEWFINDER (replaces static logo)
                      // ==========================================

                      AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (context, child) {
                          return Container(
                            width: frameSize,
                            height: frameSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: purple.withValues(
                                    alpha: _glowAnimation.value * 0.6,
                                  ),
                                  blurRadius: 50,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: _buildScanFrame(
                              frameSize,
                              isDark,
                              magenta,
                              violet,
                              primaryBlue,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      // ==========================================
                      // APP NAME  ("Doc" white + gradient rest)
                      // ==========================================

                      _buildAppName(
                        appNameSize,
                        textColor,
                        [magenta, violet, primaryBlue],
                      ),

                      const SizedBox(height: 8),

                      // ==========================================
                      // TAGLINE
                      // ==========================================

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          AppConstants.appTagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: taglineSize,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ==========================================
                      // PIPELINE:  Scan > Convert > Generate > Export
                      // ==========================================

                      _buildPipelineRow(isDark),

                      const SizedBox(height: 40),

                      // ==========================================
                      // LOADING INDICATOR
                      // ==========================================

                      SizedBox(
                        width: isMobile ? 130 : 160,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        'Preparing your workspace...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor,
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

          if (MediaQuery.of(context).size.height > 520)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Text(
                'Scan. Convert. Generate. Export.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: textColor.withValues(alpha: 0.35),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // APP NAME  ("Doc" static + gradient remainder, like the icon)
  // ============================================================

  Widget _buildAppName(
    double fontSize,
    Color baseColor,
    List<Color> gradientColors,
  ) {
    final name = AppConstants.appName; // "DocScanner"
    final splitIndex = name.length >= 3 ? 3 : 0;
    final prefix = name.substring(0, splitIndex); // "Doc"
    final suffix = name.substring(splitIndex); // "Scanner"

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        children: [
          TextSpan(
            text: prefix,
            style: TextStyle(color: baseColor),
          ),
          TextSpan(
            text: suffix,
            style: TextStyle(
              foreground: Paint()
                ..shader = LinearGradient(colors: gradientColors).createShader(
                  Rect.fromLTWH(0, 0, fontSize * suffix.length * 0.62, fontSize),
                ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FLOATING FORMAT CHIPS  (PDF / DOCX / PPT)
  // ============================================================

  Widget _buildFormatChipRow({required bool isMobile}) {
    final chips = [
      _FormatChipData('PDF', Icons.picture_as_pdf_rounded,
          const [Color(0xFFEF4444), Color(0xFFEC4899)]),
      _FormatChipData('W', Icons.description_rounded,
          const [Color(0xFF3B82F6), Color(0xFF60A5FA)]),
      _FormatChipData('P', Icons.slideshow_rounded,
          const [Color(0xFFF97316), Color(0xFFFACC15)]),
    ];

    return SizedBox(
      height: isMobile ? 54 : 62,
      child: AnimatedBuilder(
        animation: _chipController,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(chips.length, (index) {
              // Staggered entrance per chip.
              final start = index * 0.18;
              final end = (start + 0.6).clamp(0.0, 1.0);

              final progress = Curves.easeOutBack.transform(
                ((_chipController.value - start) / (end - start))
                    .clamp(0.0, 1.0),
              );

              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : (isMobile ? 14 : 18),
                ),
                child: Opacity(
                  opacity: progress.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, (1 - progress) * -14),
                    child: _buildFormatChip(chips[index], isMobile),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildFormatChip(_FormatChipData data, bool isMobile) {
    final size = isMobile ? 44.0 : 50.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: data.colors,
        ),
        boxShadow: [
          BoxShadow(
            color: data.colors.last.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        data.icon,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }

  // ============================================================
  // SCAN VIEWFINDER  (corner brackets + moving scan line)
  // ============================================================

  Widget _buildScanFrame(
    double size,
    bool isDark,
    Color magenta,
    Color violet,
    Color blue,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Faint document silhouette behind the scan line.
            Icon(
              Icons.description_outlined,
              size: size * 0.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.08),
            ),

            // Corner brackets.
            CustomPaint(
              size: Size(size, size),
              painter: _ScanCornerPainter(
                topLeft: magenta,
                topRight: blue,
                bottomLeft: violet,
                bottomRight: blue,
              ),
            ),

            // Animated horizontal scan line.
            AnimatedBuilder(
              animation: _scanLineAnimation,
              builder: (context, child) {
                final margin = size * 0.14;
                final travel = size - margin * 2;

                return Positioned(
                  top: margin + (_scanLineAnimation.value * travel),
                  left: margin,
                  right: margin,
                  child: Container(
                    height: 2.4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [
                          magenta.withValues(alpha: 0.0),
                          violet.withValues(alpha: 0.95),
                          blue.withValues(alpha: 0.0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: violet.withValues(alpha: 0.65),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PIPELINE ROW:  Scan > Convert > Generate > Export
  // ============================================================

  Widget _buildPipelineRow(bool isDark) {
    final steps = [
      _PipelineStepData(
        Icons.document_scanner_rounded,
        'Scan',
        const Color(0xFFEC4899),
      ),
      _PipelineStepData(
        Icons.sync_alt_rounded,
        'Convert',
        const Color(0xFFA855F7),
      ),
      _PipelineStepData(
        Icons.auto_awesome_rounded,
        'Generate',
        const Color(0xFF8B5CF6),
      ),
      _PipelineStepData(
        Icons.cloud_upload_rounded,
        'Export',
        const Color(0xFF3B82F6),
      ),
    ];

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              // Small colored dot connector between steps.
              final leftColor = steps[i ~/ 2].color;
              final rightColor = steps[i ~/ 2 + 1].color;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [leftColor, rightColor],
                    ),
                  ),
                ),
              );
            }

            final step = steps[i ~/ 2];

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: step.color.withValues(alpha: isDark ? 0.14 : 0.09),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(step.icon, size: 18, color: step.color),
                ),
                const SizedBox(height: 6),
                Text(
                  step.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.65)
                        : Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            );
          }),
        ),
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
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SCAN CORNER PAINTER  (camera-viewfinder style brackets)
// ================================================================

class _ScanCornerPainter extends CustomPainter {
  final Color topLeft;
  final Color topRight;
  final Color bottomLeft;
  final Color bottomRight;

  _ScanCornerPainter({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final armLength = size.width * 0.20;
    const strokeWidth = 4.0;
    const inset = 14.0;

    Paint paintFor(Color color) => Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(
      Offset(inset, inset + armLength),
      Offset(inset, inset),
      paintFor(topLeft),
    );
    canvas.drawLine(
      Offset(inset, inset),
      Offset(inset + armLength, inset),
      paintFor(topLeft),
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - inset - armLength, inset),
      Offset(size.width - inset, inset),
      paintFor(topRight),
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + armLength),
      paintFor(topRight),
    );

    // Bottom-left
    canvas.drawLine(
      Offset(inset, size.height - inset - armLength),
      Offset(inset, size.height - inset),
      paintFor(bottomLeft),
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset + armLength, size.height - inset),
      paintFor(bottomLeft),
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - inset - armLength, size.height - inset),
      Offset(size.width - inset, size.height - inset),
      paintFor(bottomRight),
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset - armLength),
      Offset(size.width - inset, size.height - inset),
      paintFor(bottomRight),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanCornerPainter oldDelegate) {
    return oldDelegate.topLeft != topLeft ||
        oldDelegate.topRight != topRight ||
        oldDelegate.bottomLeft != bottomLeft ||
        oldDelegate.bottomRight != bottomRight;
  }
}

// ================================================================
// DATA HOLDERS
// ================================================================

class _FormatChipData {
  final String label;
  final IconData icon;
  final List<Color> colors;

  const _FormatChipData(this.label, this.icon, this.colors);
}

class _PipelineStepData {
  final IconData icon;
  final String label;
  final Color color;

  const _PipelineStepData(this.icon, this.label, this.color);
}
