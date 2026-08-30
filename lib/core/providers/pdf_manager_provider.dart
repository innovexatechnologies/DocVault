import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/conversion_type.dart';
import '../../models/pdf_document.dart';
import '../services/pdf_storage_service.dart';

enum PdfSortOption {
  newestFirst('Newest first'),
  oldestFirst('Oldest first'),
  nameAsc('Name (A–Z)'),
  nameDesc('Name (Z–A)'),
  sizeLargest('Largest first'),
  sizeSmallest('Smallest first');

  final String label;
  const PdfSortOption(this.label);
}

class PdfManagerProvider extends ChangeNotifier {
  final PdfStorageService _storageService;

  List<PdfDocument> _documents = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  PdfSortOption _sortOption = PdfSortOption.newestFirst;
  ConversionType? _typeFilter; // null means 'All'

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  PdfManagerProvider({PdfStorageService? storageService})
      : _storageService = storageService ?? PdfStorageService() {
    loadDocuments();
  }

  // Getters
  List<PdfDocument> get rawDocuments => List.unmodifiable(_documents);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  PdfSortOption get sortOption => _sortOption;
  ConversionType? get typeFilter => _typeFilter;
  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectedCount => _selectedIds.length;
  int get totalCount => _documents.length;
  bool get hasDocuments => _documents.isNotEmpty;

  int get pdfCount =>
      _documents.where((d) => d.documentType == ConversionType.pdf).length;
  int get docsCount =>
      _documents.where((d) => d.documentType == ConversionType.docs).length;
  int get pptCount =>
      _documents.where((d) => d.documentType == ConversionType.ppt).length;

  /// Returns documents filtered by search query, format type, and sorted according to sortOption
  List<PdfDocument> get documents {
    List<PdfDocument> list = List.from(_documents);

    // Apply format filter (PDF, DOCS, PPT)
    if (_typeFilter != null) {
      list = list.where((doc) => doc.documentType == _typeFilter).toList();
    }

    // Apply search filter
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      list = list.where((doc) {
        return doc.fileName.toLowerCase().contains(query);
      }).toList();
    }

    // Apply sorting
    switch (_sortOption) {
      case PdfSortOption.newestFirst:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case PdfSortOption.oldestFirst:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case PdfSortOption.nameAsc:
        list.sort(
          (a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
        );
        break;
      case PdfSortOption.nameDesc:
        list.sort(
          (a, b) => b.fileName.toLowerCase().compareTo(a.fileName.toLowerCase()),
        );
        break;
      case PdfSortOption.sizeLargest:
        list.sort((a, b) => b.fileSizeBytes.compareTo(a.fileSizeBytes));
        break;
      case PdfSortOption.sizeSmallest:
        list.sort((a, b) => a.fileSizeBytes.compareTo(b.fileSizeBytes));
        break;
    }

    return list;
  }

