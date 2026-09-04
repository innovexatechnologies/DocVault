import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/code_scanner_service.dart';
import '../../core/widgets/code_scan_result_dialog.dart';
import '../../models/conversion_type.dart';
import 'source_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onNavigateToAllFiles;

  const HomeScreen({
    super.key,
    this.onNavigateToAllFiles,
  });

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void _navigateToSourceSelection(
    BuildContext context,
    ConversionType conversionType,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SourceSelectionScreen(
          conversionType: conversionType,
        ),
      ),
    );
  }

  // ===========================================================================
  // QR / BARCODE SCAN
  // ===========================================================================

  Future<void> _handleScanCode(BuildContext context) async {
    if (!CodeScannerService.isSupported) {
      _showScannerMessage(
        context,
        'QR/barcode scanning uses Google Play services and is '
        'currently available on Android only.',
      );
      return;
    }

    try {
      final result = await CodeScannerService.scan();

      if (result == null) {
        // User backed out of the scanner -- nothing to do.
        return;
      }

      if (context.mounted) {
        await CodeScanResultDialog.show(context, result);
      }
    } on CodeScannerException catch (e) {
      if (context.mounted) {
        _showScannerMessage(context, e.message);
      }
    }
  }

  void _showScannerMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? const Color(0xFF020617)
        : const Color(0xFFF9FAFC);

    final primaryText = isDark
        ? Colors.white
        : const Color(0xFF111827);

    final secondaryText = isDark
        ? const Color(0xFFA7B0C3)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.horizontalPadding(context),
                  vertical: isMobile ? 18 : 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =================================================================
                    // HEADER
                    // =================================================================

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: isMobile ? 46 : 52,
                                height: isMobile ? 46 : 52,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7C3AED),
                                      Color(0xFFEC4899),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C3AED)
                                          .withValues(alpha: 0.25),
                                      blurRadius: 18,
                                      offset: const Offset(0, 7),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.description_rounded,
                                  color: Colors.white,
                                  size: 27,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  AppConstants.appName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isMobile ? 20 : 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                    color: primaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // THEME BUTTON
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0B1020)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF29324A)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: IconButton(
                            onPressed: () {
                              context.read<ThemeProvider>().toggleTheme();
                            },
                            icon: Icon(
                              isDark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              color: primaryText,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(
                      height: isMobile ? 30 : 42,
                    ),

                    // =================================================================
                    // HERO TITLE
                    // =================================================================

                    Text(
                      'Choose',
                      style: TextStyle(
                        fontSize: isMobile ? 38 : 48,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        // letterSpacing: -1.8,
                        color: primaryText,
                      ),
                    ),

                    Text(
                      'Transform &',
                      style: TextStyle(
                        fontSize: isMobile ? 38 : 48,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        // letterSpacing: 0.2,
                        color: primaryText,
                      ),
                    ),

                    ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          colors: [
                            Color(0xFF3B82F6),
                            Color(0xFF8B5CF6),
                            Color(0xFFEC4899),
                          ],
                        ).createShader(bounds);
                      },
                      child: Text(
                        'Share.',
                        style: TextStyle(
                          fontSize: isMobile ? 38 : 48,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          // letterSpacing: -1.8,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'Convert images to PDF, DOCX & PPT\ninstantly with high quality.',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        height: 1.55,
                        color: secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    SizedBox(
                      height: isMobile ? 30 : 38,
                    ),

                    // =================================================================
                    // POPULAR CONVERSIONS TITLE
                    // =================================================================

                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 29,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF7C3AED),
                                Color(0xFFEC4899),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Popular Conversions',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isMobile ? 21 : 24,
                              fontWeight: FontWeight.w800,
                              color: primaryText,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // =================================================================
                    // PDF
                    // =================================================================

                    _buildConversionCard(
                      context,
                      isDark: isDark,
                      isMobile: isMobile,
                      title: 'Images to PDF',
                      description:
                          'Convert your images into high-quality PDF files.',
                  buttonText: 'Create PDF',
                  icon: Icons.picture_as_pdf_rounded,
                  iconLetter: 'PDF',
                  gradient: const [
                    Color(0xFFFF4D4D),
                    Color(0xFFEC2E9A),
                  ],
                  onTap: () {
                    _navigateToSourceSelection(
                      context,
                      ConversionType.pdf,
                    );
                  },
                ),

                const SizedBox(height: 12),

                // =================================================================
                // DOCX
                // =================================================================

                _buildConversionCard(
                  context,
                  isDark: isDark,
                  isMobile: isMobile,
                  title: 'Images to DOCX',
                  description:
                      'Convert images to editable Word documents.',
                  buttonText: 'Create DOCX',
                  icon: Icons.article_rounded,
                  iconLetter: 'W',
                  gradient: const [
                    Color(0xFF3489F5),
                    Color(0xFF3155F5),
                  ],
                  onTap: () {
                    _navigateToSourceSelection(
                      context,
                      ConversionType.docs,
                    );
                  },
                ),

                const SizedBox(height: 12),

                // =================================================================
                // PPT
                // =================================================================

                _buildConversionCard(
                  context,
                  isDark: isDark,
                  isMobile: isMobile,
                  title: 'Images to PPT',
                  description:
                      'Convert images to powerful PowerPoint presentations.',
                  buttonText: 'Create PPT',
                  icon: Icons.slideshow_rounded,
                  iconLetter: 'P',
                  gradient: const [
                    Color(0xFFFF8A22),
                    Color(0xFFFF4E22),
                  ],
                  onTap: () {
                    _navigateToSourceSelection(
                      context,
                      ConversionType.ppt,
                    );
                  },
                ),

                const SizedBox(height: 12),

                // =================================================================
                // QR / BARCODE SCAN
                // =================================================================

                _buildConversionCard(
                  context,
                  isDark: isDark,
                  isMobile: isMobile,
                  title: 'Scan QR / Barcode',
                  description:
                      'Scan a QR code or barcode using your camera.',
                  buttonText: 'Scan Code',
                  icon: Icons.qr_code_scanner_rounded,
                  iconLetter: 'QR',
                  gradient: const [
                    Color(0xFF00C6AE),
                    Color(0xFF00A896),
                  ],
                  onTap: () {
                    _handleScanCode(context);
                  },
                ),

                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }

  // ===========================================================================
  // COMPACT CONVERSION CARD
  // ===========================================================================
  Widget _buildConversionCard(
    BuildContext context, {
    required bool isDark,
    required bool isMobile,
    required String title,
    required String description,
    required String buttonText,
    required IconData icon,
    required String iconLetter,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    final primaryText = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryText =
        isDark ? const Color(0xFFAAB3C5) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // ✅ NOW WHOLE CARD IS CLICKABLE
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 13 : 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B1020) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: gradient.first.withValues(
                alpha: isDark ? 0.28 : 0.14,
              ),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(
                  alpha: isDark ? 0.08 : 0.06,
                ),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              // ===============================================================
              // ICON
              // ===============================================================
              Container(
                width: isMobile ? 64 : 72,
                height: isMobile ? 64 : 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: isMobile ? 32 : 36,
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          iconLetter,
                          style: TextStyle(
                            fontSize: iconLetter == 'PDF' ? 7 : 9,
                            fontWeight: FontWeight.w900,
                            color: gradient.first,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),

              // ===============================================================
              // TITLE + DESCRIPTION
              // ===============================================================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isMobile ? 17 : 19,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        height: 1.3,
                        color: secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // ===============================================================
              // PLUS BUTTON
              // ===============================================================
              Container(
                height: isMobile ? 42 : 46,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 11 : 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 5),
                      Text(
                        buttonText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
