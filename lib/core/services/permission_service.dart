import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // ============================================================
  // CAMERA PERMISSION
  // ============================================================

  Future<PermissionStatus> requestCameraPermission() async {
    return await Permission.camera.request();
  }

  // ============================================================
  // GALLERY / PHOTOS PERMISSION
  // ============================================================

  Future<PermissionStatus> requestGalleryPermission() async {
    return await Permission.photos.request();
  }

  // ============================================================
  // OPEN APP SETTINGS
  // ============================================================

  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}