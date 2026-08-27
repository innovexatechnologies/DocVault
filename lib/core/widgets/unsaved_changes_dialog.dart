import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum UnsavedChangesAction {
  save,
  discard,
  cancel,
}

class UnsavedChangesDialog extends StatelessWidget {
  final String title;
  final String message;
  final String saveLabel;
  final String discardLabel;
  final String cancelLabel;
  final bool showSave;

  const UnsavedChangesDialog({
    super.key,
    this.title = 'Unsaved Changes',
    this.message =
        'You have unsaved changes. What would you like to do?',
    this.saveLabel = 'Save Changes',
    this.discardLabel = 'Discard',
    this.cancelLabel = 'Cancel',
    this.showSave = true,
  });

  static Future<UnsavedChangesAction?> show(
    BuildContext context, {
    String title = 'Unsaved Changes',
    String message =
        'You have unsaved changes. What would you like to do?',
    String saveLabel = 'Save Changes',
    String discardLabel = 'Discard',
    String cancelLabel = 'Cancel',
    bool showSave = true,
  }) {
    return showDialog<UnsavedChangesAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UnsavedChangesDialog(
        title: title,
        message: message,
        saveLabel: saveLabel,
        discardLabel: discardLabel,
        cancelLabel: cancelLabel,
        showSave: showSave,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: isDark
          ? AppTheme.surfaceDark
          : AppTheme.surfaceLight,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        22,
        22,
        22,
        8,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        22,
        8,
        22,
        8,
      ),
      title: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color:
                  AppTheme.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.accentColor,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
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
          fontSize: 14,
          height: 1.5,
          color:
              colorScheme.onSurface.withValues(alpha: 0.68),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        16,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop(UnsavedChangesAction.cancel),
          style: TextButton.styleFrom(
            foregroundColor:
                colorScheme.onSurface.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          child: Text(
            cancelLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop(UnsavedChangesAction.discard),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          child: Text(
            discardLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (showSave)
          ElevatedButton(
            onPressed: () => Navigator.of(context)
                .pop(UnsavedChangesAction.save),
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
            child: Text(
              saveLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}