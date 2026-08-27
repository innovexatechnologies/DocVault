import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/providers/theme_provider.dart';
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 32,
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

                    // APP LOGO + NAME
                    Row(
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

                        Text(
                          AppConstants.appName,
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: primaryText,
                          ),
                        ),
                      ],
                    ),

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
                          context
                              .read<ThemeProvider>()
                              .toggleTheme();
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
                  'Convert.',
                  style: TextStyle(
                    fontSize: isMobile ? 38 : 48,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -1.8,
                    color: primaryText,
                  ),
                ),

                Text(
                  'Create.',
                  style: TextStyle(
                    fontSize: isMobile ? 38 : 48,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -1.8,
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
                    'Simplified.',
                    style: TextStyle(
                      fontSize: isMobile ? 38 : 48,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      letterSpacing: -1.8,
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

                    Text(
                      'Popular Conversions',
                      style: TextStyle(
                        fontSize: isMobile ? 21 : 24,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                        letterSpacing: -0.4,
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
                      'Convert your images into\nhigh-quality PDF files.',
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

                const SizedBox(height: 18),

                // =================================================================
                // DOCX
                // =================================================================

                _buildConversionCard(
                  context,
                  isDark: isDark,
                  isMobile: isMobile,
                  title: 'Images to DOCX',
                  description:
                      'Convert images to editable\nWord documents.',
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

                const SizedBox(height: 18),

                // =================================================================
                // PPT
                // =================================================================

                _buildConversionCard(
                  context,
                  isDark: isDark,
                  isMobile: isMobile,
                  title: 'Images to PPT',
                  description:
                      'Convert images to powerful\nPowerPoint presentations.',
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

                const SizedBox(height: 22),

                // =================================================================
                // ALL FILES
                // =================================================================

                _buildAllFilesCard(
                  context,
                  isDark: isDark,
                  isMobile: isMobile,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // CONVERSION CARD
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
    final primaryText = isDark
        ? Colors.white
        : const Color(0xFF111827);

    final secondaryText = isDark
        ? const Color(0xFFAAB3C5)
        : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 18 : 24,
        isMobile ? 18 : 24,
        isMobile ? 18 : 24,
        isMobile ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0B1020)
            : Colors.white,
        borderRadius: BorderRadius.circular(
          isMobile ? 22 : 26,
        ),
        border: Border.all(
          color: gradient.first.withValues(
            alpha: isDark ? 0.30 : 0.15,
          ),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(
              alpha: isDark ? 0.10 : 0.07,
            ),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [

          // TOP CONTENT
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              // ICON
              Container(
                width: isMobile ? 112 : 126,
                height: isMobile ? 112 : 126,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(21),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withValues(
                        alpha: 0.28,
                      ),
                      blurRadius: 22,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Stack(
                  children: [

                    Center(
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: isMobile ? 57 : 64,
                      ),
                    ),

                    // SMALL LABEL
                    Positioned(
                      right: 7,
                      top: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: 0.95,
                          ),
                          borderRadius:
                              BorderRadius.circular(7),
                        ),
                        child: Text(
                          iconLetter,
                          style: TextStyle(
                            fontSize: iconLetter == 'PDF'
                                ? 10
                                : 13,
                            fontWeight: FontWeight.w900,
                            color: gradient.first,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 17),

              // TITLE + DESCRIPTION
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isMobile ? 21 : 25,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 9),

                    Text(
                      description,
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 15,
                        height: 1.45,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              // ARROW
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: gradient.first.withValues(
                    alpha: isDark ? 0.10 : 0.07,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: gradient.first,
                  size: 30,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // CREATE BUTTON
          SizedBox(
            width: double.infinity,
            height: isMobile ? 52 : 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withValues(
                      alpha: isDark ? 0.20 : 0.14,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius:
                      BorderRadius.circular(30),
                  child: Center(
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [

                        const Icon(
                          Icons.description_rounded,
                          color: Colors.white,
                          size: 21,
                        ),

                        const SizedBox(width: 9),

                        Text(
                          buttonText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 16 : 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ALL FILES CARD
  // ===========================================================================

  Widget _buildAllFilesCard(
    BuildContext context, {
    required bool isDark,
    required bool isMobile,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onNavigateToAllFiles != null) {
            onNavigateToAllFiles!();
          } else {
            Navigator.of(context).pushNamed(
              '/all-files',
            );
          }
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(
            isMobile ? 17 : 22,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0B1020)
                : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF202A42)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [

              // FOLDER ICON
              Container(
                width: isMobile ? 48 : 54,
                height: isMobile ? 48 : 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6D4AFF),
                      Color(0xFF9747FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.folder_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    Text(
                      'All Files',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'View and manage your documents',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF171E32)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}