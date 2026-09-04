import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';

/// Premium, responsive dialog that gracefully prompts the user to grant
/// permissions or open device settings when a feature is denied or permanently denied.
class PermissionRequestDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String positiveLabel;
  final String negativeLabel;
  final Future<bool> Function()? onOpenSettings;

  const PermissionRequestDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.security_rounded,
    this.positiveLabel = 'Open Settings',
    this.negativeLabel = 'Not Now',
    this.onOpenSettings,
  });

  /// Displays the permission dialog. Returns `true` if settings was opened or access granted.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.security_rounded,
    String positiveLabel = 'Open Settings',
    String negativeLabel = 'Not Now',
    Future<bool> Function()? onOpenSettings,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PermissionRequestDialog(
        title: title,
        message: message,
        icon: icon,
        positiveLabel: positiveLabel,
        negativeLabel: negativeLabel,
        onOpenSettings: onOpenSettings,
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final isSmall = ResponsiveHelper.isSmallMobile(context);

    return AlertDialog(
      backgroundColor:
          isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      actionsOverflowButtonSpacing: 8,
      titlePadding: EdgeInsets.fromLTRB(
        isSmall ? 18 : 24,
        isSmall ? 18 : 24,
        isSmall ? 18 : 24,
        8,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        isSmall ? 18 : 24,
        8,
        isSmall ? 18 : 24,
        16,
      ),
      title: Row(
        children: [
          Container(
            width: isSmall ? 42 : 48,
            height: isSmall ? 42 : 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: isSmall ? 22 : 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isSmall ? 16 : 18,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(
          fontSize: isSmall ? 13 : 14,
          height: 1.5,
          color: colorScheme.onSurface.withValues(alpha: 0.72),
        ),
      ),
      actionsPadding: EdgeInsets.fromLTRB(
        isSmall ? 14 : 20,
        0,
        isSmall ? 14 : 20,
        isSmall ? 16 : 20,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor:
                colorScheme.onSurface.withValues(alpha: 0.65),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
          ),
          child: Text(
            negativeLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(context).pop(true);
            if (onOpenSettings != null) {
              await onOpenSettings!();
            } else {
              await openAppSettings();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 14 : 18,
              vertical: 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            positiveLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
