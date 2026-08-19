import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/conversion_type.dart';
import '../../../models/pdf_document.dart';

class PdfDetailsDialog extends StatelessWidget {
  final PdfDocument document;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onExport;

  const PdfDetailsDialog({
    super.key,
    required this.document,
    required this.onOpen,
    required this.onShare,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final docType = document.documentType;
    final unitLabel = docType == ConversionType.ppt
        ? (document.pageCount == 1 ? 'slide' : 'slides')
        : (document.pageCount == 1 ? 'page' : 'pages');

    return AlertDialog(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor,
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: docType.badgeColor.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(docType.icon, color: docType.badgeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            '${docType.shortName} Details',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                context,
                icon: Icons.title_rounded,
                label: 'File Name',
                value: document.fileName,
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                context,
                icon: Icons.category_rounded,
                label: 'Format Type',
                value: '${docType.label} (.${docType.extension})',
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                context,
                icon: Icons.data_usage_rounded,
                label: 'File Size',
                value:
                    '${document.formattedFileSize} (${document.fileSizeBytes} bytes)',
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                context,
                icon: Icons.auto_stories_rounded,
                label: docType == ConversionType.ppt
                    ? 'Slide Count'
                    : 'Page Count',
                value: '${document.pageCount} $unitLabel',
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                context,
                icon: Icons.calendar_today_rounded,
                label: 'Created',
                value: document.formattedCreatedDate,
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                context,
                icon: Icons.update_rounded,
                label: 'Modified',
                value: document.formattedModifiedDate,
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                context,
                icon: Icons.folder_outlined,
                label: 'Storage Path',
                value: document.filePath,
                isPath: true,
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {
                Navigator.of(context).pop();
                onShare();
              },
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              color: docType.badgeColor,
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context).pop();
                onExport();
              },
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Save to Device',
              color: docType.badgeColor,
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onOpen();
              },
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: Text('Open ${docType.shortName}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: docType.badgeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isPath = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: document.documentType.badgeColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: isPath ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: isPath ? 'monospace' : null,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
