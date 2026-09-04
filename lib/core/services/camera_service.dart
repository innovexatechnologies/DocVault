import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized && _controller != null;
  CameraController? get controller => _controller;

  Future<void> initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('No camera available');
      }

      final firstCamera = _cameras.first;

      final controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      _controller = controller;
      _isInitialized = true;
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      _isInitialized = false;
      _controller = null;
      rethrow;
    }
  }

  Future<XFile?> capturePhoto() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('Camera not initialized');
    }

    try {
      final image = await _controller!.takePicture();
      return image;
    } catch (e) {
      debugPrint('Capture error: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_controller != null) {
      try {
        await _controller!.dispose();
      } catch (e) {
        debugPrint('Camera dispose error: $e');
      }
      _controller = null;
      _isInitialized = false;
    }
  }
}
