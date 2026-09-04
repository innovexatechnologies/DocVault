import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

export 'package:permission_handler/permission_handler.dart';

import '../widgets/permission_request_dialog.dart';

class PermissionService {
  // ============================================================
  // CAMERA PERMISSION STATUS & REQUEST
  // ============================================================

  Future<PermissionStatus> getCameraStatus() async {
    return await Permission.camera.status;
  }

  Future<PermissionStatus> requestCameraPermission() async {
    return await Permission.camera.request();
  }

  Future<bool> hasCameraPermission() async {
    final status = await getCameraStatus();
    return status.isGranted || status.isLimited;
  }

  // ============================================================
  // GALLERY / PHOTOS PERMISSION STATUS & REQUEST
  // ============================================================

  Future<PermissionStatus> getGalleryStatus() async {
    return await Permission.photos.status;
  }

  Future<PermissionStatus> requestGalleryPermission() async {
    return await Permission.photos.request();
  }

  Future<bool> hasGalleryPermission() async {
    final status = await getGalleryStatus();
    return status.isGranted || status.isLimited;
  }

  // ============================================================
  // OPEN APP SETTINGS
  // ============================================================

  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  // ============================================================
  // RE-REQUEST OR PROMPT FOR CAMERA
  // ============================================================

  /// Intelligently requests camera access without throwing error snackbars:
  /// - If granted: triggers [onGranted] and returns `true`.
  /// - If denied: triggers the system permission dialog again.
  /// - If permanently denied: shows a friendly dialog prompting to open Settings.
  Future<bool> requestOrPromptCamera(
    BuildContext context, {
    VoidCallback? onGranted,
  }) async {
    try {
      final currentStatus = await Permission.camera.status;

      if (currentStatus.isGranted || currentStatus.isLimited) {
        onGranted?.call();
        return true;
      }

      if (currentStatus.isPermanentlyDenied || currentStatus.isRestricted) {
        if (!context.mounted) return false;

        final shouldOpenSettings = await PermissionRequestDialog.show(
          context,
          title: 'Camera Access Required',
          message:
              'DocVault needs camera access to scan and capture documents. Please enable camera permission in device settings.',
          icon: Icons.camera_alt_rounded,
          positiveLabel: 'Open Settings',
          negativeLabel: 'Not Now',
        );

        if (shouldOpenSettings) {
          // Check permission again after returning from settings
          final updatedStatus = await Permission.camera.status;
          if (updatedStatus.isGranted || updatedStatus.isLimited) {
            onGranted?.call();
            return true;
          }
        }
        return false;
      }

      // If status is denied, request again to trigger the OS dialog
      final requestedStatus = await Permission.camera.request();
      if (requestedStatus.isGranted || requestedStatus.isLimited) {
        onGranted?.call();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error handling camera permission: $e');
      return false;
    }
  }

  // ============================================================
  // RE-REQUEST OR PROMPT FOR GALLERY / PHOTOS
  // ============================================================

  /// Intelligently requests photos access without throwing error snackbars:
  /// - If granted: triggers [onGranted] and returns `true`.
  /// - If denied: triggers the system permission dialog again.
  /// - If permanently denied: shows a friendly dialog prompting to open Settings.
  Future<bool> requestOrPromptGallery(
    BuildContext context, {
    VoidCallback? onGranted,
  }) async {
    try {
      final currentStatus = await Permission.photos.status;

      if (currentStatus.isGranted || currentStatus.isLimited) {
        onGranted?.call();
        return true;
      }

      if (currentStatus.isPermanentlyDenied || currentStatus.isRestricted) {
        if (!context.mounted) return false;

        final shouldOpenSettings = await PermissionRequestDialog.show(
          context,
          title: 'Photos Access Required',
          message:
              'DocVault needs access to your photos to import and convert documents. Please enable photos permission in device settings.',
          icon: Icons.photo_library_rounded,
          positiveLabel: 'Open Settings',
          negativeLabel: 'Not Now',
        );

        if (shouldOpenSettings) {
          final updatedStatus = await Permission.photos.status;
          if (updatedStatus.isGranted || updatedStatus.isLimited) {
            onGranted?.call();
            return true;
          }
        }
        return false;
      }

      final requestedStatus = await Permission.photos.request();
      if (requestedStatus.isGranted || requestedStatus.isLimited) {
        onGranted?.call();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error handling gallery permission: $e');
      return false;
    }
  }
}