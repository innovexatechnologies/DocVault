import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../services/scan_filter_service.dart';

class ScanFilterPickerWidget extends StatefulWidget {
  final Uint8List originalImageBytes;
  final void Function(Uint8List filteredBytes) onFilterApplied;

  const ScanFilterPickerWidget({
    super.key,
    required this.originalImageBytes,
    required this.onFilterApplied,
  });

  @override
  State<ScanFilterPickerWidget> createState() =>
      _ScanFilterPickerWidgetState();
}

/// Cache for filter thumbnails
class _ThumbnailCache {
  final Map<String, Uint8List> _cache = {};
  static const maxCacheSize = 10;

  Uint8List? get(ScanFilter filter) {
    return _cache[filter.toString()];
  }

  void set(ScanFilter filter, Uint8List bytes) {
    if (_cache.length >= maxCacheSize) {
      // Remove oldest entry (first one)
      _cache.remove(_cache.keys.first);
    }
    _cache[filter.toString()] = bytes;
  }

  void clear() {
    _cache.clear();
  }
}

class _ScanFilterPickerWidgetState extends State<ScanFilterPickerWidget> {
  ScanFilter _selected = ScanFilter.original;
  Uint8List? _previewBytes;
  bool _loading = false;
  late final _ThumbnailCache _thumbnailCache;

  /// Track which filter thumbnails are being generated
  final Map<ScanFilter, bool> _generatingThumbnails = {};

  @override
  void initState() {
    super.initState();
    _thumbnailCache = _ThumbnailCache();
    _previewBytes = widget.originalImageBytes;

    /// Pre-generate thumbnails for common filters
    _preThumbnails();
  }

  @override
  void dispose() {
    _thumbnailCache.clear();
    super.dispose();
  }

  /// Pre-generate thumbnails for frequently used filters
  void _preThumbnails() {
    final commonFilters = [
      ScanFilter.original,
      ScanFilter.grayscale,
      ScanFilter.blackAndWhite,
      ScanFilter.enhance,
    ];

    for (final filter in commonFilters) {
      _generateThumbnailInBackground(filter);
    }
  }

  /// Generate thumbnail in background (fire and forget)
  void _generateThumbnailInBackground(ScanFilter filter) {
    if (!mounted) return;

    setState(() {
      _generatingThumbnails[filter] = true;
    });

    _createThumbnail(filter).then((thumbnail) {
      if (!mounted) return;

      _thumbnailCache.set(filter, thumbnail);

      setState(() {
        _generatingThumbnails[filter] = false;
      });
    }).catchError((_) {
      if (!mounted) return;

      setState(() {
        _generatingThumbnails[filter] = false;
      });
    });
  }

  /// Create a small thumbnail for preview
  Future<Uint8List> _createThumbnail(ScanFilter filter) async {
    // Decode original
    final original = img.decodeImage(widget.originalImageBytes);
    if (original == null) {
      return widget.originalImageBytes;
    }

    // Resize to thumbnail size (200x200 max)
    final thumbnail = img.copyResize(
      original,
      width: 200,
      height: 200,
      maintainAspect: true,
      interpolation: img.Interpolation.linear,
    );

    // Apply filter
    img.Image filtered = thumbnail;

    switch (filter) {
      case ScanFilter.original:
        break;

      case ScanFilter.grayscale:
        filtered = img.grayscale(filtered);
        break;

      case ScanFilter.blackAndWhite:
        filtered = _applyBlackAndWhiteQuick(filtered);
        break;

      case ScanFilter.enhance:
        filtered = img.adjustColor(
          filtered,
          contrast: 1.35,
          brightness: 1.08,
          saturation: 1.15,
        );
        break;

      case ScanFilter.sharpen:
        filtered = img.convolution(
          filtered,
          filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
        );
        break;

      case ScanFilter.vivid:
        filtered = img.adjustColor(
          filtered,
          contrast: 1.25,
          saturation: 1.5,
          brightness: 1.03,
        );
        break;

      case ScanFilter.softLight:
        filtered = img.adjustColor(
          filtered,
          contrast: 0.92,
          brightness: 1.1,
          saturation: 0.95,
        );
        break;

      case ScanFilter.warmTone:
        filtered = img.adjustColor(
          filtered,
          contrast: 1.1,
          brightness: 1.04,
          saturation: 1.05,
        );
        filtered = img.colorOffset(
          filtered,
          red: 18,
          green: 6,
          blue: -14,
        );
        break;

      case ScanFilter.coolTone:
        filtered = img.adjustColor(
          filtered,
          contrast: 1.1,
          brightness: 1.03,
        );
        filtered = img.colorOffset(
          filtered,
          red: -12,
          green: -2,
          blue: 16,
        );
        break;

      case ScanFilter.highContrastBW:
        filtered = img.grayscale(filtered);
        filtered = img.adjustColor(
          filtered,
          contrast: 2.4,
          brightness: 1.02,
        );
        break;

      case ScanFilter.softBW:
        filtered = img.grayscale(filtered);
        filtered = img.adjustColor(
          filtered,
          contrast: 1.15,
          brightness: 1.05,
        );
        break;

      case ScanFilter.sepia:
        filtered = _applySepiaQuick(filtered);
        break;

      case ScanFilter.noirDramatic:
        filtered = img.grayscale(filtered);
        filtered = img.adjustColor(
          filtered,
          contrast: 1.7,
          brightness: 0.85,
        );
        break;

      case ScanFilter.brightWhite:
        filtered = img.adjustColor(
          filtered,
          contrast: 1.5,
          brightness: 1.25,
          saturation: 0.6,
        );
        break;

      case ScanFilter.lowLightBoost:
        filtered = img.adjustColor(
          filtered,
          brightness: 1.35,
          contrast: 1.12,
          gamma: 0.85,
        );
        break;

      case ScanFilter.matte:
        filtered = img.adjustColor(
          filtered,
          contrast: 0.85,
          brightness: 1.02,
          saturation: 0.85,
        );
        break;

      case ScanFilter.vintagePaper:
        filtered = img.adjustColor(
          filtered,
          contrast: 0.95,
          brightness: 1.02,
          saturation: 0.7,
        );
        filtered = img.colorOffset(
          filtered,
          red: 20,
          green: 10,
          blue: -20,
        );
        break;

      case ScanFilter.coldSteel:
        filtered = _applyColdSteelQuick(filtered);
        break;

      case ScanFilter.magicColorPro:
        filtered = img.adjustColor(
          filtered,
          contrast: 1.45,
          brightness: 1.1,
          saturation: 1.3,
        );
        filtered = img.convolution(
          filtered,
          filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
        );
        break;

      case ScanFilter.invertNegative:
        filtered = img.invert(filtered);
        break;

      case ScanFilter.cleanDocument:
        filtered = img.gaussianBlur(filtered, radius: 1);
        filtered = img.adjustColor(
          filtered,
          contrast: 1.4,
          brightness: 1.15,
          saturation: 0.9,
        );
        filtered = img.convolution(
          filtered,
          filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
        );
        break;
    }

    // Encode with lower quality for thumbnail
    return Uint8List.fromList(img.encodeJpg(filtered, quality: 80));
  }

