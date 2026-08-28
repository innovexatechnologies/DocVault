import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/scan_filter_service.dart';

class FilterScreen extends StatefulWidget {
  final Uint8List scannedImageBytes;

  const FilterScreen({
    super.key,
    required this.scannedImageBytes,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  ScanFilter _selectedFilter = ScanFilter.original;
  Uint8List? _filteredBytes;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _filteredBytes = widget.scannedImageBytes;
  }

  Future<void> _selectFilter(ScanFilter filter) async {
    setState(() {
      _selectedFilter = filter;
      _isApplying = true;
    });

    try {
      final bytes = await compute(
        _applyFilter,
        _FilterRequest(filter, widget.scannedImageBytes),
      );

      if (!mounted) return;

      setState(() {
        _filteredBytes = bytes;
        _isApplying = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isApplying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to apply this filter.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply Filter'),
        actions: [
          TextButton(
            onPressed: _isApplying || _filteredBytes == null
                ? null
                : () => Navigator.of(context).pop(_filteredBytes),
            child: const Text('Done'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _isApplying
                    ? const CircularProgressIndicator()
                    : Image.memory(
                        _filteredBytes!,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            SizedBox(
              height: 96,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: ScanFilter.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = ScanFilter.values[index];
                  final isSelected = filter == _selectedFilter;

                  return ChoiceChip(
                    label: Text(ScanFilterService.label(filter)),
                    selected: isSelected,
                    selectedColor: colorScheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? colorScheme.onPrimary : null,
                    ),
                    onSelected: _isApplying
                        ? null
                        : (_) => _selectFilter(filter),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRequest {
  final ScanFilter filter;
  final Uint8List bytes;

  const _FilterRequest(this.filter, this.bytes);
}

Uint8List _applyFilter(_FilterRequest request) {
  return ScanFilterService.apply(request.filter, request.bytes);
}
