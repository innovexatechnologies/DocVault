import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/image_selection_provider.dart';
import '../../core/services/image_editor_service.dart';
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
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final ImageEditorService _editorService = ImageEditorService();

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

  // ============================================================
  // FILTER
  // ============================================================

  ImageFilterType _activeFilter = ImageFilterType.none;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _currentWorkingPath = widget.imagePath;
  }

  // ============================================================
  // ROTATE
  // ============================================================

  Future<void> _handleRotate(int degrees) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final newPath = await _editorService.rotateImage(
        _currentWorkingPath,
        degrees,
      );

      if (!mounted) return;

      setState(() {
        _currentWorkingPath = newPath;
        _hasUnsavedEdits = true;
      });
    } catch (e) {
      _showError('Rotation failed: $e');
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
      final newPath = await _editorService.flipImage(
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
      _showError('Flip failed: $e');
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

  Future<void> _handleFilter(ImageFilterType filter) async {
    if (_isProcessing || _activeFilter == filter) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final newPath = await _editorService.applyFilter(
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
      _showError('Filter application failed: $e');
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
    if (_overlayText.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final newPath = await _editorService.addTextOverlay(
        _currentWorkingPath,
        text: _overlayText,
        xPercent: _textXPercent,
        yPercent: _textYPercent,
        color: _textColor,
        fontSize: _textFontSize,
      );

      if (!mounted) return;

      setState(() {
        _currentWorkingPath = newPath;
        _overlayText = '';
        _hasUnsavedEdits = true;
        _activeMode = EditorMode.none;
      });
    } catch (e) {
      _showError('Failed to add text: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // CROP
  // ============================================================

  Future<void> _handleApplyCrop() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final file = File(_currentWorkingPath);

      final bytes = await file.readAsBytes();

      final decoded = await decodeImageFromList(bytes);

      int cropW = decoded.width;
      int cropH = decoded.height;

      if (_selectedCropRatio == '1:1') {
        final minDim = decoded.width < decoded.height
            ? decoded.width
            : decoded.height;

        cropW = minDim;
        cropH = minDim;
      } else if (_selectedCropRatio == '4:3') {
        cropW = decoded.width;

        cropH = (decoded.width * 3 / 4)
            .round()
            .clamp(1, decoded.height);
      } else if (_selectedCropRatio == '16:9') {
        cropW = decoded.width;

        cropH = (decoded.width * 9 / 16)
            .round()
            .clamp(1, decoded.height);
      } else if (_selectedCropRatio == 'A4') {
        cropW = decoded.width;

        cropH = (decoded.width / 0.7071)
            .round()
            .clamp(1, decoded.height);
      } else {
        cropW = (decoded.width * 0.90).round();

        cropH = (decoded.height * 0.90).round();
      }

      final startX =
          ((decoded.width - cropW) / 2).round();

      final startY =
          ((decoded.height - cropH) / 2).round();

      final newPath = await _editorService.cropImage(
        _currentWorkingPath,
        x: startX,
        y: startY,
        width: cropW,
        height: cropH,
      );

      if (!mounted) return;

      setState(() {
        _currentWorkingPath = newPath;
        _hasUnsavedEdits = true;
        _activeMode = EditorMode.none;
      });
    } catch (e) {
      _showError('Crop failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  void _saveAndExit() {
    if (_hasUnsavedEdits) {
      context.read<ImageSelectionProvider>().updateImageFilePath(
            widget.imageId,
            _currentWorkingPath,
          );
    }

    Navigator.of(context).pop(_currentWorkingPath);
  }

  // ============================================================
  // BACK / CANCEL
  // ============================================================

  Future<void> _handleCancelOrBack() async {
    if (!_hasUnsavedEdits) {
      Navigator.of(context).pop();
      return;
    }

    final result = await UnsavedChangesDialog.show(
      context,
      title: 'Discard Image Edits?',
      message:
          'You have unapplied edits on this page. What would you like to do?',
      saveLabel: 'Apply Changes',
      discardLabel: 'Discard',
    );

    if (!mounted) return;

    if (result == UnsavedChangesAction.save) {
      _saveAndExit();
    } else if (result == UnsavedChangesAction.discard) {
      Navigator.of(context).pop();
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ============================================================
  // TEXT DIALOG
  // ============================================================

  void _openTextDialog() {
    final textController =
        TextEditingController(text: _overlayText);

    Color selectedColor = _textColor;

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Add Text',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter text...',
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark
                          ? AppTheme.cardDark
                          : AppTheme.bgLight,
                      prefixIcon: const Icon(
                        Icons.text_fields_rounded,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Text Color',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Colors.black,
                      Colors.white,
                      AppTheme.primaryColor,
                      Colors.red,
                      Colors.blue,
                      Colors.green,
                    ].map((c) {
                      final isSelected =
                          selectedColor == c;

                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = c;
                          });
                        },
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 180),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : colors.outline
                                      .withValues(alpha: 0.35),
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.25),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: c == Colors.white
                                      ? Colors.black
                                      : Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actionsPadding:
                  const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (textController.text
                        .trim()
                        .isNotEmpty) {
                      setState(() {
                        _overlayText =
                            textController.text.trim();

                        _textColor = selectedColor;

                        _activeMode =
                            EditorMode.text;
                      });
                    }

                    Navigator.of(ctx).pop();
                  },
                  icon: const Icon(
                    Icons.check_rounded,
                    size: 19,
                  ),
                  label: const Text('Add Text'),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final isDark =
        theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? AppTheme.bgDark
        : AppTheme.bgLight;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleCancelOrBack();
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,

        // ========================================================
        // APP BAR
        // ========================================================

        appBar: AppBar(
          backgroundColor: backgroundColor,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,

          leading: Padding(
            padding: const EdgeInsets.only(
              left: 12,
              top: 6,
              bottom: 6,
            ),
            child: _buildTopButton(
              icon: Icons.close_rounded,
              onTap: _handleCancelOrBack,
            ),
          ),

          titleSpacing: 12,

          title: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Image Editor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Edit Page ${widget.pageIndex + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface
                      .withValues(alpha: 0.55),
                ),
              ),
            ],
          ),

          actions: [
            Padding(
              padding: const EdgeInsets.only(
                right: 14,
              ),
              child: GestureDetector(
                onTap: _saveAndExit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius:
                        BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor
                            .withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
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

        // ========================================================
        // BODY
        // ========================================================

        body: Stack(
          children: [
            Column(
              children: [
                // ==================================================
                // IMAGE AREA
                // ==================================================

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      12,
                    ),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.cardDark
                            : Colors.white,
                        borderRadius:
                            BorderRadius.circular(26),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.dividerDark
                              : AppTheme.dividerColor,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.20 : 0.06,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(25),
                        child: InteractiveViewer(
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

                                // ====================================
                                // TEXT OVERLAY
                                // ====================================

                                if (_activeMode ==
                                        EditorMode.text &&
                                    _overlayText.isNotEmpty)
                                  Positioned(
                                    left:
                                        MediaQuery.of(context)
                                                .size
                                                .width *
                                            (_textXPercent -
                                                0.1),
                                    top:
                                        MediaQuery.of(context)
                                                .size
                                                .height *
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
                                        child: Text(
                                          _overlayText,
                                          style:
                                              TextStyle(
                                            color:
                                                _textColor,
                                            fontSize:
                                                _textFontSize
                                                    .toDouble(),
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ==================================================
                // TOOL AREA
                // ==================================================

                _buildBottomEditorPanel(
                  isDark,
                  colorScheme,
                ),
              ],
            ),

            // ======================================================
            // PROCESSING OVERLAY
            // ======================================================

            if (_isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(
                    alpha: 0.45,
                  ),
                  child: Center(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.cardDark
                            : Colors.white,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 3,
                              color:
                                  AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Processing...',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w700,
                              color: colorScheme
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
  // TOP BUTTON
  // ============================================================

  Widget _buildTopButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(13),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.cardDark
                : Colors.white,
            borderRadius:
                BorderRadius.circular(13),
            border: Border.all(
              color: isDark
                  ? AppTheme.dividerDark
                  : AppTheme.dividerColor,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: Theme.of(context)
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
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.surfaceDark
            : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppTheme.dividerDark
                : AppTheme.dividerColor,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.22 : 0.06,
            ),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ======================================================
            // ACTIVE TOOL CONTROLS
            // ======================================================

            if (_activeMode ==
                EditorMode.rotate)
              _buildRotateControls(isDark),

            if (_activeMode ==
                EditorMode.crop)
              _buildCropControls(isDark),

            if (_activeMode ==
                EditorMode.filters)
              _buildFilterControls(isDark),

            if (_activeMode ==
                    EditorMode.text &&
                _overlayText.isNotEmpty)
              _buildTextControls(isDark),

            // ======================================================
            // TOOL BAR
            // ======================================================

            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                12,
                12,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildToolItem(
                      icon: Icons.crop_rounded,
                      label: 'Crop',
                      mode: EditorMode.crop,
                    ),
                  ),

                  Expanded(
                    child: _buildToolItem(
                      icon:
                          Icons.rotate_right_rounded,
                      label: 'Rotate',
                      mode: EditorMode.rotate,
                    ),
                  ),

                  Expanded(
                    child: _buildToolItem(
                      icon:
                          Icons.text_fields_rounded,
                      label: 'Text',
                      mode: EditorMode.text,
                      onTap: _openTextDialog,
                    ),
                  ),

                  Expanded(
                    child: _buildToolItem(
                      icon:
                          Icons.auto_awesome_rounded,
                      label: 'Filters',
                      mode: EditorMode.filters,
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
        Theme.of(context).brightness ==
            Brightness.dark;

    final colorScheme =
        Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap ??
          () {
            setState(() {
              _activeMode =
                  isSelected
                      ? EditorMode.none
                      : mode;
            });
          },
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 200),
        margin:
            const EdgeInsets.symmetric(
          horizontal: 4,
        ),
        padding:
            const EdgeInsets.symmetric(
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? isDark
                  ? const Color(0xFF211A4A)
                  : const Color(0xFFEDE7FF)
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 200,
              ),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : isDark
                        ? AppTheme.cardDark
                        : AppTheme.bgLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 21,
                color: isSelected
                    ? Colors.white
                    : colorScheme.onSurface
                        .withValues(
                        alpha: 0.65,
                      ),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: isSelected
                    ? AppTheme.primaryColor
                    : colorScheme.onSurface
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

  Widget _buildRotateControls(bool isDark) {
    return _buildSubPanel(
      isDark: isDark,
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon:
                Icons.rotate_left_rounded,
            label: 'Left',
            onTap: () =>
                _handleRotate(270),
          ),

          _buildActionButton(
            icon:
                Icons.rotate_right_rounded,
            label: 'Right',
            onTap: () =>
                _handleRotate(90),
          ),

          _buildActionButton(
            icon: Icons.flip_rounded,
            label: 'Flip H',
            onTap: () =>
                _handleFlip(
              horizontal: true,
            ),
          ),

          _buildActionButton(
            icon:
                Icons.swap_vert_rounded,
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

  Widget _buildCropControls(bool isDark) {
    final ratios = [
      'Free',
      '1:1',
      '4:3',
      '16:9',
      'A4',
    ];

    return _buildSubPanel(
      isDark: isDark,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.crop_rounded,
                size: 19,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 7),
              Text(
                'Crop Ratio',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Theme.of(context)
                          .colorScheme
                          .onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection:
                Axis.horizontal,
            physics:
                const BouncingScrollPhysics(),
            child: Row(
              children: [
                ...ratios.map(
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
                        label: Text(
                          ratio,
                          style:
                              TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w700,
                            color: selected
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
                        side:
                            BorderSide(
                          color: selected
                              ? AppTheme
                                  .primaryColor
                              : Theme.of(
                                  context,
                                )
                                  .colorScheme
                                  .outline
                                  .withValues(
                                    alpha:
                                        0.18,
                                  ),
                        ),
                        onSelected:
                            (value) {
                          if (value) {
                            setState(() {
                              _selectedCropRatio =
                                  ratio;
                            });
                          }
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(width: 4),

                ElevatedButton.icon(
                  onPressed:
                      _handleApplyCrop,
                  icon: const Icon(
                    Icons.check_rounded,
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
                      horizontal: 16,
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
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER CONTROLS
  // ============================================================

  Widget _buildFilterControls(bool isDark) {
    return _buildSubPanel(
      isDark: isDark,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 19,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 7),
              Text(
                'Choose Filter',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Theme.of(context)
                          .colorScheme
                          .onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection:
                Axis.horizontal,
            physics:
                const BouncingScrollPhysics(),
            child: Row(
              children: [
                _filterButton(
                  'Original',
                  ImageFilterType.none,
                  isDark,
                ),
                const SizedBox(width: 8),
                _filterButton(
                  'Document',
                  ImageFilterType.document,
                  isDark,
                ),
                const SizedBox(width: 8),
                _filterButton(
                  'Grayscale',
                  ImageFilterType.grayscale,
                  isDark,
                ),
                const SizedBox(width: 8),
                _filterButton(
                  'Enhance',
                  ImageFilterType.enhance,
                  isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER BUTTON
  // ============================================================

  Widget _filterButton(
    String label,
    ImageFilterType type,
    bool isDark,
  ) {
    final selected =
        _activeFilter == type;

    return GestureDetector(
      onTap: () =>
          _handleFilter(type),
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor
              : isDark
                  ? AppTheme.cardDark
                  : AppTheme.bgLight,
          borderRadius:
              BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(
                      alpha: 0.16,
                    ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : Theme.of(context)
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

  Widget _buildTextControls(bool isDark) {
    return _buildSubPanel(
      isDark: isDark,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.touch_app_rounded,
              color: AppTheme.primaryColor,
              size: 21,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Drag the text to position it',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.65),
              ),
            ),
          ),

          ElevatedButton.icon(
            onPressed:
                _handleApplyText,
            icon: const Icon(
              Icons.check_rounded,
              size: 18,
            ),
            label:
                const Text('Apply'),
            style:
                ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
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
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        2,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.cardDark
            : AppTheme.bgLight,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppTheme.dividerDark
              : AppTheme.dividerColor,
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
        Theme.of(context).brightness ==
            Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        padding:
            const EdgeInsets.symmetric(
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.surfaceDark
              : Colors.white,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? AppTheme.dividerDark
                : AppTheme.dividerColor,
          ),
        ),
        child: Column(
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
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color:
                    AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
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