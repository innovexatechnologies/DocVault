package com.example.doc_vault

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {

    companion object {
        private const val PDF_CHANNEL = "docvault/pdf_intent"
        private const val OFFICE_CHANNEL = "docvault/office_renderer"
    }

    // =========================================================================
    // FLUTTER ENGINE
    // =========================================================================

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        setupPdfIntentChannel(flutterEngine)
        setupOfficeRendererChannel(flutterEngine)
    }

    // =========================================================================
    // PDF / EXTERNAL DOCUMENT CHANNEL
    // =========================================================================

    private fun setupPdfIntentChannel(
        flutterEngine: FlutterEngine
    ) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PDF_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // =============================================================
                // INITIAL EXTERNAL DOCUMENT
                // =============================================================

                "getInitialDocument",
                "getInitialPdf" -> {

                    try {
                        val uri = getDocumentUri(intent)

                        if (uri == null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }

                        val fileName = getFileName(uri)
                        val mimeType = getMimeType(uri, fileName)

                        result.success(
                            mapOf(
                                "uri" to uri.toString(),
                                "fileName" to fileName,
                                "mimeType" to mimeType
                            )
                        )

                    } catch (e: Exception) {

                        result.error(
                            "INITIAL_DOCUMENT_ERROR",
                            e.message
                                ?: "Failed to get initial document.",
                            null
                        )
                    }
                }

                // =============================================================
                // READ EXTERNAL DOCUMENT
                // =============================================================

                "readDocument",
                "readPdf" -> {

                    try {

                        val uriString =
                            call.argument<String>("uri")

                        if (uriString.isNullOrBlank()) {
                            result.error(
                                "INVALID_URI",
                                "Document URI is missing.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val uri = Uri.parse(uriString)

                        // -----------------------------------------------------
                        // Verify URI
                        // -----------------------------------------------------

                        if (!isReadableUri(uri)) {
                            result.error(
                                "INVALID_URI",
                                "The document URI cannot be accessed.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        // -----------------------------------------------------
                        // Read bytes
                        // -----------------------------------------------------

                        val bytes = readDocumentBytes(uri)

                        if (bytes == null || bytes.isEmpty()) {
                            result.error(
                                "READ_ERROR",
                                "Unable to read document or document is empty.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        // -----------------------------------------------------
                        // File information
                        // -----------------------------------------------------

                        val fileName = getFileName(uri)
                        val mimeType = getMimeType(uri, fileName)

                        // -----------------------------------------------------
                        // Return to Flutter
                        // -----------------------------------------------------

                        result.success(
                            mapOf(
                                "bytes" to bytes,
                                "fileName" to fileName,
                                "mimeType" to mimeType
                            )
                        )

                    } catch (e: SecurityException) {

                        result.error(
                            "PERMISSION_ERROR",
                            "Permission denied while reading document.",
                            null
                        )

                    } catch (e: IOException) {

                        result.error(
                            "READ_ERROR",
                            e.message
                                ?: "I/O error while reading document.",
                            null
                        )

                    } catch (e: Exception) {

                        result.error(
                            "READ_ERROR",
                            e.message
                                ?: "Failed to read external document.",
                            null
                        )
                    }
                }

                // =============================================================
                // UNKNOWN METHOD
                // =============================================================

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // =========================================================================
    // OFFICE RENDERER CHANNEL
    // =========================================================================

    private fun setupOfficeRendererChannel(
        flutterEngine: FlutterEngine
    ) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OFFICE_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "convertOfficeToPdf" -> {

                    val inputPath =
                        call.argument<String>("inputPath")

                    val outputPath =
                        call.argument<String>("outputPath")

                    if (
                        inputPath.isNullOrBlank() ||
                        outputPath.isNullOrBlank()
                    ) {
                        result.error(
                            "INVALID_ARGUMENT",
                            "Input or output path is missing.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    // ---------------------------------------------------------
                    // No native Office engine currently installed.
                    //
                    // This does NOT affect external document importing.
                    // File import is handled through PDF_CHANNEL above.
                    // ---------------------------------------------------------

                    result.error(
                        "OFFICE_ENGINE_NOT_INSTALLED",
                        "Android Office rendering engine is not installed.",
                        null
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // =========================================================================
    // NEW EXTERNAL DOCUMENT
    // =========================================================================

    override fun onNewIntent(
        intent: Intent
    ) {
        super.onNewIntent(intent)

        // Update Activity's current intent.
        setIntent(intent)

        val uri = getDocumentUri(intent)

        if (uri != null) {
            sendDocumentToFlutter(uri)
        }
    }

    // =========================================================================
    // SEND NEW DOCUMENT TO FLUTTER
    // =========================================================================

    private fun sendDocumentToFlutter(
        uri: Uri
    ) {
        val engine = flutterEngine
            ?: return

        val fileName = getFileName(uri)
        val mimeType = getMimeType(uri, fileName)

        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            PDF_CHANNEL
        ).invokeMethod(
            "newDocument",
            mapOf(
                "uri" to uri.toString(),
                "fileName" to fileName,
                "mimeType" to mimeType
            )
        )
    }

    // =========================================================================
    // GET DOCUMENT URI
    // =========================================================================

    private fun getDocumentUri(
        currentIntent: Intent?
    ): Uri? {

        if (currentIntent == null) {
            return null
        }

        val action = currentIntent.action

        // Support Android VIEW intent.
        if (action != Intent.ACTION_VIEW) {
            return null
        }

        val uri = currentIntent.data
            ?: return null

        if (!isSupportedDocument(currentIntent, uri)) {
            return null
        }

        return uri
    }

    // =========================================================================
    // CHECK SUPPORTED DOCUMENT
    // =========================================================================

    private fun isSupportedDocument(
        currentIntent: Intent,
        uri: Uri
    ): Boolean {

        // ---------------------------------------------------------------------
        // MIME TYPE
        // ---------------------------------------------------------------------

        val intentMimeType =
            currentIntent.type
                ?.lowercase()
                ?.trim()

        if (!intentMimeType.isNullOrEmpty()) {

            if (
                intentMimeType == "application/pdf" ||

                intentMimeType ==
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ||

                intentMimeType ==
                "application/vnd.openxmlformats-officedocument.presentationml.presentation" ||

                intentMimeType ==
                "application/msword" ||

                intentMimeType ==
                "application/vnd.ms-powerpoint"
            ) {
                return true
            }

            if (
                intentMimeType.contains("pdf") ||
                intentMimeType.contains("word") ||
                intentMimeType.contains("document") ||
                intentMimeType.contains("presentation") ||
                intentMimeType.contains("powerpoint")
            ) {
                return true
            }
        }

        // ---------------------------------------------------------------------
        // CONTENT RESOLVER MIME TYPE
        // ---------------------------------------------------------------------

        try {

            val resolverMimeType =
                contentResolver.getType(uri)
                    ?.lowercase()
                    ?.trim()

            if (!resolverMimeType.isNullOrEmpty()) {

                if (
                    resolverMimeType == "application/pdf" ||

                    resolverMimeType ==
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ||

                    resolverMimeType ==
                    "application/vnd.openxmlformats-officedocument.presentationml.presentation" ||

                    resolverMimeType ==
                    "application/msword" ||

                    resolverMimeType ==
                    "application/vnd.ms-powerpoint"
                ) {
                    return true
                }

                if (
                    resolverMimeType.contains("pdf") ||
                    resolverMimeType.contains("word") ||
                    resolverMimeType.contains("document") ||
                    resolverMimeType.contains("presentation") ||
                    resolverMimeType.contains("powerpoint")
                ) {
                    return true
                }
            }

        } catch (_: Exception) {
            // Continue with extension check.
        }

        // ---------------------------------------------------------------------
        // FILE EXTENSION
        // ---------------------------------------------------------------------

        val fileName =
            getFileName(uri).lowercase()

        return fileName.endsWith(".pdf") ||
                fileName.endsWith(".docx") ||
                fileName.endsWith(".pptx") ||
                fileName.endsWith(".doc") ||
                fileName.endsWith(".ppt")
    }

    // =========================================================================
    // READ DOCUMENT BYTES
    // =========================================================================

    private fun readDocumentBytes(
        uri: Uri
    ): ByteArray? {

        return try {

            when (uri.scheme?.lowercase()) {

                "content" -> {
                    contentResolver
                        .openInputStream(uri)
                        ?.use { inputStream ->
                            inputStream.readBytes()
                        }
                }

                "file" -> {
                    val path =
                        uri.path
                            ?: return null

                    java.io.File(path)
                        .takeIf { it.exists() }
                        ?.readBytes()
                }

                else -> {
                    // Try ContentResolver for unknown URI schemes.
                    contentResolver
                        .openInputStream(uri)
                        ?.use { inputStream ->
                            inputStream.readBytes()
                        }
                }
            }

        } catch (_: Exception) {
            null
        }
    }

    // =========================================================================
    // CHECK URI READABILITY
    // =========================================================================

    private fun isReadableUri(
        uri: Uri
    ): Boolean {

        return try {

            when (uri.scheme?.lowercase()) {

                "content" -> {
                    contentResolver
                        .openAssetFileDescriptor(
                            uri,
                            "r"
                        )
                        ?.use {
                            true
                        }
                        ?: false
                }

                "file" -> {
                    val path =
                        uri.path
                            ?: return false

                    java.io.File(path).canRead()
                }

                else -> {
                    contentResolver
                        .openInputStream(uri)
                        ?.use {
                            true
                        }
                        ?: false
                }
            }

        } catch (_: Exception) {
            false
        }
    }

    // =========================================================================
    // GET FILE NAME
    // =========================================================================

    private fun getFileName(
        uri: Uri
    ): String {

        // ---------------------------------------------------------------------
        // CONTENT URI
        // ---------------------------------------------------------------------

        if (uri.scheme?.equals(
                "content",
                ignoreCase = true
            ) == true
        ) {

            try {

                val projection =
                    arrayOf(OpenableColumns.DISPLAY_NAME)

                val cursor: Cursor? =
                    contentResolver.query(
                        uri,
                        projection,
                        null,
                        null,
                        null
                    )

                cursor?.use {

                    val nameIndex =
                        it.getColumnIndex(
                            OpenableColumns.DISPLAY_NAME
                        )

                    if (
                        nameIndex >= 0 &&
                        it.moveToFirst()
                    ) {

                        val name =
                            it.getString(nameIndex)

                        if (!name.isNullOrBlank()) {
                            return name
                        }
                    }
                }

            } catch (_: Exception) {
                // Continue with other methods.
            }
        }

        // ---------------------------------------------------------------------
        // FILE URI
        // ---------------------------------------------------------------------

        if (
            uri.scheme?.equals(
                "file",
                ignoreCase = true
            ) == true
        ) {

            val path =
                uri.path

            if (!path.isNullOrBlank()) {

                val fileName =
                    java.io.File(path).name

                if (fileName.isNotBlank()) {
                    return fileName
                }
            }
        }

        // ---------------------------------------------------------------------
        // URI LAST SEGMENT
        // ---------------------------------------------------------------------

        val lastSegment =
            uri.lastPathSegment

        if (!lastSegment.isNullOrBlank()) {

            val decoded =
                try {
                    Uri.decode(lastSegment)
                } catch (_: Exception) {
                    lastSegment
                }

            if (
                decoded.contains(".") &&
                decoded.length > 1
            ) {
                return decoded
            }
        }

        // ---------------------------------------------------------------------
        // MIME TYPE FALLBACK
        // ---------------------------------------------------------------------

        val mimeType =
            try {
                contentResolver
                    .getType(uri)
                    ?.lowercase()
            } catch (_: Exception) {
                null
            }

        return when {

            mimeType == "application/pdf" ||
                    mimeType?.contains("pdf") == true ->
                "Imported_Document.pdf"

            mimeType?.contains("wordprocessingml") == true ->
                "Imported_Document.docx"

            mimeType?.contains("msword") == true ->
                "Imported_Document.doc"

            mimeType?.contains("presentationml") == true ->
                "Imported_Presentation.pptx"

            mimeType?.contains("ms-powerpoint") == true ->
                "Imported_Presentation.ppt"

            mimeType?.contains("powerpoint") == true ->
                "Imported_Presentation.pptx"

            mimeType?.contains("presentation") == true ->
                "Imported_Presentation.pptx"

            else ->
                "Imported_Document.pdf"
        }
    }

    // =========================================================================
    // GET MIME TYPE
    // =========================================================================

    private fun getMimeType(
        uri: Uri,
        fileName: String
    ): String {

        // First use Android ContentResolver.
        try {

            val mimeType =
                contentResolver
                    .getType(uri)

            if (!mimeType.isNullOrBlank()) {
                return mimeType
            }

        } catch (_: Exception) {
            // Continue with extension detection.
        }

        // Fallback based on file extension.
        return when {

            fileName.lowercase().endsWith(".pdf") ->
                "application/pdf"

            fileName.lowercase().endsWith(".docx") ->
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

            fileName.lowercase().endsWith(".pptx") ->
                "application/vnd.openxmlformats-officedocument.presentationml.presentation"

            fileName.lowercase().endsWith(".doc") ->
                "application/msword"

            fileName.lowercase().endsWith(".ppt") ->
                "application/vnd.ms-powerpoint"

            else ->
                "application/octet-stream"
        }
    }
}