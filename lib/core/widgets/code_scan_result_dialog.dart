import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/code_scanner_service.dart';
import '../theme/app_theme.dart';

/// Shows the decoded value from [CodeScannerService.scan] with Copy
/// and Share actions. Visual style matches [UnsavedChangesDialog] so
/// it reads as part of the same app, not a bolted-on component.
class CodeScanResultDialog extends StatelessWidget {
  final ScannedCode code;

  const CodeScanResultDialog({
    super.key,
    required this.code,
  });

  static Future<void> show(
    BuildContext context,
    ScannedCode code,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => CodeScanResultDialog(code: code),
    );
  }

  String get _typeLabel {
    switch (code.type) {
      case ScannedCodeType.url:
        return 'Link';
      case ScannedCodeType.wifi:
        return 'Wi-Fi network';
      case ScannedCodeType.email:
        return 'Email';
      case ScannedCodeType.phone:
        return 'Phone number';
      case ScannedCodeType.sms:
        return 'Text message';
      case ScannedCodeType.contactInfo:
        return 'Contact';
      case ScannedCodeType.isbn:
        return 'ISBN';
      case ScannedCodeType.product:
        return 'Product code';
      case ScannedCodeType.geo:
        return 'Location';
      case ScannedCodeType.calendarEvent:
        return 'Calendar event';
      case ScannedCodeType.driverLicense:
        return 'Driver license';
      case ScannedCodeType.text:
      case ScannedCodeType.unknown:
        return code.format.replaceAll('_', ' ');
    }
  }

  IconData get _typeIcon {
    switch (code.type) {
      case ScannedCodeType.url:
        return Icons.link_rounded;
      case ScannedCodeType.wifi:
        return Icons.wifi_rounded;
      case ScannedCodeType.email:
        return Icons.email_rounded;
      case ScannedCodeType.phone:
        return Icons.phone_rounded;
      case ScannedCodeType.sms:
        return Icons.sms_rounded;
      case ScannedCodeType.contactInfo:
        return Icons.contact_page_rounded;
      default:
        return Icons.qr_code_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final value = code.bestDisplayValue;

    return AlertDialog(
      backgroundColor: isDark
          ? AppTheme.surfaceDark
          : AppTheme.surfaceLight,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
      contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
      title: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _typeIcon,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              _typeLabel,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.cardDark
                : AppTheme.bgLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SelectableText(
            value.isEmpty ? '(empty)' : value,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colorScheme.onSurface.withValues(
                alpha: 0.85,
              ),
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor:
                colorScheme.onSurface.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          child: const Text(
            'Close',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: value.isEmpty
              ? null
              : () async {
                  await Clipboard.setData(
                    ClipboardData(text: value),
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          child: const Text(
            'Copy',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        ElevatedButton(
          onPressed: value.isEmpty
              ? null
              : () => Share.share(value),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 11,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Share',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
