package com.example.doc_vault

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "docvault/pdf_intent"

    private var pendingPdfUri: Uri? = null

    // ============================================================
    // ACTIVITY CREATED
    // ============================================================

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        pendingPdfUri = getPdfUri(intent)
    }

    // ============================================================
    // FLUTTER ENGINE
    // ============================================================

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // ====================================================
                // APP CLOSED → OPEN PDF
                // ====================================================

                "getInitialPdf" -> {

                    val uri =
                        pendingPdfUri
                            ?: getPdfUri(intent)

                    if (uri != null) {

                        result.success(
                            mapOf(
                                "uri" to uri.toString(),
                                "fileName" to getFileName(uri)
                            )
                        )

                        pendingPdfUri = null

                    } else {

                        result.success(null)
                    }
                }

                // ====================================================
                // READ EXTERNAL PDF
                // ====================================================

                "readPdf" -> {

                    try {

                        val uriString =
                            call.argument<String>("uri")

                        if (uriString.isNullOrEmpty()) {

                            result.error(
                                "INVALID_URI",
                                "PDF URI is missing.",
                                null
                            )

                            return@setMethodCallHandler
                        }

                        val uri =
                            Uri.parse(uriString)

                        val bytes =
                            contentResolver
                                .openInputStream(uri)
                                ?.use { inputStream ->
                                    inputStream.readBytes()
                                }

                        if (bytes == null) {

                            result.error(
                                "READ_ERROR",
                                "Unable to read PDF.",
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
                            e.message
                                ?: "Failed to read PDF.",
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

    // ============================================================
    // APP ALREADY OPEN → NEW PDF
    // ============================================================

    override fun onNewIntent(
        intent: Intent
    ) {
        super.onNewIntent(intent)

        setIntent(intent)

        val uri =
            getPdfUri(intent)

        if (uri != null) {
            sendPdfToFlutter(uri)
        }
    }

    // ============================================================
    // SEND PDF TO FLUTTER
    // ============================================================

    private fun sendPdfToFlutter(
        uri: Uri
    ) {

        val engine =
            flutterEngine ?: return

        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            CHANNEL
        ).invokeMethod(
            "newPdf",
            mapOf(
                "uri" to uri.toString(),
                "fileName" to getFileName(uri)
            )
        )
    }

    // ============================================================
    // GET PDF URI
    // ============================================================

    private fun getPdfUri(
        intent: Intent?
    ): Uri? {

        if (intent == null) {
            return null
        }

        if (intent.action != Intent.ACTION_VIEW) {
            return null
        }

        val uri =
            intent.data ?: return null

        return if (isPdf(intent, uri)) {
            uri
        } else {
            null
        }
    }

    // ============================================================
    // CHECK PDF
    // ============================================================

    private fun isPdf(
        intent: Intent,
        uri: Uri
    ): Boolean {

        val mimeType =
            intent.type

        if (mimeType.equals(
                "application/pdf",
                ignoreCase = true
            )
        ) {
            return true
        }

        val uriString =
            uri.toString().lowercase()

        return uriString.endsWith(".pdf") ||
                uriString.contains(".pdf?")
    }

    // ============================================================
    // GET FILE NAME
    // ============================================================

    private fun getFileName(
        uri: Uri
    ): String {

        var fileName: String? = null

        if (uri.scheme == "content") {

            try {

                val cursor =
                    contentResolver.query(
                        uri,
                        arrayOf("_display_name"),
                        null,
                        null,
                        null
                    )

                cursor?.use {

                    if (it.moveToFirst()) {

                        val index =
                            it.getColumnIndex(
                                "_display_name"
                            )

                        if (index >= 0) {
                            fileName =
                                it.getString(index)
                        }
                    }
                }

            } catch (_: Exception) {
                // Fallback below.
            }
        }

        if (fileName.isNullOrEmpty() &&
            uri.scheme == "file"
        ) {
            fileName =
                uri.lastPathSegment
        }

        if (fileName.isNullOrEmpty()) {
            fileName =
                "Imported_PDF.pdf"
        }

        if (!fileName!!
                .lowercase()
                .endsWith(".pdf")
        ) {
            fileName =
                "$fileName.pdf"
        }

        return fileName!!
    }
}