  /// Reloads all documents from storage
  Future<void> loadDocuments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _documents = await _storageService.loadAllDocuments();
      // Clean up selection if any selected item no longer exists
      final existingIds = _documents.map((d) => d.id).toSet();
      _selectedIds.removeWhere((id) => !existingIds.contains(id));
      if (_selectedIds.isEmpty && _isSelectionMode) {
        _isSelectionMode = false;
      }
    } catch (e) {
      _errorMessage = 'Failed to load documents: $e';
      debugPrint('Error in PdfManagerProvider.loadDocuments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registers a newly generated document into the provider
  Future<PdfDocument> registerGeneratedPdf({
    required String filePath,
    required String fileName,
    required int pageCount,
  }) async {
    final doc = await _storageService.saveDocument(
      filePath: filePath,
      fileName: fileName,
      pageCount: pageCount,
    );
    _documents.removeWhere((d) => d.id == doc.id || d.filePath == filePath);
    _documents.insert(0, doc);
    notifyListeners();
    return doc;
  }

  /// Updates content (pages) of an existing document
  Future<PdfDocument> updateDocumentContent(
    String id,
    List<String> newImagePaths,
  ) async {
    try {
      final updatedDoc = await _storageService.updateDocumentContent(
        id: id,
        imagePaths: newImagePaths,
      );
      final index = _documents.indexWhere((d) => d.id == id);
      if (index != -1) {
        _documents[index] = updatedDoc;
        notifyListeners();
      }
      return updatedDoc;
    } catch (e) {
      debugPrint('Error updating document content in provider: $e');
      rethrow;
    }
  }

  /// Renames a document
  Future<PdfDocument> renamePdf(String id, String newName) async {
    try {
      final updatedDoc = await _storageService.renameDocument(id, newName);
      final index = _documents.indexWhere((d) => d.id == id);
      if (index != -1) {
        _documents[index] = updatedDoc;
        notifyListeners();
      }
      return updatedDoc;
    } catch (e) {
      debugPrint('Error renaming document in provider: $e');
      rethrow;
    }
  }

  /// Deletes a single document
  Future<bool> deletePdf(String id) async {
    try {
      final success = await _storageService.deleteDocument(id);
      if (success) {
        _documents.removeWhere((d) => d.id == id);
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty && _isSelectionMode) {
          _isSelectionMode = false;
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error deleting document in provider: $e');
      return false;
    }
  }

  /// Deletes all currently selected documents
  Future<int> deleteSelected() async {
    if (_selectedIds.isEmpty) return 0;

    final idsToDelete = _selectedIds.toList();
    final count = await _storageService.deleteMultipleDocuments(idsToDelete);

    _documents.removeWhere((d) => _selectedIds.contains(d.id));
    _selectedIds.clear();
    _isSelectionMode = false;
    notifyListeners();
    return count;
  }

  /// Shares a single file
  Future<void> sharePdf(PdfDocument doc) async {
    await Share.shareXFiles(
      [XFile(doc.filePath)],
      text: 'Sharing ${doc.fileName} from DocScanner',
    );
  }

  /// Shares all currently selected files
  Future<void> shareSelected() async {
    if (_selectedIds.isEmpty) return;

    final selectedDocs = _documents.where((d) => _selectedIds.contains(d.id)).toList();
    final xFiles = selectedDocs.map((d) => XFile(d.filePath)).toList();

    if (xFiles.isNotEmpty) {
      await Share.shareXFiles(
        xFiles,
        text: 'Sharing ${xFiles.length} documents from DocScanner',
      );
    }
  }

  /// Exports a single document to device storage
  Future<String?> exportPdf(String id) async {
    return await _storageService.exportDocument(id);
  }

  /// Exports all currently selected documents to a directory
  Future<int> exportSelected() async {
    if (_selectedIds.isEmpty) return 0;
    return await _storageService.exportMultipleDocuments(_selectedIds.toList());
  }

  /// Updates format filter (null = All, ConversionType.pdf, docs, ppt)
  void setTypeFilter(ConversionType? filter) {
    _typeFilter = filter;
    notifyListeners();
  }

  /// Updates search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Clears search query
  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  /// Updates sort option
  void setSortOption(PdfSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  /// Toggles multi-selection mode on or off
  void toggleSelectionMode([bool? enable]) {
    _isSelectionMode = enable ?? !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedIds.clear();
    }
    notifyListeners();
  }

  /// Toggles selection state for an individual item
  void toggleSelect(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
      if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedIds.add(id);
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  /// Selects all currently visible/filtered documents
  void selectAll() {
    final visible = documents;
    if (_selectedIds.length == visible.length) {
      _selectedIds.clear();
      _isSelectionMode = false;
    } else {
      _selectedIds.addAll(visible.map((d) => d.id));
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  /// Clears current selection
  void clearSelection() {
    _selectedIds.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  /// Finds a document by ID
  PdfDocument? getDocumentById(String id) {
    try {
      return _documents.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}
