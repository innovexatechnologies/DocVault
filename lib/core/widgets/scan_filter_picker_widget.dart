// scan_filter_picker_widget.dart
//
// Example UI: a horizontal row of filter thumbnails (like CamScanner's
// bottom filter strip) that the user taps after scanning a document.
//
// Place in lib/widgets/ and wire `onFilterApplied` to your save/export step.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
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

class _ScanFilterPickerWidgetState extends State<ScanFilterPickerWidget> {
  ScanFilter _selected = ScanFilter.original;
  Uint8List? _previewBytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _previewBytes = widget.originalImageBytes;
  }

  Future<void> _selectFilter(ScanFilter filter) async {
    setState(() {
      _selected = filter;
      _loading = true;
    });

    // Offload the pixel work to an isolate so the UI doesn't jank
    // on larger scans.
    final result = await compute(
      _applyFilterInIsolate,
      _FilterRequest(filter, widget.originalImageBytes),
    );

    setState(() {
      _previewBytes = result;
      _loading = false;
    });

    widget.onFilterApplied(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Image.memory(_previewBytes!, fit: BoxFit.contain),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ScanFilter.values.map((filter) {
              final isActive = filter == _selected;
              return GestureDetector(
                onTap: () => _selectFilter(filter),
                child: Container(
                  width: 64,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive ? Colors.blueAccent : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.filter,
                        color: isActive ? Colors.blueAccent : Colors.grey,
                      ),
                      Text(
                        ScanFilterService.label(filter),
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive ? Colors.blueAccent : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _FilterRequest {
  final ScanFilter filter;
  final Uint8List bytes;
  _FilterRequest(this.filter, this.bytes);
}

Uint8List _applyFilterInIsolate(_FilterRequest request) {
  return ScanFilterService.apply(request.filter, request.bytes);
}
