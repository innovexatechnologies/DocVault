package com.example.doc_vault

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val PDF_CHANNEL = "docvault/pdf_intent"
    private val OFFICE_CHANNEL = "docvault/office_renderer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupPdfIntentChannel(flutterEngine)
        setupOfficeRendererChannel(flutterEngine)
    }

    private fun setupPdfIntentChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PDF_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "getInitialDocument",
                "getInitialPdf" -> {
                    val uri = getDocumentUri(intent)

                    if (uri != null) {
                        result.success(
                            mapOf(
                                "uri" to uri.toString(),
                                "fileName" to getFileName(uri)
                            )
                        )
                    } else {
                        result.success(null)
                    }
                }

                "readDocument",
                "readPdf" -> {
                    try {
                        val uriString = call.argument<String>("uri")

                        if (uriString.isNullOrEmpty()) {
                            result.error(
                                "INVALID_URI",
                                "Document URI is missing.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val uri = Uri.parse(uriString)

                        val bytes = contentResolver
                            .openInputStream(uri)
                            ?.use { it.readBytes() }

                        if (bytes == null) {
                            result.error(
                                "READ_ERROR",
                                "Unable to read document.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        result.success(
                            mapOf(
                                "bytes" to bytes,
                                "fileName" to getFileName(uri)
                            )
                        )
                    } catch (e: Exception) {
                        result.error(
                            "READ_ERROR",
                            e.message ?: "Failed to read document.",
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun setupOfficeRendererChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OFFICE_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "convertOfficeToPdf" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")

                    if (inputPath.isNullOrEmpty() || outputPath.isNullOrEmpty()) {
                        result.error(
                            "INVALID_ARGUMENT",
                            "Input or output path is missing.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    result.error(
                        "OFFICE_ENGINE_NOT_INSTALLED",
                        "Android Office rendering engine is not installed.",
                        null
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val uri = getDocumentUri(intent)

        if (uri != null) {
            sendDocumentToFlutter(uri)
        }
    }

    private fun sendDocumentToFlutter(uri: Uri) {
        val engine = flutterEngine ?: return

        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            PDF_CHANNEL
        ).invokeMethod(
            "newDocument",
            mapOf(
                "uri" to uri.toString(),
                "fileName" to getFileName(uri)
            )
        )
    }

    private fun getDocumentUri(intent: Intent?): Uri? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_VIEW) return null

        val uri = intent.data ?: return null

        return if (isSupportedDocument(intent, uri)) uri else null
    }

    private fun isSupportedDocument(
        intent: Intent,
        uri: Uri
    ): Boolean {

        val mimeType = intent.type?.lowercase()

        if (mimeType != null) {
            if (
                mimeType.contains("pdf") ||
                mimeType.contains("wordprocessingml") ||
                mimeType.contains("msword") ||
                mimeType.contains("presentationml") ||
                mimeType.contains("ms-powerpoint")
            ) {
                return true
            }
        }

        val uriString = uri.toString().lowercase()

        return uriString.endsWith(".pdf") ||
                uriString.endsWith(".docx") ||
                uriString.endsWith(".pptx") ||
                uriString.endsWith(".doc") ||
                uriString.endsWith(".ppt") ||
                uriString.contains(".pdf?") ||
                uriString.contains(".docx?") ||
                uriString.contains(".pptx?")
    }

    private fun getFileName(uri: Uri): String {

        var fileName: String? = null

        if (uri.scheme == "content") {
            try {
                val cursor = contentResolver.query(
                    uri,
                    arrayOf("_display_name"),
                    null,
                    null,
                    null
                )

                cursor?.use {
                    if (it.moveToFirst()) {
                        val index = it.getColumnIndex("_display_name")

                        if (index >= 0) {
                            fileName = it.getString(index)
                        }
                    }
                }
            } catch (_: Exception) {
            }
        }

        if (fileName.isNullOrEmpty() && uri.scheme == "file") {
            fileName = uri.lastPathSegment
        }

        if (fileName.isNullOrEmpty()) {
            val uriString = uri.toString().lowercase()

            fileName = when {
                uriString.contains("docx") ||
                        uriString.contains("word") ->
                    "Imported_Document.docx"

                uriString.contains("pptx") ||
                        uriString.contains("powerpoint") ||
                        uriString.contains("presentation") ->
                    "Imported_Presentation.pptx"

                else ->
                    "Imported_Document.pdf"
            }
        }

        return fileName!!
    }
}