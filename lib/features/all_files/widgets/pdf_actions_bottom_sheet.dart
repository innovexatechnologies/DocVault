import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/pdf_document.dart';

class PdfActionsBottomSheet extends StatelessWidget {
  final PdfDocument document;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback? onEdit;
  final VoidCallback onExport;
  final VoidCallback onDetails;
  final VoidCallback onDelete;

  const PdfActionsBottomSheet({
    super.key,
    required this.document,
    required this.onOpen,
    required this.onShare,
    required this.onRename,
    this.onEdit,
    required this.onExport,
    required this.onDetails,
    required this.onDelete,
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
          maxHeight: screenHeight * 0.85,
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
                // Drag handle pill
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

                // Document Header Info with 2-line flexible filename
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(
                            alpha: isDark ? 0.20 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              document.fileName,
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${document.formattedFileSize} • ${document.pageCount} ${document.pageCount == 1 ? 'page' : 'pages'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 6),

                _buildActionTile(
                  context,
                  icon: Icons.visibility_outlined,
                  title: 'Open',
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpen();
                  },
                ),
                if (onEdit != null)
                  _buildActionTile(
                    context,
                    icon: Icons.tune_rounded,
                    title: 'Edit PDF',
                    subtitle: 'Crop, rotate, add/delete pages, and edit document',
                    onTap: () {
                      Navigator.of(context).pop();
                      onEdit!();
                    },
                  ),
                _buildActionTile(
                  context,
                  icon: Icons.share_outlined,
                  title: 'Share',
                  onTap: () {
                    Navigator.of(context).pop();
                    onShare();
                  },
                ),
                _buildActionTile(
                  context,
                  icon: Icons.edit_outlined,
                  title: 'Rename',
                  onTap: () {
                    Navigator.of(context).pop();
                    onRename();
                  },
                ),
                _buildActionTile(
                  context,
                  icon: Icons.download_rounded,
                  title: 'Save to Device',
                  subtitle: 'Export copy to phone storage',
                  onTap: () {
                    Navigator.of(context).pop();
                    onExport();
                  },
                ),
                _buildActionTile(
                  context,
                  icon: Icons.info_outline_rounded,
                  title: 'Details',
                  onTap: () {
                    Navigator.of(context).pop();
                    onDetails();
                  },
                ),
                _buildActionTile(
                  context,
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete',
                  isDestructive: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final color = isDestructive ? AppTheme.errorColor : colorScheme.onSurface;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDestructive
              ? AppTheme.errorColor.withValues(alpha: 0.10)
              : (isDark ? AppTheme.bgDark : AppTheme.bgLight),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: color,
          size: 19,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isDestructive ? FontWeight.w700 : FontWeight.w600,
          color: color,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
