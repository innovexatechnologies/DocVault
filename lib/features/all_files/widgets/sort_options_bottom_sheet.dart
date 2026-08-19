import 'package:flutter/material.dart';
import '../../../core/providers/pdf_manager_provider.dart';
import '../../../core/theme/app_theme.dart';

class SortOptionsBottomSheet extends StatelessWidget {
  final PdfSortOption currentOption;
  final ValueChanged<PdfSortOption> onSelect;

  const SortOptionsBottomSheet({
    super.key,
    required this.currentOption,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.80,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 12, bottom: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.sort_rounded, color: AppTheme.primaryColor),
                      const SizedBox(width: 10),
                      Text(
                        'Sort Files By',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                ...PdfSortOption.values.map((option) {
                  final isSelected = option == currentOption;
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 2,
                    ),
                    leading: Icon(
                      _getSortIcon(option),
                      color: isSelected
                          ? AppTheme.primaryColor
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 22,
                    ),
                    title: Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.primaryColor
                            : colorScheme.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      onSelect(option);
                      Navigator.of(context).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getSortIcon(PdfSortOption option) {
    switch (option) {
      case PdfSortOption.newestFirst:
        return Icons.schedule_rounded;
      case PdfSortOption.oldestFirst:
        return Icons.history_rounded;
      case PdfSortOption.nameAsc:
        return Icons.sort_by_alpha_rounded;
      case PdfSortOption.nameDesc:
        return Icons.sort_by_alpha_rounded;
      case PdfSortOption.sizeLargest:
        return Icons.arrow_downward_rounded;
      case PdfSortOption.sizeSmallest:
        return Icons.arrow_upward_rounded;
    }
  }
}
