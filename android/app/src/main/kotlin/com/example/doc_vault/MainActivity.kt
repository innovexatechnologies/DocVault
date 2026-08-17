package com.example.doc_vault

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "docvault/pdf_intent"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "getInitialPdf" -> {
                    val uri = getPdfUri(intent)

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

                "readPdf" -> {
                    try {
                        val uriString = call.argument<String>("uri")

                        if (uriString.isNullOrEmpty()) {
                            result.error(
                                "INVALID_URI",
                                "PDF URI is missing.",
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
                            e.message ?: "Failed to read PDF.",
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

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        setIntent(intent)

        val uri = getPdfUri(intent)

        if (uri != null) {
            MethodChannel(
                flutterEngine!!.dartExecutor.binaryMessenger,
                CHANNEL
            ).invokeMethod(
                "newPdf",
                mapOf(
                    "uri" to uri.toString(),
                    "fileName" to getFileName(uri)
                )
            )
        }
    }

    private fun getPdfUri(intent: Intent?): Uri? {

        if (intent == null) {
            return null
        }

        if (intent.action == Intent.ACTION_VIEW) {

            val uri = intent.data

            if (uri != null && isPdf(intent, uri)) {
                return uri
            }
        }

        return null
    }

    private fun isPdf(
        intent: Intent,
        uri: Uri
    ): Boolean {

        val mimeType = intent.type

        return mimeType == "application/pdf" ||
                uri.toString()
                    .lowercase()
                    .contains(".pdf")
    }

    private fun getFileName(uri: Uri): String {

        var fileName: String? = null

        if (uri.scheme == "content") {

            val cursor = contentResolver.query(
                uri,
                arrayOf("_display_name"),
                null,
                null,
                null
            )

            cursor?.use {
                if (it.moveToFirst()) {

                    val index =
                        it.getColumnIndex("_display_name")

                    if (index >= 0) {
                        fileName = it.getString(index)
                    }
                }
            }
        }

        if (fileName.isNullOrEmpty()) {
            fileName = "Imported_PDF.pdf"
        }

        return fileName!!
    }
}