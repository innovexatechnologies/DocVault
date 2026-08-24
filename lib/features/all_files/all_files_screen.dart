import 'package:doc_vault/features/home/source_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/image_selection_provider.dart';
import '../../core/providers/pdf_manager_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/conversion_type.dart';
import '../../models/pdf_document.dart';
import '../pdf_generation/review_screen.dart';
import '../pdf_result/pdf_viewer_screen.dart';
import 'widgets/all_files_empty_state.dart';
import 'widgets/delete_confirmation_dialog.dart';
import 'widgets/pdf_actions_bottom_sheet.dart';
import 'widgets/pdf_details_dialog.dart';
import 'widgets/pdf_file_card.dart';
import 'widgets/rename_pdf_dialog.dart';
import 'widgets/sort_options_bottom_sheet.dart';
 

class AllFilesScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;

  const AllFilesScreen({
    super.key,
    this.onNavigateToHome,
  });

  @override
  State<AllFilesScreen> createState() => _AllFilesScreenState();
}

class _AllFilesScreenState extends State<AllFilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openPdfViewer(PdfDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          filePath: doc.filePath,
          fileName: doc.fileName,
        ),
      ),
    );
  }

  void _showRenameDialog(PdfDocument doc) {
    showDialog(
      context: context,
      builder: (_) => RenamePdfDialog(
        document: doc,
        onRename: (newName) async {
          await context.read<PdfManagerProvider>().renamePdf(doc.id, newName);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Renamed to $newName'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _showDeleteDialog(PdfDocument doc) {
    showDialog(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete "${doc.fileName}"?',
        message:
            'Are you sure you want to permanently delete this document? This action cannot be undone.',
        confirmLabel: 'Delete',
        onConfirm: () async {
          final success =
              await context.read<PdfManagerProvider>().deletePdf(doc.id);
          if (mounted && success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Deleted "${doc.fileName}"'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _showDeleteSelectedDialog(int count) {
    showDialog(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete $count files?',
        message:
            'Are you sure you want to delete $count selected documents? This action cannot be undone.',
        confirmLabel: 'Delete All ($count)',
        onConfirm: () async {
          final deletedCount =
              await context.read<PdfManagerProvider>().deleteSelected();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Deleted $deletedCount document(s)'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _showDetailsDialog(PdfDocument doc) {
    showDialog(
      context: context,
      builder: (_) => PdfDetailsDialog(
        document: doc,
        onOpen: () => _openPdfViewer(doc),
        onShare: () => context.read<PdfManagerProvider>().sharePdf(doc),
        onExport: () => _handleExportSingle(doc),
      ),
    );
  }

  Future<void> _handleExportSingle(PdfDocument doc) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final exportedPath =
          await context.read<PdfManagerProvider>().exportPdf(doc.id);
      if (exportedPath != null && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Saved to $exportedPath'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.successColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleExportSelected() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final exportedCount =
          await context.read<PdfManagerProvider>().exportSelected();
      if (exportedCount > 0 && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Exported $exportedCount file(s) to device'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.successColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SortOptionsBottomSheet(
        currentOption: context.read<PdfManagerProvider>().sortOption,
        onSelect: (option) {
          context.read<PdfManagerProvider>().setSortOption(option);
        },
      ),
    );
  }

  Future<void> _handleEditPdf(PdfDocument doc) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Loading document for editing...',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final imagePaths = await FileUtils.extractPagesFromDocument(doc.filePath);
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      final imageSelectionProvider = context.read<ImageSelectionProvider>();
      imageSelectionProvider.clearAllImages();
      imageSelectionProvider.addImages(imagePaths, 'existing_doc', markUnsaved: false);

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ReviewScreen(
            existingDocument: doc,
            conversionType: doc.documentType,
          ),
        ),
      );

      if (result == true && mounted) {
        context.read<PdfManagerProvider>().loadDocuments();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load document for editing: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showActionsBottomSheet(PdfDocument doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PdfActionsBottomSheet(
        document: doc,
        onOpen: () => _openPdfViewer(doc),
        onShare: () => context.read<PdfManagerProvider>().sharePdf(doc),
        onRename: () => _showRenameDialog(doc),
        onEdit: () => _handleEditPdf(doc),
        onExport: () => _handleExportSingle(doc),
        onDetails: () => _showDetailsDialog(doc),
        onDelete: () => _showDeleteDialog(doc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final padding = ResponsiveHelper.getResponsivePadding(context);

    return Consumer<PdfManagerProvider>(
      builder: (context, provider, _) {
        final isSelection = provider.isSelectionMode;
        final docs = provider.documents;
        final hasAny = provider.hasDocuments;

        return PopScope(
          canPop: !isSelection && !_isSearchVisible,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (isSelection) {
              provider.clearSelection();
            } else if (_isSearchVisible) {
              setState(() {
                _isSearchVisible = false;
                _searchController.clear();
                provider.clearSearch();
              });
            }
          },
          child: Scaffold(
            backgroundColor: colorScheme.surface,
            appBar: isSelection
                ? _buildSelectionAppBar(context, provider, colorScheme, isDark)
                : _buildNormalAppBar(context, provider, colorScheme, isDark),
            body: Column(
              children: [
                // Expandable Search Bar
                if (_isSearchVisible && !isSelection)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? AppTheme.dividerDark
                              : AppTheme.dividerColor,
                        ),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search documents by name...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  provider.clearSearch();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        provider.setSearchQuery(value);
                      },
                    ),
                  ),

                // Format Filter Chips: [ All ] [ PDF ] [ DOCS ] [ PPT ]
                if (hasAny && !isSelection)
                  _buildFormatFilterChips(context, provider, colorScheme, isDark),

                // Filter/Sort active summary bar
                if (hasAny && !isSelection)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${docs.length} ${docs.length == 1 ? 'document' : 'documents'}'
                          '${provider.searchQuery.isNotEmpty ? ' found' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        InkWell(
                          onTap: _showSortBottomSheet,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.sort_rounded,
                                  size: 15,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  provider.sortOption.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main List View
                Expanded(
                  child: provider.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : provider.errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      size: 48,
                                      color: AppTheme.errorColor,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      provider.errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () => provider.loadDocuments(),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : !hasAny
    ? AllFilesEmptyState(
        isSearch: false,
        onCreatePdf: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SourceSelectionScreen(),
            ),
          );
        },
      )
                              : docs.isEmpty
                                  ? AllFilesEmptyState(
                                      isSearch: true,
                                      onClearSearch: () {
                                        provider.clearSearch();
                                        provider.setTypeFilter(null);
                                      },
                                    )
                                  : RefreshIndicator(
                                      color: AppTheme.primaryColor,
                                      onRefresh: () => provider.loadDocuments(),
                                      child: ListView.builder(
                                        padding: EdgeInsets.only(
                                          left: padding,
                                          right: padding,
                                          top: 6,
                                          bottom: 90,
                                        ),
                                        itemCount: docs.length,
                                        itemBuilder: (context, index) {
                                          final doc = docs[index];
                                          final isSelected = provider.selectedIds.contains(doc.id);

                                          return PdfFileCard(
                                            document: doc,
                                            isSelected: isSelected,
                                            isSelectionMode: isSelection,
                                            onTap: () {
                                              if (isSelection) {
                                                provider.toggleSelect(doc.id);
                                              } else {
                                                _openPdfViewer(doc);
                                              }
                                            },
                                            onLongPress: () {
                                              if (!isSelection) {
                                                provider.toggleSelectionMode(true);
                                                provider.toggleSelect(doc.id);
                                              }
                                            },
                                            onMoreOptions: () {
                                              _showActionsBottomSheet(doc);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                ),
              ],
            ),
            bottomNavigationBar: isSelection
                ? _buildSelectionBottomBar(context, provider, colorScheme, isDark)
                : null,
          ),
        );
      },
    );
  }

  Widget _buildFormatFilterChips(
    BuildContext context,
    PdfManagerProvider provider,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final filters = [
      (null, 'All', provider.rawDocuments.length),
      (ConversionType.pdf, 'PDF', provider.pdfCount),
      (ConversionType.docs, 'DOCS', provider.docsCount),
      (ConversionType.ppt, 'PPT', provider.pptCount),
    ];

    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final type = filter.$1;
          final label = filter.$2;
          final count = filter.$3;
          final isSelected = provider.typeFilter == type;

          final activeColor = type?.badgeColor ?? AppTheme.primaryColor;

          return FilterChip(
            selected: isSelected,
            showCheckmark: false,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type != null) ...[
                  Icon(
                    type.icon,
                    size: 14,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  '$label ($count)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            selectedColor: activeColor,
            backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected
                    ? activeColor
                    : (isDark ? AppTheme.dividerDark : AppTheme.dividerColor),
              ),
            ),
            onSelected: (_) {
              provider.setTypeFilter(type);
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(
    BuildContext context,
    PdfManagerProvider provider,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return AppBar(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      title: const Text(
        'All Files',
        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearchVisible ? Icons.search_off_rounded : Icons.search_rounded,
          ),
          tooltip: _isSearchVisible ? 'Close Search' : 'Search documents',
          onPressed: () {
            setState(() {
              _isSearchVisible = !_isSearchVisible;
              if (!_isSearchVisible) {
                _searchController.clear();
                provider.clearSearch();
              }
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.sort_rounded),
          tooltip: 'Sort Options',
          onPressed: _showSortBottomSheet,
        ),
        if (provider.hasDocuments)
          IconButton(
            icon: const Icon(Icons.checklist_rounded),
            tooltip: 'Select Multiple',
            onPressed: () {
              provider.toggleSelectionMode(true);
            },
          ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(
    BuildContext context,
    PdfManagerProvider provider,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final count = provider.selectedCount;
    final allSelected = count == provider.documents.length && count > 0;

    return AppBar(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Cancel Selection',
        onPressed: () {
          provider.clearSelection();
        },
      ),
      title: Text(
        count == 0 ? 'Select items' : '$count selected',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: () {
            provider.selectAll();
          },
          child: Text(
            allSelected ? 'Deselect All' : 'Select All',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBottomBar(
    BuildContext context,
    PdfManagerProvider provider,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final count = provider.selectedCount;
    final hasSelection = count > 0;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.dividerDark : AppTheme.dividerColor,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSelectionActionButton(
              icon: Icons.share_outlined,
              label: 'Share ($count)',
              color: hasSelection ? AppTheme.primaryColor : Colors.grey,
              onTap: hasSelection ? () => provider.shareSelected() : null,
            ),
            _buildSelectionActionButton(
              icon: Icons.download_rounded,
              label: 'Export ($count)',
              color: hasSelection ? AppTheme.primaryColor : Colors.grey,
              onTap: hasSelection ? () => _handleExportSelected() : null,
            ),
            _buildSelectionActionButton(
              icon: Icons.delete_outline_rounded,
              label: 'Delete ($count)',
              color: hasSelection ? AppTheme.errorColor : Colors.grey,
              onTap: hasSelection ? () => _showDeleteSelectedDialog(count) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
