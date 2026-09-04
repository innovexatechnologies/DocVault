import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';
import '../../models/conversion_type.dart';
import '../../models/pdf_document.dart';
import '../utils/file_utils.dart';
import 'docx_generation_service.dart';
import 'pptx_generation_service.dart';

class PdfStorageService {
  static const String _metadataFileName = 'pdf_records.json';
  static const String _metadataDirName = 'DocScanner/metadata';

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

  /// Loads all saved documents (PDF, DOCS, PPT) and reconciles with physical disk state
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
          debugPrint('Error reading document metadata file: $e');
        }
      }

      // Reconcile with actual physical files on disk (.pdf, .docx, .pptx)
      final pdfDirectory = await FileUtils.getAppDocumentsDirectory();
      final List<PdfDocument> validDocuments = [];
      bool metadataChanged = false;

      if (await pdfDirectory.exists()) {
        final diskEntities = pdfDirectory.listSync();
        final Set<String> existingPathsOnDisk = {};

        for (final entity in diskEntities) {
          if (entity is File) {
            final pathLower = entity.path.toLowerCase();
            final isSupported = pathLower.endsWith('.pdf') ||
                pathLower.endsWith('.docx') ||
                pathLower.endsWith('.pptx');

            if (isSupported) {
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
                // Discovered unindexed document on disk
                final size = await entity.length();
                final rawName = entity.uri.pathSegments.isNotEmpty
                    ? entity.uri.pathSegments.last
                    : 'Document.pdf';
                final type = ConversionType.fromFileName(rawName);
                final fileName = FileUtils.normalizeFileName(rawName, type);
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
      debugPrint('Error loading documents: $e');
      return [];
    }
  }

  /// Registers a newly generated document into storage metadata
  Future<PdfDocument> saveDocument({
    required String filePath,
    required String fileName,
    required int pageCount,
  }) async {
    final type = ConversionType.fromFileName(fileName);
    final normalizedFileName = FileUtils.normalizeFileName(fileName, type);
    final file = File(filePath);
    int size = 0;
    if (await file.exists()) {
      size = await file.length();
    }

    final doc = PdfDocument(
      id: const Uuid().v4(),
      fileName: normalizedFileName,
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

  /// Renames a document both on disk and in persistent metadata
  Future<PdfDocument> renameDocument(String id, String newBaseName) async {
    final allDocs = await loadAllDocuments();
    final docIndex = allDocs.indexWhere((d) => d.id == id);
    if (docIndex == -1) {
      throw Exception('Document not found in storage');
    }

    final oldDoc = allDocs[docIndex];
    final normalizedFileName = FileUtils.normalizeFileName(
      newBaseName,
      oldDoc.documentType,
    );

    if (oldDoc.fileName.toLowerCase() == normalizedFileName.toLowerCase()) {
      return oldDoc;
    }

    // Check duplicate name among other documents
    final isDuplicate = allDocs.any(
      (d) => d.id != id && d.fileName.toLowerCase() == normalizedFileName.toLowerCase(),
    );
    if (isDuplicate) {
      throw Exception('A document with the name "$normalizedFileName" already exists');
    }

    final oldFile = File(oldDoc.filePath);
    if (!await oldFile.exists()) {
      throw Exception('Original document file does not exist on disk');
    }

    final parentDir = oldFile.parent;
    final newFilePath = '${parentDir.path}/$normalizedFileName';
    final targetFile = File(newFilePath);

    if (await targetFile.exists() && targetFile.path != oldFile.path) {
      throw Exception('A file with this name already exists in storage');
    }

    // Rename physical file on disk
    await oldFile.rename(newFilePath);

    final updatedDoc = oldDoc.copyWith(
      fileName: normalizedFileName,
      filePath: newFilePath,
      modifiedAt: DateTime.now(),
    );

    allDocs[docIndex] = updatedDoc;
    await _saveMetadataToFile(allDocs);
    return updatedDoc;
  }

  /// Updates an existing document (PDF, DOCS, PPT) with modified/new pages
  Future<PdfDocument> updateDocumentContent({
    required String id,
    required List<String> imagePaths,
  }) async {
    if (imagePaths.isEmpty) {
      throw Exception('Cannot update document with 0 pages. At least 1 page is required.');
    }

    final allDocs = await loadAllDocuments();
    final docIndex = allDocs.indexWhere((d) => d.id == id);
    if (docIndex == -1) {
      throw Exception('Document not found in storage');
    }

    final existingDoc = allDocs[docIndex];
    final targetFile = File(existingDoc.filePath);
    final tempDir = await FileUtils.getTempDirectory();

    if (existingDoc.documentType == ConversionType.docs) {
      // Re-generate DOCX
      final docxService = DocxGenerationService();
      final result = await docxService.generateDocxFromImages(imagePaths);
      final generatedFile = File(result.filePath);

      await targetFile.parent.create(recursive: true);
      await generatedFile.copy(targetFile.path);
      await generatedFile.delete();
    } else if (existingDoc.documentType == ConversionType.ppt) {
      // Re-generate PPTX
      final pptxService = PptxGenerationService();
      final result = await pptxService.generatePptxFromImages(imagePaths);
      final generatedFile = File(result.filePath);

      await targetFile.parent.create(recursive: true);
      await generatedFile.copy(targetFile.path);
      await generatedFile.delete();
    } else {
      // Re-generate PDF
      final pdf = pw.Document();

      for (final imagePath in imagePaths) {
        final imageFile = File(imagePath);
        if (!await imageFile.exists()) {
          throw Exception('Image file not found: $imagePath');
        }

        final imageBytes = await imageFile.readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        final decodedImage = img.decodeImage(imageBytes);
        if (decodedImage == null) {
          throw Exception('Failed to decode image: $imagePath');
        }

        final imageWidth = decodedImage.width.toDouble();
        final imageHeight = decodedImage.height.toDouble();

        final pageWidth = PdfPageFormat.a4.width;
        final pageHeight = PdfPageFormat.a4.height;
        const margin = 20.0;

        final availableWidth = pageWidth - (margin * 2);
        final availableHeight = pageHeight - (margin * 2);

        double fitWidth = availableWidth;
        double fitHeight = (availableWidth * imageHeight) / imageWidth;

        if (fitHeight > availableHeight) {
          fitHeight = availableHeight;
          fitWidth = (availableHeight * imageWidth) / imageHeight;
        }

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) {
              return pw.Center(
                child: pw.Image(image, width: fitWidth, height: fitHeight),
              );
            },
          ),
        );
      }

      final pdfBytes = await pdf.save();
      final tempSaveFile = File(
        '${tempDir.path}/temp_update_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await tempSaveFile.writeAsBytes(pdfBytes, flush: true);

      if (!await tempSaveFile.exists() || await tempSaveFile.length() == 0) {
        throw Exception('Failed to generate updated PDF bytes.');
      }

      await targetFile.parent.create(recursive: true);
      await tempSaveFile.copy(targetFile.path);
      await tempSaveFile.delete();
    }

    final newSize = await targetFile.length();
    final updatedDoc = existingDoc.copyWith(
      pageCount: imagePaths.length,
      fileSizeBytes: newSize,
      modifiedAt: DateTime.now(),
    );

    allDocs[docIndex] = updatedDoc;
    await _saveMetadataToFile(allDocs);
    return updatedDoc;
  }

  /// Deletes a document file from disk and metadata
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
      debugPrint('Error deleting document: $e');
      return false;
    }
  }

  /// Deletes multiple documents by ID
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

  /// Exports a document to user's chosen location on device with exact name & verification
  Future<String?> exportDocument(String id) async {
    final allDocs = await loadAllDocuments();
    final doc = allDocs.firstWhere(
      (d) => d.id == id,
      orElse: () => throw Exception('Document not found'),
    );

    final sourceFile = File(doc.filePath);
    if (!await sourceFile.exists() || await sourceFile.length() == 0) {
      throw Exception('File does not exist or is empty on local storage');
    }

    final normalizedFileName = FileUtils.normalizeFileName(
      doc.fileName,
      doc.documentType,
    );
    final fileBytes = await sourceFile.readAsBytes();

    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save ${doc.documentType.shortName} to Device',
        fileName: normalizedFileName,
        type: FileType.custom,
        allowedExtensions: [doc.documentType.extension],
        bytes: fileBytes,
      );

      if (outputFile == null) {
        final selectedDir = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Select Folder to Save Document',
        );
        if (selectedDir != null) {
          outputFile = '$selectedDir/$normalizedFileName';
          final targetFile = File(outputFile);
          await targetFile.writeAsBytes(fileBytes, flush: true);
        }
      } else {
        final targetFile = File(outputFile);
        if (!await targetFile.exists() || await targetFile.length() == 0) {
          await targetFile.writeAsBytes(fileBytes, flush: true);
        }
      }

      if (outputFile != null) {
        final verifiedFile = File(outputFile);
        if (await verifiedFile.exists() && await verifiedFile.length() > 0) {
          return outputFile;
        }
      }
    } catch (e) {
      debugPrint('Export error via FilePicker: $e');
      try {
        Directory? targetDir = await getDownloadsDirectory();
        targetDir ??= await getApplicationDocumentsDirectory();
        final destPath = '${targetDir.path}/$normalizedFileName';
        final destFile = File(destPath);
        await destFile.writeAsBytes(fileBytes, flush: true);

        if (await destFile.exists() && await destFile.length() > 0) {
          return destPath;
        }
      } catch (fallbackError) {
        debugPrint('Fallback export error: $fallbackError');
        rethrow;
      }
    }

    return null;
  }

  /// Exports multiple documents to a selected folder with exact filenames
  Future<int> exportMultipleDocuments(List<String> ids) async {
    final selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Folder to Export Documents',
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
            final normalizedName = FileUtils.normalizeFileName(
              doc.fileName,
              doc.documentType,
            );
            final destPath = '$selectedDir/$normalizedName';
            final destFile = File(destPath);
            final bytes = await sourceFile.readAsBytes();
            await destFile.writeAsBytes(bytes, flush: true);

            if (await destFile.exists() && await destFile.length() > 0) {
              exportedCount++;
            }
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
      final jsonList = documents.map((d) => d.toMap()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
      await metaFile.writeAsString(jsonString, flush: true);
    } catch (e) {
      debugPrint('Error saving metadata to file: $e');
    }
  }
}
