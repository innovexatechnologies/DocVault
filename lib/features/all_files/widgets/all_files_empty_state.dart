import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';

class AllFilesEmptyState extends StatelessWidget {
  final bool isSearch;
  final VoidCallback? onCreatePdf;
  final VoidCallback? onClearSearch;

  const AllFilesEmptyState({
    super.key,
    this.isSearch = false,
    this.onCreatePdf,
    this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveHelper.isMobile(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isMobile ? 100 : 120,
              height: isMobile ? 100 : 120,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isSearch
                      ? Icons.search_off_rounded
                      : Icons.folder_open_rounded,
                  size: isMobile ? 48 : 58,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearch ? 'No matching documents' : 'No PDFs saved yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMobile ? 20 : 22,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isSearch
                  ? 'Try searching with a different file name or clear your search query.'
                  : 'All PDFs you create with DocScanner will be stored locally and listed right here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: colorScheme.onSurface.withValues(alpha: 0.60),
              ),
            ),
            const SizedBox(height: 28),
            if (isSearch && onClearSearch != null)
              OutlinedButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: const Text('Clear Search'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )
            else if (!isSearch)
              ElevatedButton.icon(
                onPressed: onCreatePdf ??
                    () => Navigator.of(context).pushNamedAndRemoveUntil(
                          '/home',
                          (route) => false,
                        ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Create PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
