 import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/image_selection_provider.dart';
import '../../core/services/image_editor_service.dart';
import '../../core/services/image_processing_worker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/unsaved_changes_dialog.dart';

enum EditorMode {
  none,
  crop,
  rotate,
  text,
  filters,
}

class ImageEditorScreen extends StatefulWidget {
  final String imageId;
  final String imagePath;
  final int pageIndex;

  const ImageEditorScreen({
    super.key,
    required this.imageId,
    required this.imagePath,
    this.pageIndex = 0,
  });

  @override
  State<ImageEditorScreen> createState() =>
      _ImageEditorScreenState();
}

class _ImageEditorScreenState
    extends State<ImageEditorScreen> {
  final ImageEditorService _editorService =
      ImageEditorService();

  late String _currentWorkingPath;

  // The "source" image that all filters are computed from. This is
  // updated by structural edits (rotate/flip/crop/text) since those
  // are meant to be permanent, but it is NEVER updated by applying a
  // filter. Every filter switch re-applies the newly selected filter
  // to THIS path, so filters never stack on top of each other and
  // "Original" always has an untouched image to fall back to.
  late String _baseImagePath;

  bool _isProcessing = false;
  bool _hasUnsavedEdits = false;

  /// Monotonic counter bumped on every edit. Used to ignore stale
  /// async results so an older operation can never overwrite a newer
  /// one (extra insurance against filter overlap/races).
  int _editGeneration = 0;

  EditorMode _activeMode = EditorMode.none;

  // ============================================================
  // TEXT
  // ============================================================

  String _overlayText = '';

  double _textXPercent = 0.5;
  double _textYPercent = 0.5;

  Color _textColor = Colors.black;

  final int _textFontSize = 24;

  // ============================================================
  // CROP
  // ============================================================

  String _selectedCropRatio = 'Free';

  // Four independently-movable corners, each normalized (0.0 -> 1.0)
  // against the *actual image bounds* (not the canvas/letterbox).
  // This is what makes real perspective correction possible: the
  // user can drag any corner onto a skewed document edge instead of
  // being limited to an axis-aligned rectangle.
  Offset _cropTopLeft = const Offset(0.08, 0.08);
  Offset _cropTopRight = const Offset(0.92, 0.08);
  Offset _cropBottomLeft = const Offset(0.08, 0.92);
  Offset _cropBottomRight = const Offset(0.92, 0.92);

  static const Offset _defaultCropTopLeft = Offset(0.08, 0.08);
  static const Offset _defaultCropTopRight = Offset(0.92, 0.08);
  static const Offset _defaultCropBottomLeft = Offset(0.08, 0.92);
  static const Offset _defaultCropBottomRight = Offset(0.92, 0.92);

  void _resetCropCorners() {
    _cropTopLeft = _defaultCropTopLeft;
    _cropTopRight = _defaultCropTopRight;
    _cropBottomLeft = _defaultCropBottomLeft;
    _cropBottomRight = _defaultCropBottomRight;
  }

  /// Bounding rect of the current quad, used for the ratio presets
  /// (which still behave as an axis-aligned rectangle) and for
  /// backwards-compatible ratio math.
  Rect get _cropBoundingRect => Rect.fromLTRB(
        [
          _cropTopLeft.dx,
          _cropTopRight.dx,
          _cropBottomLeft.dx,
          _cropBottomRight.dx,
        ].reduce(math.min),
        [
          _cropTopLeft.dy,
          _cropTopRight.dy,
          _cropBottomLeft.dy,
          _cropBottomRight.dy,
        ].reduce(math.min),
        [
          _cropTopLeft.dx,
          _cropTopRight.dx,
          _cropBottomLeft.dx,
          _cropBottomRight.dx,
        ].reduce(math.max),
        [
          _cropTopLeft.dy,
          _cropTopRight.dy,
          _cropBottomLeft.dy,
          _cropBottomRight.dy,
        ].reduce(math.max),
      );

  void _setCropFromRect(Rect rect) {
    _cropTopLeft = Offset(rect.left, rect.top);
    _cropTopRight = Offset(rect.right, rect.top);
    _cropBottomLeft = Offset(rect.left, rect.bottom);
    _cropBottomRight = Offset(rect.right, rect.bottom);
  }

  Size? _imageSize;

  // ============================================================
  // FILTER
  // ============================================================

  ImageFilterType _activeFilter =
      ImageFilterType.none;

  /// Produces the preview path for [basePath] under the currently
  /// active filter. Used both by the filter picker itself and by
  /// every structural edit (rotate/flip/crop/text), so that after a
  /// structural edit the on-screen preview still reflects whatever
  /// filter was selected -- without ever baking that filter into
  /// `_baseImagePath`.
  Future<String> _applyActiveFilterTo(
    String basePath,
  ) async {
    if (_activeFilter ==
        ImageFilterType.none) {
      return basePath;
    }

    return _editorService.applyFilter(
      basePath,
      _activeFilter,
    );
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _currentWorkingPath =
        widget.imagePath;

    _baseImagePath =
        widget.imagePath;

    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    try {
      final bytes =
          await File(_currentWorkingPath)
              .readAsBytes();

      final codec =
          await ui.instantiateImageCodec(bytes);

      final frame =
          await codec.getNextFrame();

      if (!mounted) return;

      setState(() {
        _imageSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      });

      frame.image.dispose();
      codec.dispose();
    } catch (_) {}
  }

  /// Deletes an intermediate file that is no longer needed. The base
  /// image and the original source are NEVER deleted — only preview
  /// files that this editor session created and then replaced.
  void _removeStalePreview(String oldPath) {
    if (oldPath.isEmpty) return;
    if (oldPath == _baseImagePath) return;
    if (oldPath == widget.imagePath) return;

    final file = File(oldPath);

    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      // Best effort only; a failed delete is never fatal.
    }
  }

  // ============================================================
  // ROTATE
  // ============================================================

  Future<void> _handleRotate(
    int degrees,
  ) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final newBasePath =
          await _editorService.rotateImage(
        _baseImagePath,
        degrees,
      );

      final preview =
          await _applyActiveFilterTo(
        newBasePath,
      );

      if (!mounted) return;

      // Discard the preview that was shown before this rotation; it
      // is no longer referenced and would only fill the cache.
      _removeStalePreview(_currentWorkingPath);

      setState(() {
        _baseImagePath = newBasePath;
        _currentWorkingPath = preview;
        _hasUnsavedEdits = true;
      });

      await _loadImageSize();
    } catch (e) {
      _showError(
        'Rotation failed: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // FLIP
  // ============================================================

  Future<void> _handleFlip({
    bool horizontal = true,
    bool vertical = false,
  }) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final newBasePath =
          await _editorService.flipImage(
        _baseImagePath,
        horizontal: horizontal,
        vertical: vertical,
      );

      final preview =
          await _applyActiveFilterTo(
        newBasePath,
      );

      if (!mounted) return;

      // Discard the preview that was shown before this flip; it is no
      // longer referenced and would only fill the cache.
      _removeStalePreview(_currentWorkingPath);

      setState(() {
        _baseImagePath = newBasePath;
        _currentWorkingPath = preview;
        _hasUnsavedEdits = true;
      });
    } catch (e) {
      _showError(
        'Flip failed: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  Future<void> _handleFilter(
    ImageFilterType filter,
  ) async {
    if (_isProcessing) return;

    if (filter == ImageFilterType.none) {
      // Discard the previously shown filter output (if any) so the
      // cache does not fill up with files nobody displays anymore.
      _removeStalePreview(_currentWorkingPath);

      setState(() {
        _activeFilter =
            ImageFilterType.none;

        // Restore the untouched (pre-filter) source instead of
        // leaving whatever the last filter produced on screen.
        _currentWorkingPath =
            _baseImagePath;

        _hasUnsavedEdits = true;
      });
      return;
    }

    if (_activeFilter == filter) {
      return;
    }

    // Every edit bumps this counter. If a filter finishes AFTER a
    // newer operation was started, its (now stale) result is ignored,
    // so an old preview can never overwrite the current one.
    final generation = ++_editGeneration;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Always filter the original/base image, never the current
      // (possibly already-filtered) preview -- otherwise switching
      // B/W -> Grayscale would apply grayscale on top of B/W instead
      // of computing grayscale fresh from the source.
      final newPath =
          await _editorService.applyFilter(
        _baseImagePath,
        filter,
      );

      if (!mounted || generation != _editGeneration) {
        return;
      }

      // Discard the previously shown preview file (it is never the
      // base image, so this is always safe).
      _removeStalePreview(_currentWorkingPath);

      setState(() {
        _currentWorkingPath = newPath;
        _activeFilter = filter;
        _hasUnsavedEdits = true;
      });
    } catch (e) {
      _showError(
        'Filter application failed: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // AUTO CROP
  // ============================================================

  Future<void> _handleAutoCrop() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Auto-crop runs on the background worker isolate, so the UI
      // thread is never blocked (it used to freeze on big photos).
      final outputPath = '${Directory.systemTemp.path}/'
          'auto_crop_${DateTime.now().millisecondsSinceEpoch}_'
          '${identityHashCode(_baseImagePath)}.jpg';

      final croppedPath =
          await ImageProcessingWorker.instance.autoCrop(
        _baseImagePath,
        outputPath,
      );

      final preview =
          await _applyActiveFilterTo(
        croppedPath,
      );

      if (!mounted) return;

      // Discard the previously shown preview file; it is no longer
      // displayed anywhere and would otherwise fill the cache folder.
      _removeStalePreview(_currentWorkingPath);

      setState(() {
        _baseImagePath =
            croppedPath;

        _currentWorkingPath =
            preview;

        _hasUnsavedEdits = true;

        _activeMode =
            EditorMode.none;

        _selectedCropRatio =
            'Free';

        _resetCropCorners();
      });

      await _loadImageSize();

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  'Document automatically cropped',
                ),
              ],
            ),
            backgroundColor:
                AppTheme.primaryColor,
            behavior:
                SnackBarBehavior.floating,
            margin:
                const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(14),
            ),
          ),
        );
      }
    } catch (e) {
      _showError(
        'Auto Crop failed: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // TEXT
  // ============================================================

  Future<void> _handleApplyText() async {
    if (_overlayText.trim().isEmpty) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final newPath =
          await _editorService.addTextOverlay(
        _currentWorkingPath,
        text: _overlayText,
        xPercent: _textXPercent,
        yPercent: _textYPercent,
        color: _textColor,
        fontSize: _textFontSize,
      );

      if (!mounted) return;

      setState(() {
        _currentWorkingPath =
            newPath;

        // Text is burned into the pixels (as it already was before
        // this fix), so it must also become the new base -- otherwise
        // selecting "Original" afterwards would silently erase text
        // the user explicitly committed to the image.
        _baseImagePath =
            newPath;

        _overlayText = '';

        _hasUnsavedEdits = true;

        _activeMode =
            EditorMode.none;
      });
    } catch (e) {
      _showError(
        'Failed to add text: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // APPLY MANUAL CROP
  // ============================================================

  Future<void> _handleApplyCrop() async {
    if (_isProcessing) return;

    if (_imageSize == null) {
      _showError(
        'Image is still loading.',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // SIMPLE CROP:
      // The four UI corners are always kept axis-aligned. We pass the
      // normalized image coordinates to the service, which converts
      // them to integer source-pixel boundaries and performs a direct
      // copyCrop. No perspective transform, interpolation, stretching,
      // padding, or resizing is involved.
      final newBasePath =
          await _editorService.cropImageNormalized(
        _baseImagePath,
        left: _cropTopLeft.dx,
        top: _cropTopLeft.dy,
        right: _cropTopRight.dx,
        bottom: _cropBottomLeft.dy,
      );

      final preview =
          await _applyActiveFilterTo(
        newBasePath,
      );

      if (!mounted) return;

      setState(() {
        _baseImagePath = newBasePath;
        _currentWorkingPath = preview;

        _hasUnsavedEdits = true;

        _activeMode =
            EditorMode.none;

        _selectedCropRatio = 'Free';
        _resetCropCorners();
      });

      await _loadImageSize();
    } catch (e) {
      _showError(
        'Crop failed: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // CROP RATIO
  // ============================================================

  void _selectCropRatio(
    String ratio,
  ) {
    if (_imageSize == null) return;

    setState(() {
      _selectedCropRatio =
          ratio;

      if (ratio == 'Free' ||
          ratio == 'Auto Crop') {
        return;
      }

      final targetRatio =
          _ratioValue(ratio);

      if (targetRatio == null) {
        return;
      }

      _setCropFromRect(
        _createCenteredCropRect(
          targetRatio,
        ),
      );
    });
  }

  double? _ratioValue(
    String ratio,
  ) {
    switch (ratio) {
      case 'Original':
        return _imageSize!.width /
            _imageSize!.height;

      case '1:1':
        return 1.0;

      case '4:3':
        return 4 / 3;

      case '3:4':
        return 3 / 4;

      case '16:9':
        return 16 / 9;

      case '9:16':
        return 9 / 16;

      // A4 = 210 / 297.
      case 'A4 Portrait':
        return 210 / 297;

      // A4 landscape.
      case 'A4 Landscape':
        return 297 / 210;

      // A5 = 148 / 210.
      case 'A5 Portrait':
        return 148 / 210;

      case 'A5 Landscape':
        return 210 / 148;

      // Standard CR80 ID card.
      case 'ID Card':
        return 85.60 / 53.98;

      default:
        return null;
    }
  }

  Rect _createCenteredCropRect(
    double targetRatio,
  ) {
    final imageRatio =
        _imageSize!.width /
            _imageSize!.height;

    double width;
    double height;

    if (imageRatio > targetRatio) {
      height = 0.86;
      width =
          height *
          (_imageSize!.height /
              _imageSize!.width) *
          targetRatio;
    } else {
      width = 0.86;
      height =
          width *
          (_imageSize!.width /
              _imageSize!.height) /
          targetRatio;
    }

    width =
        width.clamp(0.08, 0.94);

    height =
        height.clamp(0.08, 0.94);

    final left =
        ((1 - width) / 2)
            .clamp(0.0, 1.0 - width);

    final top =
        ((1 - height) / 2)
            .clamp(0.0, 1.0 - height);

    return Rect.fromLTWH(
      left,
      top,
      width,
      height,
    );
  }

  // ============================================================
  // CROP DRAG
  // ============================================================

  /// Converts a screen-space drag delta (pixels within the crop
  /// canvas) into a delta in normalized image-fraction space, using
  /// the *actual displayed image rect* (i.e. accounting for the
  /// BoxFit.contain letterboxing), not the raw canvas size. Without
  /// this, dragging on an image whose aspect ratio doesn't match the
  /// canvas would move the corners at the wrong rate / direction.
  Offset _screenDeltaToImageFraction(
    Offset delta,
    Size canvasSize,
  ) {
    final displayedRect =
        _displayedImageRect(canvasSize);

    if (displayedRect.width <= 0 ||
        displayedRect.height <= 0) {
      return Offset.zero;
    }

    return Offset(
      delta.dx / displayedRect.width,
      delta.dy / displayedRect.height,
    );
  }

  void _moveCrop(
    Offset delta,
    Size canvasSize,
  ) {
    final d =
        _screenDeltaToImageFraction(
      delta,
      canvasSize,
    );

    final rect = _cropBoundingRect;

    // Only translate if every corner would remain within [0, 1]
    // after the move, so the whole quad shifts together without
    // ever sliding off the source image.
    final minDx = -rect.left;
    final maxDx = 1.0 - rect.right;
    final minDy = -rect.top;
    final maxDy = 1.0 - rect.bottom;

    final clampedDx =
        d.dx.clamp(minDx, maxDx);
    final clampedDy =
        d.dy.clamp(minDy, maxDy);

    setState(() {
      _cropTopLeft += Offset(clampedDx, clampedDy);
      _cropTopRight += Offset(clampedDx, clampedDy);
      _cropBottomLeft += Offset(clampedDx, clampedDy);
      _cropBottomRight += Offset(clampedDx, clampedDy);
    });
  }

  void _resizeCrop(
    _CropHandle handle,
    Offset delta,
    Size canvasSize,
  ) {
    final d =
        _screenDeltaToImageFraction(
      delta,
      canvasSize,
    );

    final ratio = _ratioValue(_selectedCropRatio);

    if (ratio == null) {
      // FREE MODE is a normal rectangular crop.
      // All four corners remain axis-aligned:
      //
      //   TL -------- TR
      //   |            |
      //   |   CROP     |
      //   |            |
      //   BL -------- BR
      //
      // This is intentionally NOT a perspective/quad crop. Every
      // screen movement is converted through the displayed image rect
      // and ultimately becomes an integer source-pixel boundary.
      final rect = _cropBoundingRect;

      var left = rect.left;
      var top = rect.top;
      var right = rect.right;
      var bottom = rect.bottom;

      switch (handle) {
        case _CropHandle.topLeft:
          left += d.dx;
          top += d.dy;
          break;

        case _CropHandle.topRight:
          right += d.dx;
          top += d.dy;
          break;

        case _CropHandle.bottomLeft:
          left += d.dx;
          bottom += d.dy;
          break;

        case _CropHandle.bottomRight:
          right += d.dx;
          bottom += d.dy;
          break;
      }

      const minSize = 0.01;

      left = left.clamp(0.0, 1.0 - minSize);
      right = right.clamp(minSize, 1.0);
      top = top.clamp(0.0, 1.0 - minSize);
      bottom = bottom.clamp(minSize, 1.0);

      // Preserve the dragged side while guaranteeing a valid rectangle.
      if (right - left < minSize) {
        switch (handle) {
          case _CropHandle.topLeft:
          case _CropHandle.bottomLeft:
            left = right - minSize;
            break;
          case _CropHandle.topRight:
          case _CropHandle.bottomRight:
            right = left + minSize;
            break;
        }
      }

      if (bottom - top < minSize) {
        switch (handle) {
          case _CropHandle.topLeft:
          case _CropHandle.topRight:
            top = bottom - minSize;
            break;
          case _CropHandle.bottomLeft:
          case _CropHandle.bottomRight:
            bottom = top + minSize;
            break;
        }
      }

      left = left.clamp(0.0, 1.0 - minSize);
      right = right.clamp(left + minSize, 1.0);
      top = top.clamp(0.0, 1.0 - minSize);
      bottom = bottom.clamp(top + minSize, 1.0);

      setState(() {
        _setCropFromRect(
          Rect.fromLTRB(left, top, right, bottom),
        );
      });

      return;
    }

    // FIXED RATIO MODE: behave like a classic axis-aligned resize,
    // same feel as before, just re-expressed through the 4 corners.
    final rect = _cropBoundingRect;

    var left = rect.left;
    var top = rect.top;
    var right = rect.right;
    var bottom = rect.bottom;

    switch (handle) {
      case _CropHandle.topLeft:
        left += d.dx;
        top += d.dy;
        break;

      case _CropHandle.topRight:
        right += d.dx;
        top += d.dy;
        break;

      case _CropHandle.bottomLeft:
        left += d.dx;
        bottom += d.dy;
        break;

      case _CropHandle.bottomRight:
        right += d.dx;
        bottom += d.dy;
        break;
    }

    const minSize = 0.08;

    left = left.clamp(0.0, right - minSize);
    right = right.clamp(left + minSize, 1.0);
    top = top.clamp(0.0, bottom - minSize);
    bottom = bottom.clamp(top + minSize, 1.0);

    final newWidth = right - left;
    final newHeight = bottom - top;

    final pixelRatio =
        _imageSize!.width / _imageSize!.height;

    final currentRatio =
        (newWidth * pixelRatio) / newHeight;

    if ((currentRatio - ratio).abs() > 0.001) {
      if (currentRatio > ratio) {
        final correctedWidth =
            newHeight * ratio / pixelRatio;

        if (handle == _CropHandle.topLeft ||
            handle == _CropHandle.bottomLeft) {
          left = right - correctedWidth;
        } else {
          right = left + correctedWidth;
        }
      } else {
        final correctedHeight =
            newWidth * pixelRatio / ratio;

        if (handle == _CropHandle.topLeft ||
            handle == _CropHandle.topRight) {
          top = bottom - correctedHeight;
        } else {
          bottom = top + correctedHeight;
        }
      }
    }

    left = left.clamp(0.0, 0.92);
    top = top.clamp(0.0, 0.92);
    right = right.clamp(left + minSize, 1.0);
    bottom = bottom.clamp(top + minSize, 1.0);

    setState(() {
      _setCropFromRect(
        Rect.fromLTRB(left, top, right, bottom),
      );
    });
  }

  static const double _minCornerGap = 0.08;

  Offset _clampCorner(
    Offset corner, {
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
  }) {
    // Guard against inverted bounds (which would otherwise throw)
    // when two corners have been dragged very close together.
    final safeMaxX = math.max(minX, maxX);
    final safeMaxY = math.max(minY, maxY);

    return Offset(
      corner.dx.clamp(minX, safeMaxX),
      corner.dy.clamp(minY, safeMaxY),
    );
  }

  /// The rect (in canvas-local pixels) where the image is actually
  /// drawn, given BoxFit.contain letterboxing. Returns the full
  /// canvas as a fallback if the image size isn't known yet.
  Rect _displayedImageRect(Size canvasSize) {
    final imageSize = _imageSize;

    if (imageSize == null ||
        imageSize.width <= 0 ||
        imageSize.height <= 0) {
      return Offset.zero & canvasSize;
    }

    final canvasRatio =
        canvasSize.width / canvasSize.height;

    final imageRatio =
        imageSize.width / imageSize.height;

    double width;
    double height;

    if (imageRatio > canvasRatio) {
      // Image is relatively wider: letterboxed top/bottom.
      width = canvasSize.width;
      height = width / imageRatio;
    } else {
      // Image is relatively taller: letterboxed left/right.
      height = canvasSize.height;
      width = height * imageRatio;
    }

    final left = (canvasSize.width - width) / 2;
    final top = (canvasSize.height - height) / 2;

    return Rect.fromLTWH(left, top, width, height);
  }

  // ============================================================
  // SAVE
  // ============================================================

  void _saveAndExit() {
    if (_hasUnsavedEdits) {
      context
          .read<ImageSelectionProvider>()
          .updateImageFilePath(
            widget.imageId,
            _currentWorkingPath,
          );
    }

    Navigator.of(context)
        .pop(_currentWorkingPath);
  }

  // ============================================================
  // BACK / CANCEL
  // ============================================================

  Future<void> _handleCancelOrBack() async {
    if (!_hasUnsavedEdits) {
      Navigator.of(context).pop();
      return;
    }

    final result =
        await UnsavedChangesDialog.show(
      context,
      title: 'Discard Image Edits?',
      message:
          'You have unapplied edits on this page. What would you like to do?',
      saveLabel: 'Apply Changes',
      discardLabel: 'Discard',
    );

    if (!mounted) return;

    if (result ==
        UnsavedChangesAction.save) {
      _saveAndExit();
    } else if (result ==
        UnsavedChangesAction.discard) {
      Navigator.of(context).pop();
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            AppTheme.errorColor,
        behavior:
            SnackBarBehavior.floating,
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ============================================================
  // TEXT DIALOG
  // ============================================================

  void _openTextDialog() {
    final textController =
        TextEditingController(
      text: _overlayText,
    );

    Color selectedColor =
        _textColor;

    showDialog(
      context: context,
      builder: (ctx) {
        final theme =
            Theme.of(ctx);

        final colors =
            theme.colorScheme;

        return StatefulBuilder(
          builder:
              (context, setDialogState) {
            return AlertDialog(
              backgroundColor:
                  colors.surface,
              surfaceTintColor:
                  Colors.transparent,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),
              title:
                  const Text(
                'Add Text',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                  TextField(
                    controller:
                        textController,
                    autofocus:
                        true,
                    maxLines: 3,
                    decoration:
                        InputDecoration(
                      hintText:
                          'Enter text...',
                      filled: true,
                      fillColor:
                          theme.brightness ==
                                  Brightness.dark
                              ? AppTheme
                                  .cardDark
                              : AppTheme
                                  .bgLight,
                      prefixIcon:
                          const Icon(
                        Icons
                            .text_fields_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Align(
                    alignment:
                        Alignment
                            .centerLeft,
                    child:
                        Text(
                      'Text Color',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight
                                .w700,
                        color:
                            colors
                                .onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Colors.black,
                      Colors.white,
                      AppTheme
                          .primaryColor,
                      Colors.red,
                      Colors.blue,
                      Colors.green,
                    ].map((c) {
                      final isSelected =
                          selectedColor ==
                              c;

                      return GestureDetector(
                        onTap: () {
                          setDialogState(
                            () {
                              selectedColor =
                                  c;
                            },
                          );
                        },
                        child:
                            AnimatedContainer(
                          duration:
                              const Duration(
                            milliseconds:
                                180,
                          ),
                          width: 38,
                          height: 38,
                          decoration:
                              BoxDecoration(
                            color: c,
                            shape:
                                BoxShape
                                    .circle,
                            border:
                                Border.all(
                              color:
                                  isSelected
                                      ? AppTheme
                                          .primaryColor
                                      : colors
                                          .outline
                                          .withValues(
                                          alpha:
                                              0.35,
                                        ),
                              width:
                                  isSelected
                                      ? 3
                                      : 1,
                            ),
                          ),
                          child:
                              isSelected
                                  ? Icon(
                                      Icons
                                          .check_rounded,
                                      size:
                                          20,
                                      color: c ==
                                              Colors
                                                  .white
                                          ? Colors
                                              .black
                                          : Colors
                                              .white,
                                    )
                                  : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
              actionsPadding:
                  const EdgeInsets.fromLTRB(
                20,
                0,
                20,
                16,
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(
                    ctx,
                  ).pop(),
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (textController
                        .text
                        .trim()
                        .isNotEmpty) {
                      setState(() {
                        _overlayText =
                            textController
                                .text
                                .trim();

                        _textColor =
                            selectedColor;

                        _activeMode =
                            EditorMode
                                .text;
                      });
                    }

                    Navigator.of(
                      ctx,
                    ).pop();
                  },
                  icon:
                      const Icon(
                    Icons
                        .check_rounded,
                    size: 19,
                  ),
                  label:
                      const Text(
                    'Add Text',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    final isDark =
        theme.brightness ==
            Brightness.dark;

    final backgroundColor =
        isDark
            ? AppTheme.bgDark
            : AppTheme.bgLight;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult:
          (didPop, result) {
        if (!didPop) {
          _handleCancelOrBack();
        }
      },
      child: Scaffold(
        backgroundColor:
            backgroundColor,
        appBar: AppBar(
          backgroundColor:
              backgroundColor,
          foregroundColor:
              colorScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading:
              Padding(
            padding:
                const EdgeInsets.only(
              left: 12,
              top: 6,
              bottom: 6,
            ),
            child:
                _buildTopButton(
              icon:
                  Icons.close_rounded,
              onTap:
                  _handleCancelOrBack,
            ),
          ),
          titleSpacing: 12,
          title:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                'Image Editor',
                style:
                    TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      colorScheme
                          .onSurface,
                ),
              ),
              const SizedBox(
                height: 2,
              ),
              Text(
                'Edit Page ${widget.pageIndex + 1}',
                style:
                    TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w500,
                  color:
                      colorScheme
                          .onSurface
                          .withValues(
                    alpha: 0.55,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding:
                  const EdgeInsets.only(
                right: 14,
              ),
              child:
                  GestureDetector(
                onTap:
                    _saveAndExit,
                child:
                    Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration:
                      BoxDecoration(
                    color: AppTheme
                        .primaryColor,
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                  ),
                  child:
                      const Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        Icons
                            .check_rounded,
                        color:
                            Colors.white,
                        size: 18,
                      ),
                      SizedBox(
                        width: 5,
                      ),
                      Text(
                        'Done',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontWeight:
                              FontWeight
                                  .w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child:
                      Padding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      16,
                      8,
                      16,
                      12,
                    ),
                    child:
                        Container(
                      width:
                          double.infinity,
                      decoration:
                          BoxDecoration(
                        color: isDark
                            ? AppTheme
                                .cardDark
                            : Colors.white,
                        borderRadius:
                            BorderRadius
                                .circular(
                          26,
                        ),
                        border:
                            Border.all(
                          color: isDark
                              ? AppTheme
                                  .dividerDark
                              : AppTheme
                                  .dividerColor,
                        ),
                      ),
                      child:
                          ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          25,
                        ),
                        child:
                            _buildImageArea(
                          isDark,
                        ),
                      ),
                    ),
                  ),
                ),
                _buildBottomEditorPanel(
                  isDark,
                  colorScheme,
                ),
              ],
            ),
            if (_isProcessing)
              Positioned.fill(
                child:
                    Container(
                  color: Colors.black
                      .withValues(
                    alpha: 0.45,
                  ),
                  child:
                      Center(
                    child:
                        Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      decoration:
                          BoxDecoration(
                        color: isDark
                            ? AppTheme
                                .cardDark
                            : Colors.white,
                        borderRadius:
                            BorderRadius
                                .circular(
                          20,
                        ),
                      ),
                      child:
                          Column(
                        mainAxisSize:
                            MainAxisSize
                                .min,
                        children: [
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppTheme
                                  .primaryColor,
                            ),
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          Text(
                            'Processing...',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w700,
                              color:
                                  colorScheme
                                      .onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE AREA
  // ============================================================

  Widget _buildImageArea(
    bool isDark,
  ) {
    if (_activeMode ==
        EditorMode.crop) {
      return _buildCropArea(
        isDark,
      );
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      boundaryMargin:
          const EdgeInsets.all(40),
      child: Center(
        child: Stack(
          alignment:
              Alignment.center,
          children: [
            Image.file(
              File(
                _currentWorkingPath,
              ),
              fit: BoxFit.contain,
              key: ValueKey(
                _currentWorkingPath,
              ),
            ),
            if (_activeMode ==
                    EditorMode.text &&
                _overlayText
                    .isNotEmpty)
              Positioned(
                left:
                    MediaQuery.of(
                          context,
                        ).size.width *
                        (_textXPercent -
                            0.1),
                top:
                    MediaQuery.of(
                          context,
                        ).size.height *
                        (_textYPercent -
                            0.15),
                child:
                    GestureDetector(
                  onPanUpdate:
                      (details) {
                    setState(() {
                      _textXPercent =
                          (_textXPercent +
                                  details
                                      .delta
                                      .dx /
                                      300)
                              .clamp(
                        0.05,
                        0.95,
                      );

                      _textYPercent =
                          (_textYPercent +
                                  details
                                      .delta
                                      .dy /
                                      500)
                              .clamp(
                        0.05,
                        0.95,
                      );
                    });
                  },
                  child:
                      Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.black
                          .withValues(
                        alpha: 0.58,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                      border:
                          Border.all(
                        color: Colors
                            .white
                            .withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    child:
                        Text(
                      _overlayText,
                      style:
                          TextStyle(
                        color:
                            _textColor,
                        fontSize:
                            _textFontSize
                                .toDouble(),
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CROP AREA
  // ============================================================

  Widget _buildCropArea(
    bool isDark,
  ) {
    return LayoutBuilder(
      builder:
          (context, constraints) {
        final size =
            Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(
                _currentWorkingPath,
              ),
              fit: BoxFit.contain,
              key: ValueKey(
                _currentWorkingPath,
              ),
            ),

            Container(
              color: Colors.black
                  .withValues(
                alpha: 0.48,
              ),
            ),

            Positioned.fill(
              child:
                  GestureDetector(
                onPanUpdate:
                    (details) {
                  _moveCrop(
                    details.delta,
                    size,
                  );
                },
                child:
                    CustomPaint(
                  painter:
                      _CropPainter(
                    topLeft: _cropTopLeft,
                    topRight: _cropTopRight,
                    bottomLeft: _cropBottomLeft,
                    bottomRight: _cropBottomRight,
                    displayedImageRect:
                        _displayedImageRect(size),
                    primaryColor:
                        AppTheme
                            .primaryColor,
                  ),
                ),
              ),
            ),

            _buildCropHandleWidget(
              _CropHandle.topLeft,
              size,
            ),

            _buildCropHandleWidget(
              _CropHandle.topRight,
              size,
            ),

            _buildCropHandleWidget(
              _CropHandle.bottomLeft,
              size,
            ),

            _buildCropHandleWidget(
              _CropHandle.bottomRight,
              size,
            ),

            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child:
                  Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.black
                          .withValues(
                        alpha: 0.60,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                    child:
                        Text(
                      _selectedCropRatio,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_selectedCropRatio ==
                      'Free')
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.black
                            .withValues(
                          alpha: 0.60,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                      child:
                          const Text(
                        'Drag corners',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontWeight:
                              FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCropHandleWidget(
    _CropHandle handle,
    Size size,
  ) {
    final displayedRect =
        _displayedImageRect(size);

    Offset corner;

    switch (handle) {
      case _CropHandle.topLeft:
        corner = _cropTopLeft;
        break;
      case _CropHandle.topRight:
        corner = _cropTopRight;
        break;
      case _CropHandle.bottomLeft:
        corner = _cropBottomLeft;
        break;
      case _CropHandle.bottomRight:
        corner = _cropBottomRight;
        break;
    }

    final left =
        displayedRect.left +
            corner.dx * displayedRect.width;

    final top =
        displayedRect.top +
            corner.dy * displayedRect.height;

    return Positioned(
      left: left - 17,
      top: top - 17,
      child:
          GestureDetector(
        behavior:
            HitTestBehavior.opaque,
        onPanUpdate:
            (details) {
          _resizeCrop(
            handle,
            details.delta,
            size,
          );
        },
        child:
            Container(
          width: 34,
          height: 34,
          decoration:
              BoxDecoration(
            color: Colors.white,
            shape:
                BoxShape.circle,
            border:
                Border.all(
              color: AppTheme
                  .primaryColor,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha: 0.30,
                ),
                blurRadius: 8,
              ),
            ],
          ),
          child:
              Icon(
            Icons
                .open_in_full_rounded,
            size: 16,
            color: AppTheme
                .primaryColor,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP BUTTON
  // ============================================================

  Widget _buildTopButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark =
        Theme.of(context)
                .brightness ==
            Brightness.dark;

    return Material(
      color:
          Colors.transparent,
      child:
          InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        child:
            Container(
          width: 42,
          height: 42,
          decoration:
              BoxDecoration(
            color: isDark
                ? AppTheme.cardDark
                : Colors.white,
            borderRadius:
                BorderRadius.circular(
              13,
            ),
            border:
                Border.all(
              color: isDark
                  ? AppTheme
                      .dividerDark
                  : AppTheme
                      .dividerColor,
            ),
          ),
          child:
              Icon(
            icon,
            size: 22,
            color:
                Theme.of(context)
                    .colorScheme
                    .onSurface,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM EDITOR PANEL
  // ============================================================

  Widget _buildBottomEditorPanel(
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Container(
      width:
          double.infinity,
      decoration:
          BoxDecoration(
        color: isDark
            ? AppTheme.surfaceDark
            : Colors.white,
        borderRadius:
            const BorderRadius
                .vertical(
          top:
              Radius.circular(28),
        ),
        border:
            Border(
          top:
              BorderSide(
            color: isDark
                ? AppTheme
                    .dividerDark
                : AppTheme
                    .dividerColor,
          ),
        ),
      ),
      child:
          SafeArea(
        top: false,
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            if (_activeMode ==
                EditorMode.rotate)
              _buildRotateControls(
                isDark,
              ),
            if (_activeMode ==
                EditorMode.crop)
              _buildCropControls(
                isDark,
              ),
            if (_activeMode ==
                EditorMode.filters)
              _buildFilterControls(
                isDark,
              ),
            if (_activeMode ==
                    EditorMode.text &&
                _overlayText
                    .isNotEmpty)
              _buildTextControls(
                isDark,
              ),
            Container(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              child:
                  Row(
                children: [
                  Expanded(
                    child:
                        _buildToolItem(
                      icon: Icons
                          .crop_rounded,
                      label: 'Crop',
                      mode:
                          EditorMode.crop,
                    ),
                  ),
                  Expanded(
                    child:
                        _buildToolItem(
                      icon: Icons
                          .rotate_right_rounded,
                      label: 'Rotate',
                      mode:
                          EditorMode.rotate,
                    ),
                  ),
                  Expanded(
                    child:
                        _buildToolItem(
                      icon: Icons
                          .text_fields_rounded,
                      label: 'Text',
                      mode:
                          EditorMode.text,
                      onTap:
                          _openTextDialog,
                    ),
                  ),
                  Expanded(
                    child:
                        _buildToolItem(
                      icon: Icons
                          .auto_awesome_rounded,
                      label: 'Filters',
                      mode:
                          EditorMode.filters,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOOL ITEM
  // ============================================================

  Widget _buildToolItem({
    required IconData icon,
    required String label,
    required EditorMode mode,
    VoidCallback? onTap,
  }) {
    final isSelected =
        _activeMode == mode;

    final isDark =
        Theme.of(context)
                .brightness ==
            Brightness.dark;

    final colorScheme =
        Theme.of(context)
            .colorScheme;

    return GestureDetector(
      onTap: onTap ??
          () {
            setState(() {
              _activeMode =
                  isSelected
                      ? EditorMode.none
                      : mode;

              if (mode ==
                  EditorMode.crop) {
                _selectedCropRatio =
                    'Free';

                _resetCropCorners();
              }
            });
          },
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        margin:
            const EdgeInsets
                .symmetric(
          horizontal: 4,
        ),
        padding:
            const EdgeInsets
                .symmetric(
          vertical: 9,
        ),
        decoration:
            BoxDecoration(
          color: isSelected
              ? isDark
                  ? const Color(
                      0xFF211A4A,
                    )
                  : const Color(
                      0xFFEDE7FF,
                    )
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(
            16,
          ),
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                color: isSelected
                    ? AppTheme
                        .primaryColor
                    : isDark
                        ? AppTheme
                            .cardDark
                        : AppTheme
                            .bgLight,
                shape:
                    BoxShape.circle,
              ),
              child:
                  Icon(
                icon,
                size: 21,
                color: isSelected
                    ? Colors.white
                    : colorScheme
                        .onSurface
                        .withValues(
                      alpha: 0.65,
                    ),
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            Text(
              label,
              style:
                  TextStyle(
                fontSize: 11,
                fontWeight:
                    isSelected
                        ? FontWeight
                            .w800
                        : FontWeight
                            .w600,
                color: isSelected
                    ? AppTheme
                        .primaryColor
                    : colorScheme
                        .onSurface
                        .withValues(
                      alpha: 0.65,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ROTATE CONTROLS
  // ============================================================

  Widget _buildRotateControls(
    bool isDark,
  ) {
    return _buildSubPanel(
      isDark: isDark,
      child:
          Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceEvenly,
        children: [
          _buildActionButton(
            icon:
                Icons
                    .rotate_left_rounded,
            label: 'Left',
            onTap: () =>
                _handleRotate(
              270,
            ),
          ),
          _buildActionButton(
            icon:
                Icons
                    .rotate_right_rounded,
            label: 'Right',
            onTap: () =>
                _handleRotate(
              90,
            ),
          ),
          _buildActionButton(
            icon:
                Icons.flip_rounded,
            label: 'Flip H',
            onTap: () =>
                _handleFlip(
              horizontal: true,
            ),
          ),
          _buildActionButton(
            icon:
                Icons
                    .swap_vert_rounded,
            label: 'Flip V',
            onTap: () =>
                _handleFlip(
              horizontal: false,
              vertical: true,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CROP CONTROLS
  // ============================================================

  Widget _buildCropControls(
    bool isDark,
  ) {
    final ratios = [
      'Free',
      'Original',
      '1:1',
      '4:3',
      '3:4',
      '16:9',
      '9:16',
      'A4 Portrait',
      'A4 Landscape',
      'A5 Portrait',
      'A5 Landscape',
      'ID Card',
    ];

    return _buildSubPanel(
      isDark: isDark,
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Row(
            children: [
              const Icon(
                Icons
                    .crop_rounded,
                size: 19,
                color: AppTheme
                    .primaryColor,
              ),
              const SizedBox(
                width: 7,
              ),
              Text(
                'Crop Ratio',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight
                          .w800,
                  color:
                      Theme.of(
                    context,
                  )
                          .colorScheme
                          .onSurface,
                ),
              ),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: OutlinedButton.icon(
                    onPressed:
                        _handleAutoCrop,
                    icon:
                        const Icon(
                      Icons
                          .auto_awesome_rounded,
                      size: 17,
                    ),
                    label:
                        const Text(
                      'Auto Crop',
                    ),
                    style:
                        OutlinedButton
                            .styleFrom(
                      foregroundColor:
                          AppTheme
                              .primaryColor,
                      side:
                          const BorderSide(
                        color: AppTheme
                            .primaryColor,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          SingleChildScrollView(
            scrollDirection:
                Axis.horizontal,
            physics:
                const BouncingScrollPhysics(),
            child:
                Row(
              children:
                  ratios.map(
                (ratio) {
                  final selected =
                      _selectedCropRatio ==
                          ratio;

                  return Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      right: 8,
                    ),
                    child:
                        ChoiceChip(
                      label:
                          Text(
                        ratio,
                        style:
                            TextStyle(
                          fontSize:
                              11,
                          fontWeight:
                              FontWeight
                                  .w700,
                          color:
                              selected
                                  ? Colors
                                      .white
                                  : Theme.of(
                                      context,
                                    )
                                      .colorScheme
                                      .onSurface,
                        ),
                      ),
                      selected:
                          selected,
                      selectedColor:
                          AppTheme
                              .primaryColor,
                      backgroundColor:
                          isDark
                              ? AppTheme
                                  .cardDark
                              : AppTheme
                                  .bgLight,
                      onSelected:
                          (value) {
                        if (value) {
                          _selectCropRatio(
                            ratio,
                          );
                        }
                      },
                    ),
                  );
                },
              ).toList(),
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Row(
            children: [
              Expanded(
                child:
                    OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _activeMode =
                          EditorMode
                              .none;
                    });
                  },
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _handleApplyCrop,
                  icon:
                      const Icon(
                    Icons
                        .check_rounded,
                    size: 18,
                  ),
                  label:
                      const Text(
                    'Apply Crop',
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 12,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER CONTROLS
  // ============================================================

  Widget _buildFilterControls(
    bool isDark,
  ) {
    return _buildSubPanel(
      isDark: isDark,
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Row(
            children: [
              const Icon(
                Icons
                    .auto_awesome_rounded,
                size: 19,
                color: AppTheme
                    .primaryColor,
              ),
              const SizedBox(
                width: 7,
              ),
              Text(
                'Choose Filter',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight
                          .w800,
                  color:
                      Theme.of(
                    context,
                  )
                          .colorScheme
                          .onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          SingleChildScrollView(
            scrollDirection:
                Axis.horizontal,
            physics:
                const BouncingScrollPhysics(),
            child:
                Row(
              children:
                  ImageFilterType
                      .values
                      .map(
                (filter) {
                  return Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      right: 8,
                    ),
                    child:
                        _filterButton(
                      ImageEditorService
                          .label(
                        filter,
                      ),
                      filter,
                      isDark,
                    ),
                  );
                },
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(
    String label,
    ImageFilterType type,
    bool isDark,
  ) {
    final selected =
        _activeFilter == type;

    return GestureDetector(
      onTap: () =>
          _handleFilter(
        type,
      ),
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),
        padding:
            const EdgeInsets
                .symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? AppTheme
                  .primaryColor
              : isDark
                  ? AppTheme
                      .cardDark
                  : AppTheme
                      .bgLight,
          borderRadius:
              BorderRadius.circular(
            13,
          ),
          border:
              Border.all(
            color: selected
                ? AppTheme
                    .primaryColor
                : Theme.of(
                    context,
                  )
                    .colorScheme
                    .outline
                    .withValues(
                    alpha: 0.16,
                  ),
          ),
        ),
        child:
            Text(
          label,
          style:
              TextStyle(
            fontSize: 12,
            fontWeight:
                FontWeight.w700,
            color: selected
                ? Colors.white
                : Theme.of(
                    context,
                  )
                    .colorScheme
                    .onSurface,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TEXT CONTROLS
  // ============================================================

  Widget _buildTextControls(
    bool isDark,
  ) {
    return _buildSubPanel(
      isDark: isDark,
      child:
          Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color: AppTheme
                  .primaryColor
                  .withValues(
                alpha: 0.12,
              ),
              shape:
                  BoxShape.circle,
            ),
            child:
                const Icon(
              Icons
                  .touch_app_rounded,
              color: AppTheme
                  .primaryColor,
              size: 21,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child:
                Text(
              'Drag the text to position it',
              style:
                  TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight
                        .w600,
                color:
                    Theme.of(
                  context,
                )
                        .colorScheme
                        .onSurface
                        .withValues(
                  alpha: 0.65,
                ),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed:
                _handleApplyText,
            icon:
                const Icon(
              Icons
                  .check_rounded,
              size: 18,
            ),
            label:
                const Text(
              'Apply',
            ),
            style:
                ElevatedButton
                    .styleFrom(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUB PANEL
  // ============================================================

  Widget _buildSubPanel({
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      width:
          double.infinity,
      margin:
          const EdgeInsets
              .fromLTRB(
        12,
        10,
        12,
        2,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color: isDark
            ? AppTheme.cardDark
            : AppTheme.bgLight,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color: isDark
              ? AppTheme
                  .dividerDark
              : AppTheme
                  .dividerColor,
        ),
      ),
      child: child,
    );
  }

  // ============================================================
  // ACTION BUTTON
  // ============================================================

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark =
        Theme.of(context)
                .brightness ==
            Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child:
          Container(
        width: 68,
        padding:
            const EdgeInsets
                .symmetric(
          vertical: 7,
        ),
        decoration:
            BoxDecoration(
          color: isDark
              ? AppTheme.surfaceDark
              : Colors.white,
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          border:
              Border.all(
            color: isDark
                ? AppTheme
                    .dividerDark
                : AppTheme
                    .dividerColor,
          ),
        ),
        child:
            Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(
                color: AppTheme
                    .primaryColor
                    .withValues(
                  alpha: 0.10,
                ),
                shape:
                    BoxShape.circle,
              ),
              child:
                  Icon(
                icon,
                color: AppTheme
                    .primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              label,
              style:
                  const TextStyle(
                fontSize: 10,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// CROP HANDLE
// ================================================================

enum _CropHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

// ================================================================
// CROP PAINTER
// ================================================================

class _CropPainter
    extends CustomPainter {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomLeft;
  final Offset bottomRight;

  /// The rect (in this painter's local canvas space) where the
  /// image is actually drawn, so the quad lines up with the image
  /// even when it's letterboxed by BoxFit.contain.
  final Rect displayedImageRect;

  final Color primaryColor;

  const _CropPainter({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.displayedImageRect,
    required this.primaryColor,
  });

  Offset _toCanvas(Offset normalized) {
    return Offset(
      displayedImageRect.left +
          normalized.dx * displayedImageRect.width,
      displayedImageRect.top +
          normalized.dy * displayedImageRect.height,
    );
  }

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final pTopLeft = _toCanvas(topLeft);
    final pTopRight = _toCanvas(topRight);
    final pBottomLeft = _toCanvas(bottomLeft);
    final pBottomRight = _toCanvas(bottomRight);

    final quad = Path()
      ..moveTo(pTopLeft.dx, pTopLeft.dy)
      ..lineTo(pTopRight.dx, pTopRight.dy)
      ..lineTo(pBottomRight.dx, pBottomRight.dy)
      ..lineTo(pBottomLeft.dx, pBottomLeft.dy)
      ..close();

    final overlayPaint =
        Paint()
          ..color = Colors.black
              .withValues(
            alpha: 0.35,
          );

    final full =
        Path()
          ..addRect(
            Offset.zero &
                size,
          );

    final outside =
        Path.combine(
      PathOperation
          .difference,
      full,
      quad,
    );

    canvas.drawPath(
      outside,
      overlayPaint,
    );

    final borderPaint =
        Paint()
          ..color =
              primaryColor
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 2.5;

    canvas.drawPath(
      quad,
      borderPaint,
    );

    // Third-line guides, interpolated along the quad's edges so they
    // stay correct even when the quad is skewed (not just an
    // axis-aligned rectangle).
    final guidePaint =
        Paint()
          ..color = Colors.white
              .withValues(
            alpha: 0.35,
          )
          ..strokeWidth = 1;

    Offset lerp(Offset a, Offset b, double t) =>
        Offset.lerp(a, b, t)!;

    for (var i = 1; i <= 2; i++) {
      final t = i / 3;

      // Vertical-ish guide line: between a point on the top edge
      // and the corresponding point on the bottom edge.
      final topPoint = lerp(pTopLeft, pTopRight, t);
      final bottomPoint = lerp(pBottomLeft, pBottomRight, t);

      canvas.drawLine(topPoint, bottomPoint, guidePaint);

      // Horizontal-ish guide line: between a point on the left edge
      // and the corresponding point on the right edge.
      final leftPoint = lerp(pTopLeft, pBottomLeft, t);
      final rightPoint = lerp(pTopRight, pBottomRight, t);

      canvas.drawLine(leftPoint, rightPoint, guidePaint);
    }

    // Corner accents so a skewed quad still reads clearly as
    // "these four points are the document corners".
    final cornerPaint =
        Paint()
          ..color = primaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;

    const cornerLen = 16.0;

    void drawCornerMark(Offset p, Offset toA, Offset toB) {
      final dirA = (toA - p);
      final dirB = (toB - p);

      final lenA = dirA.distance;
      final lenB = dirB.distance;

      if (lenA == 0 || lenB == 0) return;

      final unitA = dirA / lenA;
      final unitB = dirB / lenB;

      canvas.drawLine(p, p + unitA * cornerLen, cornerPaint);
      canvas.drawLine(p, p + unitB * cornerLen, cornerPaint);
    }

    drawCornerMark(pTopLeft, pTopRight, pBottomLeft);
    drawCornerMark(pTopRight, pTopLeft, pBottomRight);
    drawCornerMark(pBottomLeft, pTopLeft, pBottomRight);
    drawCornerMark(pBottomRight, pTopRight, pBottomLeft);
  }

  @override
  bool shouldRepaint(
    covariant _CropPainter oldDelegate,
  ) {
    return oldDelegate.topLeft != topLeft ||
        oldDelegate.topRight != topRight ||
        oldDelegate.bottomLeft != bottomLeft ||
        oldDelegate.bottomRight != bottomRight ||
        oldDelegate.displayedImageRect != displayedImageRect ||
        oldDelegate.primaryColor != primaryColor;
  }
}
 
