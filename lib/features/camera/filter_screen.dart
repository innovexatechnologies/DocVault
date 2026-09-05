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

/// Cancellation token to prevent race conditions
class _CancellationToken {
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
  }

  bool get isCancelled => _cancelled;
}

class _FilterScreenState extends State<FilterScreen> {
  ScanFilter _selectedFilter = ScanFilter.original;
  Uint8List? _filteredBytes;
  bool _isApplying = false;

  /// Track pending operation to cancel if new one starts
  _CancellationToken? _currentToken;

  @override
  void initState() {
    super.initState();
    _filteredBytes = widget.scannedImageBytes;
  }

  @override
  void dispose() {
    /// Cancel any pending operations
    _currentToken?.cancel();
    super.dispose();
  }

  Future<void> _selectFilter(ScanFilter filter) async {
    /// Cancel previous operation
    _currentToken?.cancel();
    final token = _CancellationToken();
    _currentToken = token;

    setState(() {
      _selectedFilter = filter;
      _isApplying = true;
    });

    try {
      /// Apply filter — always on the original scanned bytes,
      /// never on the currently displayed filtered result, so
      /// filters never stack/overlap on top of each other.
      final bytes = await ScanFilterService.apply(
        filter,
        widget.scannedImageBytes,
      );

      /// Check if operation was cancelled or widget unmounted
      if (token.isCancelled || !mounted) {
        return;
      }

      setState(() {
        _filteredBytes = bytes;
        _isApplying = false;
      });

      // NOTE: previously there was an `oldBytes?.clear()` call here.
      // Uint8List is a FIXED-LENGTH list — calling `.clear()` on it
      // always throws UnsupportedError. That exception was being
      // silently caught below and shown to the user as "Filter
      // failed", even though the filter had actually applied
      // successfully. It has been removed; Dart's garbage collector
      // frees the old bytes automatically once nothing references
      // them anymore.
    } catch (e) {
      /// Check if cancelled
      if (token.isCancelled || !mounted) {
        return;
      }

      setState(() {
        _isApplying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Filter failed: ${e.toString()}'),
          duration: const Duration(seconds: 2),
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
                : () {
                    /// Cancel pending operations before pop
                    _currentToken?.cancel();
                    Navigator.of(context).pop(_filteredBytes);
                  },
            child: const Text('Done'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            /// Image Preview
            Expanded(
              child: Container(
                color: Colors.black12,
                child: Center(
                  child: _isApplying
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Processing ${ScanFilterService.label(_selectedFilter)}...',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        )
                      : _filteredBytes != null
                          ? Image.memory(
                              _filteredBytes!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            )
                          : const Text('No image'),
                ),
              ),
            ),

            /// Filter Chips
            Container(
              color: Colors.white,
              child: SizedBox(
                height: 96,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: ScanFilter.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = ScanFilter.values[index];
                    final isSelected = filter == _selectedFilter;

                    return ChoiceChip(
                      label: Text(
                        ScanFilterService.label(filter),
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: isSelected,
                      selectedColor: colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? colorScheme.onPrimary : null,
                        fontSize: 12,
                      ),
                      onSelected: _isApplying
                          ? null
                          : (_) {
                              /// Don't apply if already selected
                              if (filter != _selectedFilter) {
                                _selectFilter(filter);
                              }
                            },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}