  static img.Image _applyBlackAndWhiteQuick(img.Image image) {
    var result = img.grayscale(image);
    result = img.adjustColor(
      result,
      contrast: 1.9,
      brightness: 1.05,
    );

    const threshold = 140;

    for (final pixel in result) {
      final luminance = img.getLuminance(pixel);
      final value = luminance > threshold ? 255 : 0;

      pixel
        ..r = value
        ..g = value
        ..b = value;
    }

    return result;
  }

  static img.Image _applySepiaQuick(img.Image image) {
    final result = img.grayscale(image);

    for (final pixel in result) {
      final l = img.getLuminance(pixel);

      pixel
        ..r = (l * 1.07).clamp(0, 255).toInt()
        ..g = (l * 0.86).clamp(0, 255).toInt()
        ..b = (l * 0.63).clamp(0, 255).toInt();
    }

    return result;
  }

  static img.Image _applyColdSteelQuick(img.Image image) {
    var result = img.grayscale(image);
    result = img.adjustColor(
      result,
      contrast: 1.3,
      brightness: 1.0,
    );

    for (final pixel in result) {
      final l = img.getLuminance(pixel);

      pixel
        ..r = (l * 0.85).clamp(0, 255).toInt()
        ..g = (l * 0.95).clamp(0, 255).toInt()
        ..b = (l * 1.15).clamp(0, 255).toInt();
    }

    return result;
  }

  Future<void> _selectFilter(ScanFilter filter) async {
    setState(() {
      _selected = filter;
      _loading = true;
    });

    try {
      // Apply full-resolution filter — ALWAYS on the original bytes,
      // never on the currently displayed/previous filtered result.
      // This is what prevents filters from stacking/overlapping.
      final bytes = await ScanFilterService.apply(
        filter,
        widget.originalImageBytes,
      );

      if (!mounted) return;

      setState(() {
        _previewBytes = bytes;
        _loading = false;
      });

      // NOTE: previously there was an `oldBytes?.clear()` call here.
      // Uint8List is a FIXED-LENGTH list, and `.clear()` on a
      // fixed-length list always throws UnsupportedError. That
      // exception was silently aborting this function before
      // `widget.onFilterApplied(bytes)` could run, and was being
      // reported to the user as "Failed to apply filter". It has
      // been removed — Dart's GC handles cleanup automatically, and
      // there is no safe way (or need) to manually clear a Uint8List.

      widget.onFilterApplied(bytes);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to apply filter: ${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGenerating =
        _generatingThumbnails.values.any((v) => v == true);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /// Main Preview
        AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            color: Colors.black12,
            child: Center(
              child: _loading
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          'Applying ${ScanFilterService.label(_selected)}...',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    )
                  : _previewBytes != null
                      ? Image.memory(
                          _previewBytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        )
                      : const Text('No image'),
            ),
          ),
        ),

        const SizedBox(height: 12),

        /// Filter Chips
        SizedBox(
          height: 72,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: ScanFilter.values.map((filter) {
              final isActive = filter == _selected;
              final thumbnail = _thumbnailCache.get(filter);
              final isGeneratingThumbnail =
                  _generatingThumbnails[filter] ?? false;

              return GestureDetector(
                onTap: _loading || isGeneratingThumbnail
                    ? null
                    : () => _selectFilter(filter),
                child: Container(
                  width: 64,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          isActive ? Colors.blueAccent : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: Stack(
                    children: [
                      /// Thumbnail if available
                      if (thumbnail != null)
                        Center(
                          child: Image.memory(
                            thumbnail,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        )
                      else
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.filter,
                                size: 20,
                                color: isActive
                                    ? Colors.blueAccent
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ScanFilterService.label(filter),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isActive
                                      ? Colors.blueAccent
                                      : Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                      /// Loading indicator
                      if (isGeneratingThumbnail)
                        Container(
                          color: Colors.black38,
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        if (isGenerating)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Loading previews...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}