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

  const HomeScreen({super.key, this.onNavigateToAllFiles});

  void _navigateToSourceSelection(
    BuildContext context,
    ConversionType conversionType,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SourceSelectionScreen(conversionType: conversionType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveHelper.getResponsivePadding(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: padding,
              vertical: isMobile ? 20 : 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================================
                // HEADER
                // ==========================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: isMobile ? 44 : 50,
                          height: isMobile ? 44 : 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.accentColor,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: isDark ? 0.20 : 0.15,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.description_rounded,
                            color: isDark ? AppTheme.bgDark : Colors.white,
                            size: isMobile ? 24 : 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppConstants.appName,
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: colorScheme.onSurface,
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
                        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor,
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
                          color: colorScheme.onSurface,
                          size: 21,
                        ),
                        tooltip: isDark
                            ? 'Switch to Light Mode'
                            : 'Switch to Dark Mode',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isMobile ? 28 : 38),

                // ==========================================================
                // WELCOME
                // ==========================================================
                Text(
                  'Your documents.',
                  style: TextStyle(
                    fontSize: isMobile ? 30 : 38,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -1.2,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Simplified.',
                  style: TextStyle(
                    fontSize: isMobile ? 30 : 38,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -1.2,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Convert, edit, organize and export your photos into professional files.',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    height: 1.5,
                    color: colorScheme.onSurface.withValues(alpha: 0.60),
                  ),
                ),

                SizedBox(height: isMobile ? 24 : 34),

                // ==========================================================
                // 1. IMAGES TO PDF CARD
                // ==========================================================
                _buildConversionHeroCard(
                  context,
                  title: 'Images to PDF',
                  description:
                      'Scan documents or choose images to generate a crisp, standardized PDF file.',
                  buttonLabel: AppConstants.createPdf,
                  icon: Icons.picture_as_pdf_rounded,
                  gradientColors: [
                    AppTheme.primaryColor,
                    isDark ? const Color(0xFF00A77E) : const Color(0xFF087F73),
                  ],
                  onTap: () => _navigateToSourceSelection(
                    context,
                    ConversionType.pdf,
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================================================
                // 2. IMAGES TO DOCS CARD
                // ==========================================================
                _buildConversionHeroCard(
                  context,
                  title: 'Images to Docs',
                  description:
                      'Combine your photos into an editable Microsoft Word (.docx) document.',
                  buttonLabel: 'Create DOCX',
                  icon: Icons.article_rounded,
                  gradientColors: [
                    const Color(0xFF1565C0),
                    isDark ? const Color(0xFF1976D2) : const Color(0xFF1E88E5),
                  ],
                  onTap: () => _navigateToSourceSelection(
                    context,
                    ConversionType.docs,
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================================================
                // 3. IMAGES TO PPT CARD
                // ==========================================================
                _buildConversionHeroCard(
                  context,
                  title: 'Images to PPT',
                  description:
                      'Transform pages and photos into a widescreen PowerPoint (.pptx) presentation.',
                  buttonLabel: 'Create PPTX',
                  icon: Icons.slideshow_rounded,
                  gradientColors: [
                    const Color(0xFFD84315),
                    isDark ? const Color(0xFFE64A19) : const Color(0xFFF4511E),
                  ],
                  onTap: () => _navigateToSourceSelection(
                    context,
                    ConversionType.ppt,
                  ),
                ),

                SizedBox(height: isMobile ? 26 : 34),

                // ==========================================================
                // ALL FILES QUICK ACCESS BANNER
                // ==========================================================
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (onNavigateToAllFiles != null) {
                        onNavigateToAllFiles!();
                      } else {
                        Navigator.of(context).pushNamed('/all-files');
                      }
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.dividerDark
                              : AppTheme.dividerColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: isDark ? 0.18 : 0.10,
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.folder_rounded,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Saved Documents',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'View, share, rename and export your PDFs, DOCS and PPTs',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: isMobile ? 20 : 28),

                // ==========================================================
                // INFO CARD
                // ==========================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.dividerDark
                          : AppTheme.dividerColor,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(
                            alpha: isDark ? 0.14 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Private & Offline',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'All files are converted locally on your phone without cloud uploads or an account.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: colorScheme.onSurface.withValues(
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

  Widget _buildConversionHeroCard(
    BuildContext context, {
    required String title,
    required String description,
    required String buttonLabel,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isMobile ? 20 : 26),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(
              alpha: isDark ? 0.22 : 0.16,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: isMobile ? 44 : 48,
                height: isMobile ? 44 : 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isMobile ? 24 : 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: isMobile ? 48 : 52,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: gradientColors.first,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      buttonLabel,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
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
    );
  }
}