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
        private const val DOCUMENT_CHANNEL =
            "docvault/pdf_intent"
    }

    // =========================================================================
    // FLUTTER ENGINE
    // =========================================================================

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        setupDocumentChannel(flutterEngine)
    }

    // =========================================================================
    // DOCUMENT CHANNEL
    // =========================================================================

    private fun setupDocumentChannel(
        flutterEngine: FlutterEngine
    ) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOCUMENT_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // =============================================================
                // GET INITIAL EXTERNAL DOCUMENT
                // =============================================================

                "getInitialDocument",
                "getInitialPdf" -> {

                    try {
                        val uri = getDocumentUri(intent)

                        if (uri == null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }

                        result.success(
                            createDocumentMap(uri)
                        )

                    } catch (e: Exception) {

                        result.error(
                            "INITIAL_DOCUMENT_ERROR",
                            e.message
                                ?: "Unable to open document.",
                            null
                        )
                    }
                }

                // =============================================================
                // READ DOCUMENT BYTES
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

                        val uri =
                            Uri.parse(uriString)

                        val bytes =
                            readDocumentBytes(uri)

                        if (bytes == null ||
                            bytes.isEmpty()
                        ) {

                            result.error(
                                "READ_ERROR",
                                "Unable to read document.",
                                null
                            )

                            return@setMethodCallHandler
                        }

                        val fileName =
                            getFileName(uri)

                        val mimeType =
                            getMimeType(
                                uri,
                                fileName
                            )

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
                                ?: "Unable to read document.",
                            null
                        )

                    } catch (e: Exception) {

                        result.error(
                            "READ_ERROR",
                            e.message
                                ?: "Failed to open document.",
                            null
                        )
                    }
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

        setIntent(intent)

        val uri =
            getDocumentUri(intent)

        if (uri != null) {
            sendDocumentToFlutter(uri)
        }
    }

    // =========================================================================
    // SEND DOCUMENT TO FLUTTER
    // =========================================================================

    private fun sendDocumentToFlutter(
        uri: Uri
    ) {

        val engine =
            flutterEngine
                ?: return

        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            DOCUMENT_CHANNEL
        ).invokeMethod(
            "newDocument",
            createDocumentMap(uri)
        )
    }

    // =========================================================================
    // CREATE DOCUMENT MAP
    // =========================================================================

    private fun createDocumentMap(
        uri: Uri
    ): Map<String, String> {

        val fileName =
            getFileName(uri)

        val mimeType =
            getMimeType(
                uri,
                fileName
            )

        return mapOf(
            "uri" to uri.toString(),
            "fileName" to fileName,
            "mimeType" to mimeType
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

        val action =
            currentIntent.action

        if (action != Intent.ACTION_VIEW) {
            return null
        }

        val uri =
            currentIntent.data
                ?: return null

        if (!isSupportedDocument(uri)) {
            return null
        }

        // Try to persist permission for content URI.
        if (uri.scheme.equals(
                "content",
                ignoreCase = true
            )
        ) {

            try {

                contentResolver.takePersistableUriPermission(
                    uri,
                    currentIntent.flags and
                            (
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                            )
                )

            } catch (_: Exception) {
                // Some providers don't support persistable permissions.
                // Temporary permission is still used.
            }
        }

        return uri
    }

    // =========================================================================
    // CHECK SUPPORTED DOCUMENT
    // =========================================================================

    private fun isSupportedDocument(
        uri: Uri
    ): Boolean {

        val fileName =
            getFileName(uri)
                .lowercase()

        if (
            fileName.endsWith(".pdf") ||
            fileName.endsWith(".docx") ||
            fileName.endsWith(".pptx") ||
            fileName.endsWith(".doc") ||
            fileName.endsWith(".ppt")
        ) {
            return true
        }

        val mimeType =
            try {
                contentResolver
                    .getType(uri)
                    ?.lowercase()
                    ?.trim()
            } catch (_: Exception) {
                null
            }

        if (mimeType.isNullOrBlank()) {
            return false
        }

        return mimeType == "application/pdf" ||

                mimeType.contains("pdf") ||

                mimeType.contains("word") ||

                mimeType.contains("document") ||

                mimeType.contains("presentation") ||

                mimeType.contains("powerpoint")
    }

    // =========================================================================
    // READ DOCUMENT BYTES
    // =========================================================================

    private fun readDocumentBytes(
        uri: Uri
    ): ByteArray? {

        return try {

            when (
                uri.scheme
                    ?.lowercase()
            ) {

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

                    val file =
                        java.io.File(path)

                    if (
                        file.exists() &&
                        file.canRead()
                    ) {
                        file.readBytes()
                    } else {
                        null
                    }
                }

                else -> {

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
    // GET FILE NAME
    // =========================================================================

    private fun getFileName(
        uri: Uri
    ): String {

        // =============================================================
        // CONTENT URI
        // =============================================================

        if (
            uri.scheme.equals(
                "content",
                ignoreCase = true
            )
        ) {

            try {

                val projection =
                    arrayOf(
                        OpenableColumns.DISPLAY_NAME
                    )

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
                // Continue to fallback.
            }
        }

        // =============================================================
        // FILE URI
        // =============================================================

        if (
            uri.scheme.equals(
                "file",
                ignoreCase = true
            )
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

        // =============================================================
        // URI LAST SEGMENT
        // =============================================================

        val lastSegment =
            uri.lastPathSegment

        if (!lastSegment.isNullOrBlank()) {

            val decoded =
                try {
                    Uri.decode(lastSegment)
                } catch (_: Exception) {
                    lastSegment
                }

            if (decoded.isNotBlank()) {
                return decoded
            }
        }

        // =============================================================
        // MIME FALLBACK
        // =============================================================

        val mimeType =
            try {
                contentResolver
                    .getType(uri)
                    ?.lowercase()
            } catch (_: Exception) {
                null
            }

        return when {

            mimeType?.contains("pdf") == true ->
                "Imported_Document.pdf"

            mimeType?.contains("word") == true ||
                    mimeType?.contains("document") == true ->
                "Imported_Document.docx"

            mimeType?.contains("presentation") == true ||
                    mimeType?.contains("powerpoint") == true ->
                "Imported_Presentation.pptx"

            else ->
                "Imported_Document"
        }
    }

    // =========================================================================
    // GET MIME TYPE
    // =========================================================================

    private fun getMimeType(
        uri: Uri,
        fileName: String
    ): String {

        try {

            val mimeType =
                contentResolver.getType(uri)

            if (!mimeType.isNullOrBlank()) {
                return mimeType
            }

        } catch (_: Exception) {
            // Use extension fallback.
        }

        return when {

            fileName.lowercase()
                .endsWith(".pdf") ->
                "application/pdf"

            fileName.lowercase()
                .endsWith(".docx") ->
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

            fileName.lowercase()
                .endsWith(".pptx") ->
                "application/vnd.openxmlformats-officedocument.presentationml.presentation"

            fileName.lowercase()
                .endsWith(".doc") ->
                "application/msword"

            fileName.lowercase()
                .endsWith(".ppt") ->
                "application/vnd.ms-powerpoint"

            else ->
                "application/octet-stream"
        }
    }
}