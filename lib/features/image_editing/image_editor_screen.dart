 import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/image_selection_provider.dart';
import '../../core/services/image_editor_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/unsaved_changes_dialog.dart';
import '../../core/services/scan_filter_service.dart';

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

  bool _isProcessing = false;
  bool _hasUnsavedEdits = false;

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

  // Normalized crop rectangle.
  // x/y/width/height are 0.0 -> 1.0.
  Rect _cropRect = const Rect.fromLTWH(
    0.08,
    0.08,
    0.84,
    0.84,
  );

  Size? _imageSize;

  // ============================================================
  // FILTER
  // ============================================================

  ImageFilterType _activeFilter =
      ImageFilterType.none;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _currentWorkingPath =
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
      final newPath =
          await _editorService.rotateImage(
        _currentWorkingPath,
        degrees,
      );

      if (!mounted) return;

      setState(() {
        _currentWorkingPath = newPath;
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
      final newPath =
          await _editorService.flipImage(
        _currentWorkingPath,
        horizontal: horizontal,
        vertical: vertical,
      );

      if (!mounted) return;

      setState(() {
        _currentWorkingPath = newPath;
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
      setState(() {
        _activeFilter =
            ImageFilterType.none;
      });
      return;
    }

    if (_activeFilter == filter) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final newPath =
          await _editorService.applyFilter(
        _currentWorkingPath,
        filter,
      );

      if (!mounted) return;

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
      final file =
          File(_currentWorkingPath);

      final bytes =
          await file.readAsBytes();

      final croppedBytes = ScanFilterService.autoCrop(bytes);

      final tempFile =
          await _writeAutoCropFile(
        croppedBytes,
      );

      if (!mounted) return;

      setState(() {
        _currentWorkingPath =
            tempFile.path;

        _hasUnsavedEdits = true;

        _activeMode =
            EditorMode.none;

        _selectedCropRatio =
            'Free';

        _cropRect =
            const Rect.fromLTWH(
          0.08,
          0.08,
          0.84,
          0.84,
        );
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

  Future<File> _writeAutoCropFile(
    List<int> bytes,
  ) async {
    final directory =
        Directory.systemTemp;

    final file = File(
      '${directory.path}/auto_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    await file.writeAsBytes(
      bytes,
      flush: true,
    );

    return file;
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
      final imageWidth =
          _imageSize!.width;

      final imageHeight =
          _imageSize!.height;

      final x =
          (_cropRect.left *
                  imageWidth)
              .round();

      final y =
          (_cropRect.top *
                  imageHeight)
              .round();

      final width =
          (_cropRect.width *
                  imageWidth)
              .round();

      final height =
          (_cropRect.height *
                  imageHeight)
              .round();

      final safeX =
          x.clamp(
        0,
        imageWidth.toInt() - 1,
      );

      final safeY =
          y.clamp(
        0,
        imageHeight.toInt() - 1,
      );

      final safeWidth =
          width.clamp(
        1,
        imageWidth.toInt() - safeX,
      );

      final safeHeight =
          height.clamp(
        1,
        imageHeight.toInt() - safeY,
      );

      final newPath =
          await _editorService.cropImage(
        _currentWorkingPath,
        x: safeX,
        y: safeY,
        width: safeWidth,
        height: safeHeight,
      );

      if (!mounted) return;

      setState(() {
        _currentWorkingPath =
            newPath;

        _hasUnsavedEdits = true;

        _activeMode =
            EditorMode.none;
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

      _cropRect =
          _createCenteredCropRect(
        targetRatio,
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

  void _moveCrop(
    Offset delta,
    Size canvasSize,
  ) {
    final dx =
        delta.dx /
            canvasSize.width;

    final dy =
        delta.dy /
            canvasSize.height;

    var left =
        _cropRect.left + dx;

    var top =
        _cropRect.top + dy;

    left =
        left.clamp(
      0.0,
      1.0 - _cropRect.width,
    );

    top =
        top.clamp(
      0.0,
      1.0 - _cropRect.height,
    );

    setState(() {
      _cropRect =
          Rect.fromLTWH(
        left,
        top,
        _cropRect.width,
        _cropRect.height,
      );
    });
  }

  void _resizeCrop(
    _CropHandle handle,
    Offset delta,
    Size canvasSize,
  ) {
    final dx =
        delta.dx /
            canvasSize.width;

    final dy =
        delta.dy /
            canvasSize.height;

    var left =
        _cropRect.left;

    var top =
        _cropRect.top;

    var right =
        _cropRect.right;

    var bottom =
        _cropRect.bottom;

    switch (handle) {
      case _CropHandle.topLeft:
        left += dx;
        top += dy;
        break;

      case _CropHandle.topRight:
        right += dx;
        top += dy;
        break;

      case _CropHandle.bottomLeft:
        left += dx;
        bottom += dy;
        break;

      case _CropHandle.bottomRight:
        right += dx;
        bottom += dy;
        break;
    }

    const minSize = 0.08;

    left =
        left.clamp(
      0.0,
      right - minSize,
    );

    right =
        right.clamp(
      left + minSize,
      1.0,
    );

    top =
        top.clamp(
      0.0,
      bottom - minSize,
    );

    bottom =
        bottom.clamp(
      top + minSize,
      1.0,
    );

    // Keep fixed aspect ratio for all ratio modes.
    final ratio =
        _ratioValue(
      _selectedCropRatio,
    );

    if (ratio != null) {
      final newWidth =
          right - left;

      final newHeight =
          bottom - top;

      final pixelRatio =
          _imageSize!.width /
              _imageSize!.height;

      final currentRatio =
          (newWidth * pixelRatio) /
              newHeight;

      if ((currentRatio - ratio)
              .abs() >
          0.001) {
        if (currentRatio > ratio) {
          final correctedWidth =
              newHeight *
                  ratio /
                  pixelRatio;

          if (handle ==
                  _CropHandle.topLeft ||
              handle ==
                  _CropHandle.bottomLeft) {
            left =
                right -
                    correctedWidth;
          } else {
            right =
                left +
                    correctedWidth;
          }
        } else {
          final correctedHeight =
              newWidth *
                  pixelRatio /
                  ratio;

          if (handle ==
                  _CropHandle.topLeft ||
              handle ==
                  _CropHandle.topRight) {
            top =
                bottom -
                    correctedHeight;
          } else {
            bottom =
                top +
                    correctedHeight;
          }
        }
      }
    }

    left =
        left.clamp(0.0, 0.92);

    top =
        top.clamp(0.0, 0.92);

    right =
        right.clamp(
      left + minSize,
      1.0,
    );

    bottom =
        bottom.clamp(
      top + minSize,
      1.0,
    );

    setState(() {
      _cropRect =
          Rect.fromLTRB(
        left,
        top,
        right,
        bottom,
      );
    });
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
                  Column(
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
                    cropRect:
                        _cropRect,
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
    double left =
        _cropRect.left *
            size.width;

    double top =
        _cropRect.top *
            size.height;

    if (handle ==
        _CropHandle.topRight) {
      left =
          _cropRect.right *
              size.width;
    }

    if (handle ==
        _CropHandle.bottomLeft) {
      top =
          _cropRect.bottom *
              size.height;
    }

    if (handle ==
        _CropHandle.bottomRight) {
      left =
          _cropRect.right *
              size.width;

      top =
          _cropRect.bottom *
              size.height;
    }

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

                _cropRect =
                    const Rect.fromLTWH(
                  0.08,
                  0.08,
                  0.84,
                  0.84,
                );
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
              OutlinedButton.icon(
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
  final Rect cropRect;
  final Color primaryColor;

  const _CropPainter({
    required this.cropRect,
    required this.primaryColor,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final rect =
        Rect.fromLTWH(
      cropRect.left *
          size.width,
      cropRect.top *
          size.height,
      cropRect.width *
          size.width,
      cropRect.height *
          size.height,
    );

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

    final selected =
        Path()
          ..addRect(rect);

    final outside =
        Path.combine(
      PathOperation
          .difference,
      full,
      selected,
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

    canvas.drawRect(
      rect,
      borderPaint,
    );

    final guidePaint =
        Paint()
          ..color = Colors.white
              .withValues(
            alpha: 0.35,
          )
          ..strokeWidth = 1;

    final thirdX =
        rect.width / 3;

    final thirdY =
        rect.height / 3;

    for (var i = 1; i <= 2; i++) {
      final x =
          rect.left +
              thirdX * i;

      canvas.drawLine(
        Offset(
          x,
          rect.top,
        ),
        Offset(
          x,
          rect.bottom,
        ),
        guidePaint,
      );

      final y =
          rect.top +
              thirdY * i;

      canvas.drawLine(
        Offset(
          rect.left,
          y,
        ),
        Offset(
          rect.right,
          y,
        ),
        guidePaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _CropPainter oldDelegate,
  ) {
    return oldDelegate.cropRect !=
            cropRect ||
        oldDelegate.primaryColor !=
            primaryColor;
  }
}
 
