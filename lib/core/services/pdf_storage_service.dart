import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/pdf_document.dart';
import '../utils/file_utils.dart';

class PdfStorageService {
  static const String _metadataFileName = 'pdf_records.json';
  static const String _metadataDirName = 'DocVault/metadata';

  PdfStorageService();

  /// Gets the file where metadata JSON is persisted
  Future<File> _getMetadataFile() async {
    final docDir = await getApplicationDocumentsDirectory();
    final metaDir = Directory('${docDir.path}/$_metadataDirName');
    if (!await metaDir.exists()) {
      await metaDir.create(recursive: true);
    }
    return File('${metaDir.path}/$_metadataFileName');
  }

  /// Loads all saved PDF documents and reconciles with physical disk state
  Future<List<PdfDocument>> loadAllDocuments() async {
    try {
      final metaFile = await _getMetadataFile();
      final Map<String, PdfDocument> documentMap = {};

      if (await metaFile.exists()) {
        try {
          final content = await metaFile.readAsString();
          if (content.trim().isNotEmpty) {
            final List<dynamic> jsonList = json.decode(content) as List<dynamic>;
            for (final item in jsonList) {
              if (item is Map<String, dynamic>) {
                final doc = PdfDocument.fromMap(item);
                documentMap[doc.filePath] = doc;
              }
            }
          }
        } catch (e) {
          debugPrint('Error reading PDF metadata file: $e');
        }
      }

      // Reconcile with actual physical PDF files on disk
      final pdfDirectory = await FileUtils.getAppDocumentsDirectory();
      final List<PdfDocument> validDocuments = [];
      bool metadataChanged = false;

      if (await pdfDirectory.exists()) {
        final diskEntities = pdfDirectory.listSync();
        final Set<String> existingPathsOnDisk = {};

        for (final entity in diskEntities) {
          if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
            existingPathsOnDisk.add(entity.path);

            if (documentMap.containsKey(entity.path)) {
              // Valid existing document
              final existingDoc = documentMap[entity.path]!;
              final actualSize = await entity.length();
              if (existingDoc.fileSizeBytes != actualSize) {
                validDocuments.add(existingDoc.copyWith(fileSizeBytes: actualSize));
                metadataChanged = true;
              } else {
                validDocuments.add(existingDoc);
              }
            } else {
              // Discovered unindexed PDF on disk (e.g. from prior version or external intent)
              final size = await entity.length();
              final fileName = entity.uri.pathSegments.isNotEmpty
                  ? entity.uri.pathSegments.last
                  : 'Document.pdf';
              final fileStat = await entity.stat();

              final newDoc = PdfDocument(
                id: const Uuid().v4(),
                fileName: fileName,
                filePath: entity.path,
                fileSizeBytes: size,
                pageCount: 1,
                createdAt: fileStat.changed,
                modifiedAt: fileStat.modified,
              );
              validDocuments.add(newDoc);
              metadataChanged = true;
            }
          }
        }

        // Check if any metadata entries point to non-existent disk files
        if (documentMap.length != validDocuments.length) {
          metadataChanged = true;
        }
      }

      // Sort newest first by creation date
      validDocuments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (metadataChanged) {
        await _saveMetadataToFile(validDocuments);
      }

      return validDocuments;
    } catch (e) {
      debugPrint('Error loading PDF documents: $e');
      return [];
    }
  }

  /// Registers a newly generated PDF document into storage metadata
  Future<PdfDocument> saveDocument({
    required String filePath,
    required String fileName,
    required int pageCount,
  }) async {
    final file = File(filePath);
    int size = 0;
    if (await file.exists()) {
      size = await file.length();
    }

    final doc = PdfDocument(
      id: const Uuid().v4(),
      fileName: fileName,
      filePath: filePath,
      fileSizeBytes: size,
      pageCount: pageCount,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );

    final allDocs = await loadAllDocuments();
    allDocs.removeWhere((d) => d.filePath == filePath || d.id == doc.id);
    allDocs.insert(0, doc);

    await _saveMetadataToFile(allDocs);
    return doc;
  }

  /// Renames a PDF file both on disk and in persistent metadata
  Future<PdfDocument> renameDocument(String id, String newBaseName) async {
    final cleanBase = newBaseName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (cleanBase.isEmpty) {
      throw Exception('File name cannot be empty');
    }

    final newFileName = cleanBase.toLowerCase().endsWith('.pdf')
        ? cleanBase
        : '$cleanBase.pdf';

    final allDocs = await loadAllDocuments();
    final docIndex = allDocs.indexWhere((d) => d.id == id);
    if (docIndex == -1) {
      throw Exception('PDF document not found in storage');
    }

    final oldDoc = allDocs[docIndex];
    if (oldDoc.fileName == newFileName) {
      return oldDoc;
    }

    // Check duplicate name among other documents
    final isDuplicate = allDocs.any(
      (d) => d.id != id && d.fileName.toLowerCase() == newFileName.toLowerCase(),
    );
    if (isDuplicate) {
      throw Exception('A document with the name "$newFileName" already exists');
    }

    final oldFile = File(oldDoc.filePath);
    if (!await oldFile.exists()) {
      throw Exception('Original PDF file does not exist on disk');
    }

    final parentDir = oldFile.parent;
    final newFilePath = '${parentDir.path}/$newFileName';
    final targetFile = File(newFilePath);

    if (await targetFile.exists() && targetFile.path != oldFile.path) {
      throw Exception('A file with this name already exists in storage');
    }

    // Rename on disk
    await oldFile.rename(newFilePath);

    final updatedDoc = oldDoc.copyWith(
      fileName: newFileName,
      filePath: newFilePath,
      modifiedAt: DateTime.now(),
    );

    allDocs[docIndex] = updatedDoc;
    await _saveMetadataToFile(allDocs);
    return updatedDoc;
  }

  /// Deletes a PDF file from disk and metadata
  Future<bool> deleteDocument(String id) async {
    try {
      final allDocs = await loadAllDocuments();
      final docIndex = allDocs.indexWhere((d) => d.id == id);
      if (docIndex == -1) return false;

      final doc = allDocs[docIndex];
      final file = File(doc.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      allDocs.removeAt(docIndex);
      await _saveMetadataToFile(allDocs);
      return true;
    } catch (e) {
      debugPrint('Error deleting PDF document: $e');
      return false;
    }
  }

  /// Deletes multiple PDF documents by ID
  Future<int> deleteMultipleDocuments(List<String> ids) async {
    int deletedCount = 0;
    final allDocs = await loadAllDocuments();
    final Set<String> targetIds = ids.toSet();

    for (final id in targetIds) {
      final docIndex = allDocs.indexWhere((d) => d.id == id);
      if (docIndex != -1) {
        final doc = allDocs[docIndex];
        try {
          final file = File(doc.filePath);
          if (await file.exists()) {
            await file.delete();
          }
          deletedCount++;
        } catch (e) {
          debugPrint('Error deleting file ${doc.filePath}: $e');
        }
      }
    }

    allDocs.removeWhere((d) => targetIds.contains(d.id));
    await _saveMetadataToFile(allDocs);
    return deletedCount;
  }

  /// Exports a PDF document to user's chosen location on device
  Future<String?> exportDocument(String id) async {
    final allDocs = await loadAllDocuments();
    final doc = allDocs.firstWhere(
      (d) => d.id == id,
      orElse: () => throw Exception('Document not found'),
    );

    final sourceFile = File(doc.filePath);
    if (!await sourceFile.exists()) {
      throw Exception('PDF file does not exist on disk');
    }

    try {
      // Prompt user to select destination file or folder
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF to Device',
        fileName: doc.fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile == null) {
        // Fallback: ask user to select directory if saveFile returns null or unsupported
        final selectedDir = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Select Folder to Save PDF',
        );
        if (selectedDir != null) {
          outputFile = '$selectedDir/${doc.fileName}';
        }
      }

      if (outputFile != null) {
        if (!outputFile.toLowerCase().endsWith('.pdf')) {
          outputFile = '$outputFile.pdf';
        }
        await sourceFile.copy(outputFile);
        return outputFile;
      }
    } catch (e) {
      debugPrint('Export error via FilePicker: $e');
      // Fallback to Documents/Downloads folder if accessible
      try {
        Directory? targetDir = await getDownloadsDirectory();
        targetDir ??= await getApplicationDocumentsDirectory();
        final destPath = '${targetDir.path}/${doc.fileName}';
        await sourceFile.copy(destPath);
        return destPath;
      } catch (fallbackError) {
        debugPrint('Fallback export error: $fallbackError');
        rethrow;
      }
    }

    return null;
  }

  /// Exports multiple PDF documents to a selected folder
  Future<int> exportMultipleDocuments(List<String> ids) async {
    final selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Folder to Export PDFs',
    );
    if (selectedDir == null) return 0;

    int exportedCount = 0;
    final allDocs = await loadAllDocuments();
    final targetIds = ids.toSet();

    for (final doc in allDocs) {
      if (targetIds.contains(doc.id)) {
        try {
          final sourceFile = File(doc.filePath);
          if (await sourceFile.exists()) {
            final destPath = '$selectedDir/${doc.fileName}';
            await sourceFile.copy(destPath);
            exportedCount++;
          }
        } catch (e) {
          debugPrint('Error exporting ${doc.fileName}: $e');
        }
      }
    }

    return exportedCount;
  }

  /// Helper to persist documents list into JSON file
  Future<void> _saveMetadataToFile(List<PdfDocument> documents) async {
    try {
      final metaFile = await _getMetadataFile();
      final jsonString = json.encode(documents.map((d) => d.toMap()).toList());
      await metaFile.writeAsString(jsonString, flush: true);
    } catch (e) {
      debugPrint('Error saving metadata to file: $e');
    }
  }
}
