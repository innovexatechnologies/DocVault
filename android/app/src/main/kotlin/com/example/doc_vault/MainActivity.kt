package com.example.doc_vault

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {

    companion object {
        private const val DOCUMENT_CHANNEL = "docvault/pdf_intent"
        private const val CODE_SCANNER_CHANNEL = "docvault/code_scanner"
    }

    private var methodChannel: MethodChannel? = null
    private var codeScannerChannel: MethodChannel? = null
    private var pendingDocumentUri: Uri? = null

    // =========================================================================
    // FLUTTER ENGINE
    // =========================================================================

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOCUMENT_CHANNEL
        )

        codeScannerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CODE_SCANNER_CHANNEL
        )

        setupDocumentChannel()
        setupCodeScannerChannel()

        // Save initial incoming document.
        pendingDocumentUri = getDocumentUri(intent)
    }

    // =========================================================================
    // GOOGLE CODE SCANNER (barcode / QR)
    // =========================================================================
    // Wraps com.google.mlkit.vision.codescanner.GmsBarcodeScanning, the
    // Google Play services "code scanner" API. It owns its own camera UI and
    // never requires the CAMERA permission from this app.
    // https://developers.google.com/ml-kit/vision/barcode-scanning/code-scanner

    private fun setupCodeScannerChannel() {

        codeScannerChannel?.setMethodCallHandler { call, result ->

            when (call.method) {

                "startScan" -> {

                    try {

                        val requestedFormats =
                            call.argument<List<String>>("formats")

                        val enableAutoZoom =
                            call.argument<Boolean>("enableAutoZoom")
                                ?: true

                        startCodeScan(
                            requestedFormats,
                            enableAutoZoom,
                            result
                        )

                    } catch (e: Exception) {

                        result.error(
                            "CODE_SCANNER_START_FAILED",
                            e.message
                                ?: "Unable to start the code scanner.",
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

    private fun startCodeScan(
        requestedFormats: List<String>?,
        enableAutoZoom: Boolean,
        result: MethodChannel.Result
    ) {

        val formatInts =
            requestedFormats
                ?.mapNotNull { barcodeFormatFromName(it) }
                ?.takeIf { it.isNotEmpty() }
                ?.toIntArray()

        val optionsBuilder =
            GmsBarcodeScannerOptions.Builder()

        if (formatInts != null && formatInts.isNotEmpty()) {

            optionsBuilder.setBarcodeFormats(
                formatInts[0],
                *formatInts.drop(1).toIntArray()
            )
        }

        if (enableAutoZoom) {
            optionsBuilder.enableAutoZoom()
        }

        val scanner =
            GmsBarcodeScanning.getClient(
                this,
                optionsBuilder.build()
            )

        scanner.startScan()
            .addOnSuccessListener { barcode ->
                result.success(barcodeToMap(barcode))
            }
            .addOnCanceledListener {
                // User backed out of the scanner -- not an error.
                result.success(
                    mapOf("cancelled" to true)
                )
            }
            .addOnFailureListener { e ->
                result.error(
                    "CODE_SCANNER_FAILED",
                    e.message
                        ?: "Code scanning failed.",
                    e.javaClass.simpleName
                )
            }
    }

    // =========================================================================
    // BARCODE -> MAP
    // =========================================================================

    private fun barcodeToMap(
        barcode: Barcode
    ): Map<String, Any?> {

        val details = mutableMapOf<String, Any?>()

        barcode.url?.let {
            details["url"] = it.url
            details["title"] = it.title
        }

        barcode.email?.let {
            details["address"] = it.address
            details["subject"] = it.subject
            details["body"] = it.body
        }

        barcode.phone?.let {
            details["number"] = it.number
        }

        barcode.sms?.let {
            details["phoneNumber"] = it.phoneNumber
            details["message"] = it.message
        }

        barcode.wifi?.let {
            details["ssid"] = it.ssid
            details["password"] = it.password
            details["encryptionType"] = it.encryptionType
        }

        return mapOf(
            "cancelled" to false,
            "rawValue" to barcode.rawValue,
            "displayValue" to barcode.displayValue,
            "format" to barcodeFormatToName(barcode.format),
            "valueType" to barcodeValueTypeToName(barcode.valueType),
            "details" to details
        )
    }

    private fun barcodeFormatFromName(
        name: String
    ): Int? = when (name.uppercase()) {
        "CODE_128" -> Barcode.FORMAT_CODE_128
        "CODE_39" -> Barcode.FORMAT_CODE_39
        "CODE_93" -> Barcode.FORMAT_CODE_93
        "CODABAR" -> Barcode.FORMAT_CODABAR
        "DATA_MATRIX" -> Barcode.FORMAT_DATA_MATRIX
        "EAN_13" -> Barcode.FORMAT_EAN_13
        "EAN_8" -> Barcode.FORMAT_EAN_8
        "ITF" -> Barcode.FORMAT_ITF
        "QR_CODE" -> Barcode.FORMAT_QR_CODE
        "UPC_A" -> Barcode.FORMAT_UPC_A
        "UPC_E" -> Barcode.FORMAT_UPC_E
        "PDF417" -> Barcode.FORMAT_PDF417
        "AZTEC" -> Barcode.FORMAT_AZTEC
        "ALL_FORMATS" -> Barcode.FORMAT_ALL_FORMATS
        else -> null
    }

    private fun barcodeFormatToName(
        format: Int
    ): String = when (format) {
        Barcode.FORMAT_CODE_128 -> "CODE_128"
        Barcode.FORMAT_CODE_39 -> "CODE_39"
        Barcode.FORMAT_CODE_93 -> "CODE_93"
        Barcode.FORMAT_CODABAR -> "CODABAR"
        Barcode.FORMAT_DATA_MATRIX -> "DATA_MATRIX"
        Barcode.FORMAT_EAN_13 -> "EAN_13"
        Barcode.FORMAT_EAN_8 -> "EAN_8"
        Barcode.FORMAT_ITF -> "ITF"
        Barcode.FORMAT_QR_CODE -> "QR_CODE"
        Barcode.FORMAT_UPC_A -> "UPC_A"
        Barcode.FORMAT_UPC_E -> "UPC_E"
        Barcode.FORMAT_PDF417 -> "PDF417"
        Barcode.FORMAT_AZTEC -> "AZTEC"
        else -> "UNKNOWN"
    }

    private fun barcodeValueTypeToName(
        valueType: Int
    ): String = when (valueType) {
        Barcode.TYPE_CONTACT_INFO -> "CONTACT_INFO"
        Barcode.TYPE_EMAIL -> "EMAIL"
        Barcode.TYPE_ISBN -> "ISBN"
        Barcode.TYPE_PHONE -> "PHONE"
        Barcode.TYPE_PRODUCT -> "PRODUCT"
        Barcode.TYPE_SMS -> "SMS"
        Barcode.TYPE_TEXT -> "TEXT"
        Barcode.TYPE_URL -> "URL"
        Barcode.TYPE_WIFI -> "WIFI"
        Barcode.TYPE_GEO -> "GEO"
        Barcode.TYPE_CALENDAR_EVENT -> "CALENDAR_EVENT"
        Barcode.TYPE_DRIVER_LICENSE -> "DRIVER_LICENSE"
        else -> "UNKNOWN"
    }

    // =========================================================================
    // DOCUMENT CHANNEL
    // =========================================================================

    private fun setupDocumentChannel() {

        methodChannel?.setMethodCallHandler { call, result ->

            when (call.method) {

                // =============================================================
                // GET INITIAL EXTERNAL DOCUMENT
                // =============================================================

                "getInitialDocument",
                "getInitialPdf" -> {

                    try {

                        val uri = pendingDocumentUri
                            ?: getDocumentUri(intent)

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
                // READ DOCUMENT
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

                        if (
                            bytes == null ||
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
    // NEW INTENT
    // =========================================================================

    override fun onNewIntent(
        intent: Intent
    ) {
        super.onNewIntent(intent)

        setIntent(intent)

        val uri =
            getDocumentUri(intent)

        if (uri != null) {

            pendingDocumentUri = uri

            sendDocumentToFlutter(uri)
        }
    }

    // =========================================================================
    // SEND DOCUMENT TO FLUTTER
    // =========================================================================

    private fun sendDocumentToFlutter(
        uri: Uri
    ) {

        methodChannel?.invokeMethod(
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

        var uri: Uri? = null

        when (currentIntent.action) {

            // =============================================================
            // OPEN WITH
            // =============================================================

            Intent.ACTION_VIEW -> {
                uri = currentIntent.data
            }

            // =============================================================
            // SHARE DOCUMENT
            // =============================================================

            Intent.ACTION_SEND -> {

                uri =
                    if (android.os.Build.VERSION.SDK_INT >=
                        android.os.Build.VERSION_CODES.TIRAMISU
                    ) {

                        currentIntent.getParcelableExtra(
                            Intent.EXTRA_STREAM,
                            Uri::class.java
                        )

                    } else {

                        @Suppress("DEPRECATION")
                        currentIntent.getParcelableExtra(
                            Intent.EXTRA_STREAM
                        )
                    }
            }
        }

        if (uri == null) {
            return null
        }

        if (!isSupportedDocument(uri)) {
            return null
        }

        // Try to persist permission.
        if (
            uri.scheme.equals(
                "content",
                ignoreCase = true
            )
        ) {

            try {

                val takeFlags =
                    currentIntent.flags and
                        (
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        )

                if (takeFlags != 0) {

                    contentResolver
                        .takePersistableUriPermission(
                            uri,
                            takeFlags
                        )
                }

            } catch (_: Exception) {
                // Temporary permission is usually enough.
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
            fileName.endsWith(".doc") ||
            fileName.endsWith(".docx") ||
            fileName.endsWith(".ppt") ||
            fileName.endsWith(".pptx")
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

        return mimeType == "application/pdf" ||
                mimeType == "application/msword" ||
                mimeType == "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ||
                mimeType == "application/vnd.ms-powerpoint" ||
                mimeType == "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    }

    // =========================================================================
    // READ DOCUMENT BYTES
    // =========================================================================

    private fun readDocumentBytes(
        uri: Uri
    ): ByteArray? {

        return try {

            when (
                uri.scheme?.lowercase()
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
                        File(path)

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
                // Continue.
            }
        }

        if (
            uri.scheme.equals(
                "file",
                ignoreCase = true
            )
        ) {

            val path = uri.path

            if (!path.isNullOrBlank()) {

                val fileName =
                    File(path).name

                if (fileName.isNotBlank()) {
                    return fileName
                }
            }
        }

        val lastSegment =
            uri.lastPathSegment

        if (!lastSegment.isNullOrBlank()) {

            try {

                val decoded =
                    Uri.decode(lastSegment)

                if (decoded.isNotBlank()) {
                    return decoded
                }

            } catch (_: Exception) {
                // Continue.
            }
        }

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
            // Extension fallback.
        }

        val lowerName =
            fileName.lowercase()

        return when {

            lowerName.endsWith(".pdf") ->
                "application/pdf"

            lowerName.endsWith(".doc") ->
                "application/msword"

            lowerName.endsWith(".docx") ->
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

            lowerName.endsWith(".ppt") ->
                "application/vnd.ms-powerpoint"

            lowerName.endsWith(".pptx") ->
                "application/vnd.openxmlformats-officedocument.presentationml.presentation"

            else ->
                "application/octet-stream"
        }
    }
}