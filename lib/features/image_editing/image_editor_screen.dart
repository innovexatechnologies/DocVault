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

  // Text overlay state
  String _overlayText = '';
  double _textXPercent = 0.5;
  double _textYPercent = 0.5;
  Color _textColor = Colors.black;
  final int _textFontSize = 24;

  // Crop presets
  String _selectedCropRatio = 'Free';

  // Active filter
  ImageFilterType _activeFilter = ImageFilterType.none;

  @override
  void initState() {
    super.initState();
    _currentWorkingPath = widget.imagePath;
  }

  Future<void> _handleRotate(int degrees) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final newPath = await _editorService.rotateImage(_currentWorkingPath, degrees);
      setState(() {
        _currentWorkingPath = newPath;
        _hasUnsavedEdits = true;
      });
    } catch (e) {
      _showError('Rotation failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleFlip({bool horizontal = true, bool vertical = false}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final newPath = await _editorService.flipImage(
        _currentWorkingPath,
        horizontal: horizontal,
        vertical: vertical,
      );
      setState(() {
        _currentWorkingPath = newPath;
        _hasUnsavedEdits = true;
      });
    } catch (e) {
      _showError('Flip failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleFilter(ImageFilterType filter) async {
    if (_isProcessing || _activeFilter == filter) return;
    setState(() => _isProcessing = true);
    try {
      final newPath = await _editorService.applyFilter(_currentWorkingPath, filter);
      setState(() {
        _currentWorkingPath = newPath;
        _activeFilter = filter;
        _hasUnsavedEdits = true;
      });
    } catch (e) {
      _showError('Filter application failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleApplyText() async {
    if (_overlayText.trim().isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final newPath = await _editorService.addTextOverlay(
        _currentWorkingPath,
        text: _overlayText,
        xPercent: _textXPercent,
        yPercent: _textYPercent,
        color: _textColor,
        fontSize: _textFontSize,
      );
      setState(() {
        _currentWorkingPath = newPath;
        _overlayText = '';
        _hasUnsavedEdits = true;
        _activeMode = EditorMode.none;
      });
    } catch (e) {
      _showError('Failed to add text: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleApplyCrop() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final file = File(_currentWorkingPath);
      final bytes = await file.readAsBytes();
      final decoded = await decodeImageFromList(bytes);

      int cropW = decoded.width;
      int cropH = decoded.height;

      if (_selectedCropRatio == '1:1') {
        final minDim = decoded.width < decoded.height ? decoded.width : decoded.height;
        cropW = minDim;
        cropH = minDim;
      } else if (_selectedCropRatio == '4:3') {
        cropW = decoded.width;
        cropH = (decoded.width * 3 / 4).round().clamp(1, decoded.height);
      } else if (_selectedCropRatio == '16:9') {
        cropW = decoded.width;
        cropH = (decoded.width * 9 / 16).round().clamp(1, decoded.height);
      } else if (_selectedCropRatio == 'A4') {
        cropW = decoded.width;
        cropH = (decoded.width * 1.414).round().clamp(1, decoded.height);
      } else {
        // Free: inset by 5% margin for clean cut
        cropW = (decoded.width * 0.90).round();
        cropH = (decoded.height * 0.90).round();
      }

      final startX = ((decoded.width - cropW) / 2).round();
      final startY = ((decoded.height - cropH) / 2).round();

      final newPath = await _editorService.cropImage(
        _currentWorkingPath,
        x: startX,
        y: startY,
        width: cropW,
        height: cropH,
      );

      setState(() {
        _currentWorkingPath = newPath;
        _hasUnsavedEdits = true;
        _activeMode = EditorMode.none;
      });
    } catch (e) {
      _showError('Crop failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _saveAndExit() {
    if (_hasUnsavedEdits) {
      context.read<ImageSelectionProvider>().updateImageFilePath(
            widget.imageId,
            _currentWorkingPath,
          );
    }
    Navigator.of(context).pop(_currentWorkingPath);
  }

  Future<void> _handleCancelOrBack() async {
    if (!_hasUnsavedEdits) {
      Navigator.of(context).pop();
      return;
    }

    final result = await UnsavedChangesDialog.show(
      context,
      title: 'Discard Image Edits?',
      message: 'You have unapplied edits on this page. What would you like to do?',
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openTextDialog() {
    final textController = TextEditingController(text: _overlayText);
    Color selectedColor = _textColor;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Text to Page'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter text...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Colors.black,
                      Colors.white,
                      AppTheme.primaryColor,
                      Colors.red,
                      Colors.blue,
                      Colors.green,
                    ].map((c) {
                      final isSelected = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.accentColor : Colors.grey.shade400,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (textController.text.trim().isNotEmpty) {
                      setState(() {
                        _overlayText = textController.text.trim();
                        _textColor = selectedColor;
                        _activeMode = EditorMode.text;
                      });
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleCancelOrBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _handleCancelOrBack,
            tooltip: 'Cancel',
          ),
          title: Text(
            'Edit Page ${widget.pageIndex + 1}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          actions: [
            TextButton(
              onPressed: _saveAndExit,
              child: const Text(
                'Done',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // Center Image Preview
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.file(
                      File(_currentWorkingPath),
                      fit: BoxFit.contain,
                      key: ValueKey(_currentWorkingPath),
                    ),
                    if (_activeMode == EditorMode.text && _overlayText.isNotEmpty)
                      Positioned(
                        left: 40,
                        top: 40,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _textXPercent = (_textXPercent + details.delta.dx / 200).clamp(0.05, 0.95);
                              _textYPercent = (_textYPercent + details.delta.dy / 200).clamp(0.05, 0.95);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Text(
                              _overlayText,
                              style: TextStyle(
                                color: _textColor,
                                fontSize: _textFontSize.toDouble(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (_isProcessing)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              ),

            // Bottom Tools Control Dock
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.grey.shade900,
                    border: Border(top: BorderSide(color: Colors.white12)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sub-panel for active tool
                      if (_activeMode == EditorMode.rotate) _buildRotateControls(),
                      if (_activeMode == EditorMode.crop) _buildCropControls(),
                      if (_activeMode == EditorMode.filters) _buildFilterControls(),
                      if (_activeMode == EditorMode.text && _overlayText.isNotEmpty)
                        _buildTextControls(),

                      // Primary tool bar tabs
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildToolTab(
                              icon: Icons.crop_rounded,
                              label: 'Crop',
                              mode: EditorMode.crop,
                            ),
                            _buildToolTab(
                              icon: Icons.rotate_right_rounded,
                              label: 'Rotate',
                              mode: EditorMode.rotate,
                            ),
                            _buildToolTab(
                              icon: Icons.text_fields_rounded,
                              label: 'Text',
                              mode: EditorMode.text,
                              onTap: _openTextDialog,
                            ),
                            _buildToolTab(
                              icon: Icons.filter_b_and_w_rounded,
                              label: 'Filters',
                              mode: EditorMode.filters,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolTab({
    required IconData icon,
    required String label,
    required EditorMode mode,
    VoidCallback? onTap,
  }) {
    final isSelected = _activeMode == mode;
    return InkWell(
      onTap: onTap ??
          () {
            setState(() {
              _activeMode = isSelected ? EditorMode.none : mode;
            });
          },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primaryColor : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRotateControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: Colors.black26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.rotate_left_rounded, color: Colors.white),
            tooltip: 'Rotate Left 90°',
            onPressed: () => _handleRotate(270),
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
            tooltip: 'Rotate Right 90°',
            onPressed: () => _handleRotate(90),
          ),
          IconButton(
            icon: const Icon(Icons.flip_rounded, color: Colors.white),
            tooltip: 'Flip Horizontal',
            onPressed: () => _handleFlip(horizontal: true),
          ),
          IconButton(
            icon: const Icon(Icons.swap_vert_rounded, color: Colors.white),
            tooltip: 'Flip Vertical',
            onPressed: () => _handleFlip(horizontal: false, vertical: true),
          ),
        ],
      ),
    );
  }

  Widget _buildCropControls() {
    final ratios = ['Free', '1:1', '4:3', '16:9', 'A4'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: Colors.black26,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            ...ratios.map((r) {
              final isSelected = _selectedCropRatio == r;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(r, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12)),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: Colors.white10,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCropRatio = r);
                    }
                  },
                ),
              );
            }),
            ElevatedButton(
              onPressed: _handleApplyCrop,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Apply Crop'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: Colors.black26,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _filterButton('Original', ImageFilterType.none),
            const SizedBox(width: 8),
            _filterButton('Document', ImageFilterType.document),
            const SizedBox(width: 8),
            _filterButton('Grayscale', ImageFilterType.grayscale),
            const SizedBox(width: 8),
            _filterButton('Enhance', ImageFilterType.enhance),
          ],
        ),
      ),
    );
  }

  Widget _filterButton(String label, ImageFilterType type) {
    final isSelected = _activeFilter == type;
    return InkWell(
      onTap: () => _handleFilter(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTextControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.black26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Drag text to position it',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          ElevatedButton(
            onPressed: _handleApplyText,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Apply Text'),
          ),
        ],
      ),
    );
  }
}
