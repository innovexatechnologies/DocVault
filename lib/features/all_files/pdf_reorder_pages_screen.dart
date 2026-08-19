import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:provider/provider.dart';
import '../../core/providers/pdf_manager_provider.dart';
import '../../core/services/pdf_storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/unsaved_changes_dialog.dart';
import '../../models/pdf_document.dart';

class PdfReorderPagesScreen extends StatefulWidget {
  final PdfDocument document;

  const PdfReorderPagesScreen({
    super.key,
    required this.document,
  });

  @override
  State<PdfReorderPagesScreen> createState() => _PdfReorderPagesScreenState();
}

class _PageEntry {
  final int originalPageIndex;
  final pdfx.PdfPageImage pageImage;

  _PageEntry({
    required this.originalPageIndex,
    required this.pageImage,
  });
}

class _PdfReorderPagesScreenState extends State<PdfReorderPagesScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  String? _errorMessage;

  List<_PageEntry> _pages = [];

  @override
  void initState() {
    super.initState();
    _loadPdfPages();
  }

  Future<void> _loadPdfPages() async {
    try {
      final docFile = File(widget.document.filePath);
      if (!await docFile.exists()) {
        throw Exception('PDF file not found on device.');
      }

      final pdfDoc = await pdfx.PdfDocument.openFile(widget.document.filePath);
      final List<_PageEntry> loadedPages = [];

      for (int i = 1; i <= pdfDoc.pagesCount; i++) {
        final page = await pdfDoc.getPage(i);
        final pageImage = await page.render(
          width: page.width / 2,
          height: page.height / 2,
          format: pdfx.PdfPageImageFormat.jpeg,
        );
        await page.close();

        if (pageImage != null) {
          loadedPages.add(_PageEntry(
            originalPageIndex: i,
            pageImage: pageImage,
          ));
        }
      }

      await pdfDoc.close();

      if (mounted) {
        setState(() {
          _pages = loadedPages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load PDF pages: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
      _hasChanges = true;
    });
  }

  void _removePage(int index) {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove the only remaining page in the PDF.'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _pages.removeAt(index);
      _hasChanges = true;
    });
  }

  Future<void> _saveReorderedPdf() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final pdfProvider = context.read<PdfManagerProvider>();
    try {
      final newPdf = pw.Document();

      for (final entry in _pages) {
        final image = pw.MemoryImage(entry.pageImage.bytes);
        newPdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(image, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      final targetFile = File(widget.document.filePath);
      final pdfBytes = await newPdf.save();
      await targetFile.writeAsBytes(pdfBytes, flush: true);

      // Verify file written
      if (!await targetFile.exists() || await targetFile.length() == 0) {
        throw Exception('Failed to write updated PDF file.');
      }

      // Update storage metadata
      final updatedDoc = PdfDocument(
        id: widget.document.id,
        fileName: widget.document.fileName,
        filePath: widget.document.filePath,
        fileSizeBytes: await targetFile.length(),
        pageCount: _pages.length,
        createdAt: widget.document.createdAt,
        modifiedAt: DateTime.now(),
      );

      await PdfStorageService().saveDocument(
        filePath: updatedDoc.filePath,
        fileName: updatedDoc.fileName,
        pageCount: updatedDoc.pageCount,
      );

      if (mounted) {
        await pdfProvider.loadDocuments();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Updated "${widget.document.fileName}" successfully!'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save updated PDF: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleBack() async {
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    final action = await UnsavedChangesDialog.show(
      context,
      title: 'Discard Page Reordering?',
      message: 'You have unapplied page changes. What would you like to do?',
      saveLabel: 'Save Changes',
      discardLabel: 'Discard',
    );

    if (!mounted) return;

    if (action == UnsavedChangesAction.save) {
      _saveReorderedPdf();
    } else if (action == UnsavedChangesAction.discard) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
            tooltip: 'Back',
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reorder PDF Pages',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Text(
                widget.document.fileName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _isSaving ? null : _saveReorderedPdf,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.primaryColor,
                        ),
                      ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Go Back'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Drag items to reorder pages or tap delete to remove pages.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _pages.length,
                          onReorder: _onReorder,
                          itemBuilder: (context, index) {
                            final entry = _pages[index];

                            return Container(
                              key: ValueKey('page_${entry.originalPageIndex}_$index'),
                              margin: const EdgeInsets.only(bottom: 12),
                              height: 90,
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.surfaceDark : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      color: Colors.transparent,
                                      child: const Icon(
                                        Icons.drag_indicator,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    height: 90,
                                    child: Image.memory(
                                      entry.pageImage.bytes,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Page ${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Original Page ${entry.originalPageIndex}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colorScheme.onSurface.withValues(alpha: 0.55),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppTheme.errorColor,
                                    ),
                                    tooltip: 'Delete Page',
                                    onPressed: () => _removePage(index),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
        bottomNavigationBar: _hasChanges
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                  border: Border(top: BorderSide(color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor)),
                ),
                child: SafeArea(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveReorderedPdf,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(_isSaving ? 'Saving Changes...' : 'Save Changes (${_pages.length} pages)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
