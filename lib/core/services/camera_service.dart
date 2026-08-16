import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  late CameraController _controller;
  late List<CameraDescription> _cameras;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  CameraController get controller => _controller;

  Future<void> initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('No camera available');
      }

      final firstCamera = _cameras.first;

      _controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      rethrow;
    }
  }

  Future<XFile?> capturePhoto() async {
    if (!_isInitialized) {
      throw Exception('Camera not initialized');
    }

    try {
      final image = await _controller.takePicture();
      return image;
    } catch (e) {
      debugPrint('Capture error: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await _controller.dispose();
      _isInitialized = false;
    }
  }
}
