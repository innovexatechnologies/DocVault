import 'package:doc_vault/core/providers/pdf_manager_provider.dart';
import 'package:doc_vault/core/services/pdf_storage_service.dart';
import 'package:doc_vault/models/pdf_document.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePdfStorageService extends PdfStorageService {
  final List<PdfDocument> mockDocs;

  FakePdfStorageService(this.mockDocs);

  @override
  Future<List<PdfDocument>> loadAllDocuments() async {
    return List.from(mockDocs);
  }

  @override
  Future<PdfDocument> saveDocument({
    required String filePath,
    required String fileName,
    required int pageCount,
  }) async {
    final doc = PdfDocument(
      id: 'mock-${mockDocs.length + 1}',
      fileName: fileName,
      filePath: filePath,
      fileSizeBytes: 1024,
      pageCount: pageCount,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
    mockDocs.insert(0, doc);
    return doc;
  }

  @override
  Future<PdfDocument> renameDocument(String id, String newBaseName) async {
    final index = mockDocs.indexWhere((d) => d.id == id);
    if (index == -1) throw Exception('Not found');
    final clean = newBaseName.endsWith('.pdf') ? newBaseName : '$newBaseName.pdf';
    final updated = mockDocs[index].copyWith(fileName: clean);
    mockDocs[index] = updated;
    return updated;
  }

  @override
  Future<bool> deleteDocument(String id) async {
    final index = mockDocs.indexWhere((d) => d.id == id);
    if (index == -1) return false;
    mockDocs.removeAt(index);
    return true;
  }

  @override
  Future<int> deleteMultipleDocuments(List<String> ids) async {
    final initial = mockDocs.length;
    mockDocs.removeWhere((d) => ids.contains(d.id));
    return initial - mockDocs.length;
  }
}

void main() {
  late List<PdfDocument> sampleDocs;
  late FakePdfStorageService fakeStorage;
  late PdfManagerProvider provider;

  setUp(() {
    sampleDocs = [
      PdfDocument(
        id: '1',
        fileName: 'Beta.pdf',
        filePath: '/storage/Beta.pdf',
        fileSizeBytes: 2048,
        pageCount: 2,
        createdAt: DateTime(2026, 8, 5, 10, 0),
        modifiedAt: DateTime(2026, 8, 5, 10, 0),
      ),
      PdfDocument(
        id: '2',
        fileName: 'Alpha.pdf',
        filePath: '/storage/Alpha.pdf',
        fileSizeBytes: 1024,
        pageCount: 1,
        createdAt: DateTime(2026, 8, 10, 12, 0),
        modifiedAt: DateTime(2026, 8, 10, 12, 0),
      ),
      PdfDocument(
        id: '3',
        fileName: 'Gamma.pdf',
        filePath: '/storage/Gamma.pdf',
        fileSizeBytes: 4096,
        pageCount: 5,
        createdAt: DateTime(2026, 8, 1, 8, 0),
        modifiedAt: DateTime(2026, 8, 1, 8, 0),
      ),
    ];

    fakeStorage = FakePdfStorageService(sampleDocs);
    provider = PdfManagerProvider(storageService: fakeStorage);
  });

  group('PdfManagerProvider Sorting and Filtering', () {
    test('sorts by newestFirst by default', () async {
      await provider.loadDocuments();
      expect(provider.sortOption, PdfSortOption.newestFirst);
      final names = provider.documents.map((d) => d.fileName).toList();
      expect(names, ['Alpha.pdf', 'Beta.pdf', 'Gamma.pdf']);
    });

    test('sorts by oldestFirst', () async {
      await provider.loadDocuments();
      provider.setSortOption(PdfSortOption.oldestFirst);
      final names = provider.documents.map((d) => d.fileName).toList();
      expect(names, ['Gamma.pdf', 'Beta.pdf', 'Alpha.pdf']);
    });

    test('sorts by nameAsc', () async {
      await provider.loadDocuments();
      provider.setSortOption(PdfSortOption.nameAsc);
      final names = provider.documents.map((d) => d.fileName).toList();
      expect(names, ['Alpha.pdf', 'Beta.pdf', 'Gamma.pdf']);
    });

    test('sorts by nameDesc', () async {
      await provider.loadDocuments();
      provider.setSortOption(PdfSortOption.nameDesc);
      final names = provider.documents.map((d) => d.fileName).toList();
      expect(names, ['Gamma.pdf', 'Beta.pdf', 'Alpha.pdf']);
    });

    test('sorts by sizeLargest', () async {
      await provider.loadDocuments();
      provider.setSortOption(PdfSortOption.sizeLargest);
      final names = provider.documents.map((d) => d.fileName).toList();
      expect(names, ['Gamma.pdf', 'Beta.pdf', 'Alpha.pdf']);
    });

    test('sorts by sizeSmallest', () async {
      await provider.loadDocuments();
      provider.setSortOption(PdfSortOption.sizeSmallest);
      final names = provider.documents.map((d) => d.fileName).toList();
      expect(names, ['Alpha.pdf', 'Beta.pdf', 'Gamma.pdf']);
    });

    test('filters by search query', () async {
      await provider.loadDocuments();
      provider.setSearchQuery('alp');
      expect(provider.documents.length, 1);
      expect(provider.documents.first.fileName, 'Alpha.pdf');

      provider.clearSearch();
      expect(provider.documents.length, 3);
    });
  });

  group('PdfManagerProvider Selection Mode', () {
    test('toggles selection mode and selects items', () async {
      await provider.loadDocuments();
      expect(provider.isSelectionMode, false);

      provider.toggleSelect('1');
      expect(provider.isSelectionMode, true);
      expect(provider.selectedCount, 1);
      expect(provider.selectedIds.contains('1'), true);

      provider.toggleSelect('2');
      expect(provider.selectedCount, 2);

      provider.toggleSelect('1');
      expect(provider.selectedCount, 1);

      provider.toggleSelect('2');
      expect(provider.selectedCount, 0);
      expect(provider.isSelectionMode, false);
    });

    test('selects and deselects all items', () async {
      await provider.loadDocuments();
      provider.selectAll();
      expect(provider.selectedCount, 3);
      expect(provider.isSelectionMode, true);

      provider.selectAll();
      expect(provider.selectedCount, 0);
      expect(provider.isSelectionMode, false);
    });

    test('deletes selected documents', () async {
      await provider.loadDocuments();
      provider.toggleSelect('1');
      provider.toggleSelect('3');

      final deleted = await provider.deleteSelected();
      expect(deleted, 2);
      expect(provider.documents.length, 1);
      expect(provider.documents.first.id, '2');
      expect(provider.isSelectionMode, false);
    });
  });

  group('PdfManagerProvider CRUD operations', () {
    test('renames a document', () async {
      await provider.loadDocuments();
      final updated = await provider.renamePdf('1', 'RenamedBeta');
      expect(updated.fileName, 'RenamedBeta.pdf');
      expect(provider.getDocumentById('1')?.fileName, 'RenamedBeta.pdf');
    });

    test('deletes a document', () async {
      await provider.loadDocuments();
      final result = await provider.deletePdf('2');
      expect(result, true);
      expect(provider.documents.length, 2);
      expect(provider.getDocumentById('2'), isNull);
    });

    test('registers a newly generated document', () async {
      await provider.loadDocuments();
      final newDoc = await provider.registerGeneratedPdf(
        filePath: '/storage/NewDoc.pdf',
        fileName: 'NewDoc.pdf',
        pageCount: 3,
      );

      expect(newDoc.fileName, 'NewDoc.pdf');
      expect(provider.documents.first.fileName, 'NewDoc.pdf');
    });
  });
}
