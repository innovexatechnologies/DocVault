import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/conversion_type.dart';
import '../../../models/pdf_document.dart';

class PdfFileCard extends StatelessWidget {
  final PdfDocument document;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMoreOptions;

  const PdfFileCard({
    super.key,
    required this.document,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final docType = document.documentType;

    final selectedBorderColor = docType.badgeColor;
    final defaultBorderColor = isDark ? AppTheme.dividerDark : AppTheme.dividerColor;
    final unitBadge = docType == ConversionType.ppt ? '${document.pageCount}s' : '${document.pageCount}p';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? docType.badgeColor.withValues(alpha: isDark ? 0.15 : 0.08)
            : (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? selectedBorderColor : defaultBorderColor,
          width: isSelected ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.20 : 0.03,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Selection Checkbox or File Icon
                if (isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? docType.badgeColor : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? docType.badgeColor
                              : (isDark ? AppTheme.dividerDark : AppTheme.dividerColor),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),

                // Format Thumbnail Icon with Badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            docType.gradientStart.withValues(alpha: isDark ? 0.25 : 0.15),
                            docType.gradientEnd.withValues(alpha: isDark ? 0.15 : 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: docType.badgeColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          docType.icon,
                          color: docType.badgeColor,
                          size: 26,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: docType.badgeColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          unitBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 14),

                // File Info with 2-line flexible filename
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        document.fileName,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text(
                            docType.shortName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: docType.badgeColor,
                            ),
                          ),
                          Text(
                            '•',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.35),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            document.formattedFileSize,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withValues(alpha: 0.70),
                            ),
                          ),
                          Text(
                            '•',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.35),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            document.formattedCreatedDate,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions Menu button (shown when not in selection mode)
                if (!isSelectionMode)
                  IconButton(
                    onPressed: onMoreOptions,
                    icon: const Icon(Icons.more_vert_rounded),
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    splashRadius: 20,
                    tooltip: 'More actions',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
