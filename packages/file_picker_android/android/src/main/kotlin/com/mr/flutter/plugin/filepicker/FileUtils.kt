package com.mr.flutter.plugin.filepicker

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Parcelable
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.net.toUri
import com.mr.flutter.plugin.filepicker.FilePickerDelegate.Companion.REQUEST_CODE
import com.mr.flutter.plugin.filepicker.FilePickerDelegate.Companion.SAVE_FILE_CODE
import com.mr.flutter.plugin.filepicker.FilePickerDelegate.Companion.finishWithAlreadyActiveError
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.BufferedOutputStream
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.URLConnection
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object FileUtils {
    private const val TAG = "FilePickerUtils"
    private const val MAX_RENAME_ATTEMPTS = 20
    // On Android, the CSV mime type from getMimeTypeFromExtension() returns
    // "text/comma-separated-values" which is non-standard and doesn't filter
    // CSV files in Google Drive.
    // (see https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types/Common_types)
    // (see https://android.googlesource.com/platform/frameworks/base/+/61ae88e/core/java/android/webkit/MimeTypeMap.java#439)
    private const val CSV_EXTENSION = "csv"
    private const val CSV_MIME_TYPE = "text/csv"
    // Fallback MIME type used when neither the file name extension nor
    // content sniffing can determine a type, matching the value used by
    // most content-detection libraries for
    // unrecognized binary content.
    private const val DEFAULT_MIME_TYPE = "application/octet-stream"
    // Maximum dimension (width or height) allowed when decoding an image for
    // compression. Images larger than this are subsampled via
    // BitmapFactory.Options.inSampleSize to avoid excessive memory usage
    // (see https://developer.android.com/topic/performance/graphics/load-bitmap).
    // 4096 matches the common GPU texture size limit, so regular photos are
    // decoded at full resolution and only unusually large images are downscaled.
    private const val MAX_COMPRESSED_IMAGE_DIMENSION = 4096

    fun FilePickerDelegate.processFiles(
        activity: Activity,
        data: Intent?,
        compressionQuality: Int,
        type: String,
        androidSafOptions: java.util.HashMap<*, *>?
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            if (data == null) {
                finishWithError("unknown_activity", "Unknown activity error, please fill an issue.")
                return@launch
            }

            val grantStr = androidSafOptions?.get("grant") as? String
            val accessStr = androidSafOptions?.get("access") as? String
            val autoPersist = (androidSafOptions?.get("autoPersist") as? Boolean) ?: true
            
            val isPersist = grantStr == "lifetime"
            val isReadWrite = accessStr == "readWrite"

            val hasSafOptions = androidSafOptions != null

            fun maybeTakePersistableUriPermission(uri: Uri) {
                 if (isPersist && autoPersist) {
                     try {
                         val flags = if (isReadWrite) {
                            android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION or android.content.Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                         } else {
                            android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                         }
                         activity.contentResolver.takePersistableUriPermission(uri, flags)
                     } catch (e: SecurityException) {
                         Log.e(TAG, "Failed to take persistable URI permission for $uri", e)
                     }
                 }
            }

            val files = mutableListOf<FileInfo>()

            try {
                when {
                    data.clipData != null -> {
                        for (i in 0 until data.clipData!!.itemCount) {
                            var uri = data.clipData!!.getItemAt(i).uri
                            maybeTakePersistableUriPermission(uri)
                            uri = processUri(activity, uri, compressionQuality)
                            addFile(activity, uri, files, hasSafOptions, isReadWrite)
                        }
                        finishWithSuccess(files)
                    }

                    data.data != null -> {
                        var uri = processUri(activity, data.data!!, compressionQuality)

                        if (type == "dir") {
                            maybeTakePersistableUriPermission(data.data!!)
                            if (androidSafOptions != null) {
                                finishWithSuccess(data.data!!.toString())
                            } else {
                                uri = DocumentsContract.buildDocumentUriUsingTree(
                                    uri,
                                    DocumentsContract.getTreeDocumentId(uri)
                                )
                                val dirPath = getFullPathFromTreeUri(uri, activity)
                                if (dirPath != null) {
                                    finishWithSuccess(dirPath)
                                } else {
                                    finishWithError("unknown_path", "Failed to retrieve directory path.")
                                }
                            }
                        } else {
                            maybeTakePersistableUriPermission(data.data!!)
                            addFile(activity, uri, files, hasSafOptions, isReadWrite)
                            handleFileResult(files)
                        }
                    }

                    data.extras?.containsKey("selectedItems") == true -> {
                        val fileUris = getSelectedItems(data.extras!!)
                        fileUris?.filterIsInstance<Uri>()?.forEach { uri ->
                            maybeTakePersistableUriPermission(uri)
                            addFile(activity, uri, files, hasSafOptions, isReadWrite)
                        }
                        finishWithSuccess(files)
                    }

                    else -> finishWithError(
                        "unknown_activity",
                        "Unknown activity error, please fill an issue."
                    )
                }
            } catch (oom: OutOfMemoryError) {
                Log.e(TAG, "Out of memory while processing selected files.", oom)
                finishWithError(
                    "out_of_memory",
                    "Selected files are too large to process."
                )
            } catch (e: Exception) {
                finishWithError("file_picker_error", e.message ?: "Unknown error")
            }
        }
    }

    fun writeBytesData(
        context: Context,
        uri: Uri,
        bytes: ByteArray?
    ): Uri {
        context.contentResolver.openOutputStream(uri)?.use { output ->
            bytes?.let {
                output.write(it)
            }
        }

        return uri
    }

    private fun FilePickerDelegate.handleFileResult(files: List<FileInfo>) {
        if (files.isNotEmpty()) {
            finishWithSuccess(files)
        } else {
            finishWithError("unknown_path", "Failed to retrieve path.")
        }
    }

    /**
     * Creates and launches an intent for the given file type.
     *
     * This method is responsible for creating the appropriate intent based on the type of file
     * that is requested to be picked.
     *
     * This may be either a directory, a regular file, or a gallery pick.
     */
    fun FilePickerDelegate.startFileExplorer() {
        val intent: Intent

        // Temporary fix, remove this null-check after Flutter Engine 1.14 has landed on stable
        if (type == null) {
            return
        }

        if (type == "dir") {
            intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        } else {
            intent = when (type) {
                "image/*" -> Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = this@startFileExplorer.type
                    if (!allowedExtensions.isNullOrEmpty()) {
                        putExtra(Intent.EXTRA_MIME_TYPES, allowedExtensions!!.toTypedArray())
                    }
                }
                "audio/*" -> Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = this@startFileExplorer.type
                    addCategory(Intent.CATEGORY_OPENABLE)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val authority = "com.android.providers.media.documents"
                        val audioRootUri = DocumentsContract.buildRootUri(authority, "audio_root")
                        putExtra(DocumentsContract.EXTRA_INITIAL_URI, audioRootUri)
                    }
                }
                "video/*" -> Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = this@startFileExplorer.type
                    addCategory(Intent.CATEGORY_OPENABLE)
                }
                "media" -> Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*", "audio/*"))
                    addCategory(Intent.CATEGORY_OPENABLE)
                }
                else -> Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = this@startFileExplorer.type
                    if (!allowedExtensions.isNullOrEmpty()) {
                        putExtra(Intent.EXTRA_MIME_TYPES, allowedExtensions!!.toTypedArray())
                    } else {
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(type))
                    }
                }
            }.apply {
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, isMultipleSelection)
                putExtra("multi-pick", isMultipleSelection)
            }
        }
        if (intent.resolveActivity(activity.packageManager) != null) {
            activity.startActivityForResult(intent, REQUEST_CODE)
        } else {
            Log.e(
                FilePickerDelegate.TAG,
                "Can't find a valid activity to handle the request. Make sure you've a file explorer installed."
            )
            finishWithError("explorer_not_found", "Can't find a valid activity to handle the request. Make sure you have a file explorer installed.")
        }
    }

    /**
     * Called by the plugin to start a new file explorer activity.
     *
     * @param type The file types that will be selectable.
     * @param isMultipleSelection Whether multiple files can be selected.
     * @param allowedExtensions The allowed file extensions for custom file types.
     * @param compressionQuality The compression quality for images.
     * @param result The MethodChannel result to send the file picking result to.
     */
    fun FilePickerDelegate?.startFileExplorer(
        type: String?,
        isMultipleSelection: Boolean?,
        allowedExtensions: ArrayList<String>,
        compressionQuality: Int? = 0,
        androidSafOptions: java.util.HashMap<*, *>?,
        result: MethodChannel.Result
    ) {
        if (this?.setPendingMethodCallResult(result) == false) {
            finishWithAlreadyActiveError(result)
            return
        }
        this?.type = type
        if (isMultipleSelection != null) {
            this?.isMultipleSelection = isMultipleSelection
        }
        this?.allowedExtensions = allowedExtensions
        if (compressionQuality != null) {
            this?.compressionQuality = compressionQuality
        }
        this?.androidSafOptions = androidSafOptions

        this?.startFileExplorer()
    }

    fun getFileExtension(bytes: ByteArray?): String {
        val mimeType = guessMimeTypeFromBytes(bytes) ?: DEFAULT_MIME_TYPE
        return MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
            ?: mimeType.substringAfter("/")
    }

    private fun getMimeTypeForBytes(fileName: String?, bytes: ByteArray?): String {
        val extension = fileName?.substringAfterLast('.', "")
        if (!extension.isNullOrEmpty()) {
            if (extension.equals(CSV_EXTENSION, ignoreCase = true)) {
                return CSV_MIME_TYPE
            }
            MimeTypeMap.getSingleton()
                .getMimeTypeFromExtension(extension.lowercase(Locale.getDefault()))
                ?.let { return it }

            // The extension is unknown to the device's MimeTypeMap (e.g. a
            // niche format like .gpx). Falling through to content sniffing
            // here would sniff the underlying format rather than the
            // extension, e.g. a .gpx file is valid XML and sniffs as
            // text/xml, whose own registered default extension is .xml, not
            // .gpx. The system's "create document" picker honors that
            // declared type and "corrects" the suggested file name by
            // appending its own extension, corrupting the one the caller
            // asked for. A wildcard type has no default extension of its
            // own, so the picker leaves the requested name alone.
            return "*/*"
        }

        val detectedType = guessMimeTypeFromBytes(bytes)
        return if (detectedType == null || detectedType == "text/plain") {
            "*/*"
        } else {
            detectedType
        }
    }

    // Sniffs [bytes] for a MIME type using URLConnection's built-in magic-number
    // detection. This is a best-effort fallback for when the file name has no
    // usable extension.
    private fun guessMimeTypeFromBytes(bytes: ByteArray?): String? {
        if (bytes == null || bytes.isEmpty()) {
            return null
        }
        return try {
            ByteArrayInputStream(bytes).use { URLConnection.guessContentTypeFromStream(it) }
        } catch (e: IOException) {
            null
        }
    }

    fun FilePickerDelegate.saveFile(
        fileName: String?,
        type: String?,
        initialDirectory: String?,
        bytes: ByteArray?,
        result: MethodChannel.Result
    ) {
        if (!this.setPendingMethodCallResult(result)) {
            finishWithAlreadyActiveError(result)
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        if (!fileName.isNullOrEmpty()) {
            intent.putExtra(Intent.EXTRA_TITLE, fileName)
        }
        this.bytes = bytes
        this.saveFileName = fileName
        if ("dir" != type) {
            try {
                intent.type = getMimeTypeForBytes(fileName = fileName, bytes = bytes)
                this.saveMimeType = intent.type
            } catch (t: Throwable) {
                intent.type = "*/*"
                this.saveMimeType = intent.type
                Log.e(
                    FilePickerDelegate.TAG,
                    "Failed to detect mime type. $t"
                )
            }
        }
        if (!initialDirectory.isNullOrEmpty()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, initialDirectory.toUri())
            }
        }
        if (intent.resolveActivity(activity.packageManager) != null) {
            activity.startActivityForResult(intent, SAVE_FILE_CODE)
        } else {
            Log.e(
                FilePickerDelegate.TAG,
                "Can't find a valid activity to handle the request. Make sure you've a file explorer installed."
            )
            finishWithError("explorer_not_found", "Can't find a valid activity to handle the request. Make sure you have a file explorer installed.")
        }
    }

    fun maybeRenameGenericMimeDuplicate(
        context: Context,
        uri: Uri,
        originalFileName: String?,
        mimeType: String?
    ): Uri {
        if (originalFileName.isNullOrBlank()) {
            return uri
        }

        val extension = originalFileName.substringAfterLast('.', "")
        if (extension.isBlank()) {
            return uri
        }

        val currentName = getFileName(uri, context) ?: return uri
        val escapedExtension = Regex.escape(extension)

        var (baseName, suffix) = extractBaseNameAndSuffix(currentName, escapedExtension)

        // Clean up baseName if it already has one or more " (M)" suffixes to prevent nesting.
        val normalized = normalizeBaseNameAndSuffix(baseName, suffix)
        baseName = normalized.first
        suffix = normalized.second

        var finalUri = uri
        var success = false
        var currentSuffix = suffix ?: 0
        var attempts = 0

        while (!success && attempts < MAX_RENAME_ATTEMPTS) {
            val targetName = when {
                currentSuffix > 0 -> "$baseName ($currentSuffix).$extension"
                else -> "$baseName.$extension"
            }

            if (targetName == currentName && attempts == 0) {
                return uri
            }

            try {
                val newUri = DocumentsContract.renameDocument(context.contentResolver, finalUri, targetName)
                if (newUri != null) {
                    val actualName = getFileName(newUri, context)
                    if (actualName == targetName) {
                        finalUri = newUri
                        success = true
                    } else {
                        // The provider likely auto-suffixed because targetName exists (e.g., "file (1).ext" -> "file (1) (1).ext").
                        // Update finalUri and increment our suffix to try to find a "clean" one ourselves.
                        finalUri = newUri
                        currentSuffix++
                        attempts++
                    }
                } else {
                    currentSuffix++
                    attempts++
                }
            } catch (ex: Exception) {
                currentSuffix++
                attempts++
                if (attempts >= MAX_RENAME_ATTEMPTS) {
                    Log.w(
                        TAG,
                        "Failed to normalize saved document name from '$currentName' to '$targetName' after $MAX_RENAME_ATTEMPTS attempts. MIME=$mimeType, error=$ex"
                    )
                }
            }
        }

        return finalUri
    }

    private fun extractBaseNameAndSuffix(currentName: String, escapedExtension: String): Pair<String, Int?> {
        // Android duplicate style "name.ext (N)" that we normalize. Example: "report.pdf (1)"
        val androidCollisionRegex = Regex("^(.*)\\.$escapedExtension \\((\\d+)\\)$")
        // Desired style "name (N).ext"
        val normalizedCollisionRegex = Regex("^(.*) \\((\\d+)\\)\\.$escapedExtension$")
        // Regular "name.ext"
        val plainNameRegex = Regex("^(.*)\\.$escapedExtension$")
        // The system's document picker can append its own extension on top
        // of ours when the MIME type we declared doesn't match what it
        // expects for our extension (e.g. "trace.gpx" becoming
        // "trace.gpx.xml"). Detect our extension immediately followed by
        // exactly one more extension and strip both, recovering the true
        // base name, instead of leaving the mismatched extension in place
        // and appending ours on top of it (which would produce
        // "trace.gpx.xml.gpx").
        val systemAppendedExtensionRegex = Regex("^(.*)\\.$escapedExtension\\.[^./\\\\]+$")

        return when {
            androidCollisionRegex.matches(currentName) -> {
                val match = androidCollisionRegex.matchEntire(currentName)!!
                match.groupValues[1] to match.groupValues[2].toInt()
            }
            normalizedCollisionRegex.matches(currentName) -> {
                val match = normalizedCollisionRegex.matchEntire(currentName)!!
                match.groupValues[1] to match.groupValues[2].toInt()
            }
            plainNameRegex.matches(currentName) -> {
                val match = plainNameRegex.matchEntire(currentName)!!
                match.groupValues[1] to null
            }
            systemAppendedExtensionRegex.matches(currentName) -> {
                val match = systemAppendedExtensionRegex.matchEntire(currentName)!!
                match.groupValues[1] to null
            }
            else -> {
                currentName to null
            }
        }
    }

    private fun normalizeBaseNameAndSuffix(baseName: String, suffix: Int?): Pair<String, Int?> {
        var normalizedBaseName = baseName
        var normalizedSuffix = suffix
        // Trailing numeric suffix chunk "name (N)" we repeatedly strip and accumulate.
        // Example: "report (1)" -> base "report", suffix +1
        val baseNameSuffixRegex = Regex("^(.*) \\((\\d+)\\)$")

        while (true) {
            val baseMatch = baseNameSuffixRegex.matchEntire(normalizedBaseName) ?: break

            val realBase = baseMatch.groupValues[1]
            val baseSuffix = baseMatch.groupValues[2].toInt()
            normalizedBaseName = realBase
            normalizedSuffix = (normalizedSuffix ?: 0) + baseSuffix
        }

        return normalizedBaseName to normalizedSuffix
    }

    private fun processUri(activity: Activity, uri: Uri, compressionQuality: Int): Uri {
        return if (compressionQuality > 0 && isImage(activity.applicationContext, uri)) {
            compressImage(uri, compressionQuality, activity.applicationContext)
        } else {
            uri
        }
    }

    private fun addFile(
        activity: Activity,
        uri: Uri,
        files: MutableList<FileInfo>,
        hasSafOptions: Boolean = false,
        isReadWrite: Boolean = false
    ) {
        openFileStream(activity, uri, hasSafOptions, isReadWrite)?.let { file ->
            files.add(file)
        }
    }

    @Suppress("deprecation")
    private fun getSelectedItems(bundle: Bundle): ArrayList<Parcelable>? {
        if (Build.VERSION.SDK_INT >= 33) {
            return bundle.getParcelableArrayList("selectedItems", Parcelable::class.java)
        }

        return bundle.getParcelableArrayList("selectedItems")
    }

    fun getMimeTypes(allowedExtensions: ArrayList<String>?): ArrayList<String> {
        if (allowedExtensions.isNullOrEmpty()) {
            return ArrayList(listOf("*/*"))
        }

        val mimes = ArrayList<String>()

        for (i in allowedExtensions.indices) {
            val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(
                allowedExtensions[i]
            )
            if (mime == null) {
                Log.w(
                    TAG,
                    "Custom file type '" + allowedExtensions[i] + "' has no known mime type and will not be filtered by the system picker."
                )
                continue
            }

            mimes.add(mime)
            if(allowedExtensions[i] == CSV_EXTENSION) {
                // Add the standard CSV mime type.
                mimes.add(CSV_MIME_TYPE)
            }
        }

        if (mimes.isEmpty()) {
            Log.w(
                TAG,
                "None of the custom file types $allowedExtensions have a known mime type, falling back to */*."
            )
            return ArrayList(listOf("*/*"))
        }

        Log.d(
            TAG,
            "Custom file types are $allowedExtensions. The mime types were detected as $mimes."
        )
        return mimes
    }

    @JvmStatic
    fun getFileName(uri: Uri, context: Context): String? {
        var result: String? = null

        try {
            if (uri.scheme == "content") {
                context.contentResolver.query(
                    uri,
                    arrayOf(OpenableColumns.DISPLAY_NAME),
                    null,
                    null,
                    null
                ).use { cursor ->
                    if (cursor != null && cursor.moveToFirst()) {
                        result =
                            cursor.getString(cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME))
                    }
                }
            }
            if (result == null) {
                result = uri.path?.substringAfterLast('/')
            }
        } catch (ex: Exception) {
            Log.e(
                TAG,
                "Failed to handle file name: $ex"
            )
        }

        return result
    }

    @JvmStatic
    fun isImage(context: Context, uri: Uri): Boolean {
        val extension = getFileExtension(context, uri) ?: return false

        return extension.contentEquals("jpg") || extension.contentEquals("jpeg")
                || extension.contentEquals("png") || extension.contentEquals("webp")
                || extension.contentEquals("heic") || extension.contentEquals("heif")
    }

    private fun getFileExtension(context: Context, uri: Uri): String? {
        val contentResolver = context.contentResolver
        val mimeType = contentResolver.getType(uri)
        return MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
    }

    private fun getCompressFormat(context: Context, uri: Uri): Bitmap.CompressFormat {
        val format = getFileExtension(context, uri)
        return when (format!!.uppercase(Locale.getDefault())) {
            "PNG" -> Bitmap.CompressFormat.PNG
            "WEBP" -> Bitmap.CompressFormat.WEBP
            else -> Bitmap.CompressFormat.JPEG
        }
    }

    private fun getCompressFormatBasedFileExtension(format: Bitmap.CompressFormat): String {
        return when (format) {
            Bitmap.CompressFormat.PNG -> "png"
            Bitmap.CompressFormat.WEBP -> "webp"
            else -> "jpeg"
        }
    }

    @JvmStatic
    fun compressImage(originalImageUri: Uri, compressionQuality: Int, context: Context): Uri {
        val compressedUri: Uri
        try {
            // First pass: decode only the image bounds so a subsampling factor
            // can be computed without loading the full bitmap into memory.
            val boundsOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            context.contentResolver.openInputStream(originalImageUri).use { imageStream ->
                BitmapFactory.decodeStream(imageStream, null, boundsOptions)
            }
            val decodeOptions = BitmapFactory.Options().apply {
                inSampleSize = calculateInSampleSize(
                    boundsOptions,
                    MAX_COMPRESSED_IMAGE_DIMENSION,
                    MAX_COMPRESSED_IMAGE_DIMENSION
                )
            }
            context.contentResolver.openInputStream(originalImageUri).use { imageStream ->
                val compressFormat = getCompressFormat(context, originalImageUri)
                val compressedFile = createImageFile(context, compressFormat)
                val originalBitmap = BitmapFactory.decodeStream(imageStream, null, decodeOptions)
                    ?: throw IOException("Failed to decode image: $originalImageUri")
                // Compress and save the image
                val fileOutputStream = FileOutputStream(compressedFile)
                originalBitmap.compress(compressFormat, compressionQuality, fileOutputStream)
                fileOutputStream.flush()
                fileOutputStream.close()
                compressedUri = Uri.fromFile(compressedFile)
            }
        } catch (e: IOException) {
            throw RuntimeException(e)
        }
        return compressedUri
    }

    /**
     * Calculates the largest power-of-two [BitmapFactory.Options.inSampleSize]
     * that keeps both dimensions at least as large as the requested size, as
     * recommended by https://developer.android.com/topic/performance/graphics/load-bitmap.
     */
    private fun calculateInSampleSize(
        options: BitmapFactory.Options,
        reqWidth: Int,
        reqHeight: Int
    ): Int {
        val height = options.outHeight
        val width = options.outWidth
        var inSampleSize = 1
        if (height > reqHeight || width > reqWidth) {
            val halfHeight = height / 2
            val halfWidth = width / 2
            while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }

    @Throws(IOException::class)
    private fun createImageFile(context: Context, compressFormat: Bitmap.CompressFormat): File {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val imageFileName = "IMAGE_" + timeStamp + "_"
        val storageDir = context.cacheDir
        return File.createTempFile(imageFileName, "." + getCompressFormatBasedFileExtension(compressFormat), storageDir)
    }

    /**
     * @param uri The Uri to check.
     * @return Whether the Uri authority is DownloadsProvider.
     */
    private fun isDownloadsDocument(uri: Uri): Boolean {
        return uri.authority == "com.android.providers.downloads.documents"
    }

    @JvmStatic
    fun clearCache(context: Context): Boolean {
        try {
            val cacheDir = File(context.cacheDir.toString() + "/file_picker/")
            recursiveDeleteFile(cacheDir)
        } catch (ex: Exception) {
            Log.e(
                TAG,
                "There was an error while clearing cached files: $ex"
            )
            return false
        }
        return true
    }

    @JvmStatic
    fun openFileStream(
        context: Context,
        uri: Uri,
        hasSafOptions: Boolean = false,
        isReadWrite: Boolean = false
    ): FileInfo? {
        var fileInputStream: InputStream? = null
        var fileOutputStream: FileOutputStream? = null
        val fileInfo = FileInfo.Builder()
        val fileName = getFileName(uri, context)
        val path =
            context.cacheDir.absolutePath + "/file_picker/" + System.currentTimeMillis() + "/" + (fileName
                ?: "unamed")

        val file = File(path)
        
        val safeDir = File(context.cacheDir.absolutePath + "/file_picker/").canonicalPath
        if (!file.canonicalPath.startsWith(safeDir)) {
            throw SecurityException("Path traversal detected. Escaping the intended cache directory is not allowed.")
        }

        if (!file.exists()) {
            try {
                file.parentFile?.mkdirs()

                fileInputStream = context.contentResolver.openInputStream(uri)
                fileOutputStream = FileOutputStream(file)

                val out = BufferedOutputStream(fileOutputStream)
                val buffer = ByteArray(8192)
                var len: Int

                while ((fileInputStream!!.read(buffer).also { len = it }) >= 0) {
                    out.write(buffer, 0, len)
                }
                out.flush()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to retrieve and cache file: " + e.message, e)
                return null
            } finally {
                try {
                    fileOutputStream?.fd?.sync()
                    fileOutputStream?.close()
                    fileInputStream?.close()
                } catch (ex: IOException) {
                    Log.e(TAG, "Failed to close file streams: " + ex.message, ex)
                }
            }
        }

        fileInfo
            .withPath(path)
            .withName(fileName)
            .withUri(uri)
            .withSize(file.length())

        if (hasSafOptions) {
            val safHandleMap = java.util.HashMap<String, Any>()
            safHandleMap["uri"] = uri.toString()
            safHandleMap["access"] = if (isReadWrite) "readWrite" else "readOnly"
            fileInfo.withSafHandle(safHandleMap)
        }

        return fileInfo.build()
    }

    private fun getPathFromTreeUri(uri: Uri): String {
        val docId = DocumentsContract.getTreeDocumentId(uri)
        val parts = docId.split(":")

        // Check if the URI corresponds to external storage
        return if (parts.size > 1) {
            val volumeId = parts[0]
            val path = parts[1]

            // Map volume ID to external storage path
            if ("primary".equals(volumeId, ignoreCase = true)) {
                "${Environment.getExternalStorageDirectory()}/$path"
            } else {
                "/storage/$volumeId/$path"
            }
        } else {
            "${Environment.getExternalStorageDirectory()}/${parts.last()}"
        }
    }

    @JvmStatic
    fun getFullPathFromTreeUri(treeUri: Uri?, context: Context): String? {
        if (treeUri == null) {
            return null
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            if (isDownloadsDocument(treeUri)) {
                val docId = DocumentsContract.getDocumentId(treeUri)
                val extPath =
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).path
                if (docId == "downloads") {
                    return extPath
                } else if (docId.matches("^ms[df]:.*".toRegex())) {
                    // Handle "msf:" (Media Store File) and "msd:" (Media Store Directory) prefixes.
                    // These are commonly seen on Android 10+ (API 29+) when selecting files from the
                    // "Downloads" category in the system picker.
                    // Note that this does not happen on all devices.
                    // Example URI: content://com.android.providers.downloads.documents/document/msf:1000000033
                    val fileName = getFileName(treeUri, context)
                    return "$extPath/$fileName"
                } else if (docId.startsWith("raw:")) {
                    return docId.split(":".toRegex()).dropLastWhile { it.isEmpty() }
                        .toTypedArray()[1]
                }
                return null
            }
        }

        var volumePath = getPathFromTreeUri(treeUri)

        if (volumePath.endsWith(File.separator)) {
            volumePath = volumePath.dropLast(1)
        }

        var documentPath = getDocumentPathFromTreeUri(treeUri)

        if (documentPath.endsWith(File.separator)) {
            documentPath = documentPath.dropLast(1)
        }
        return if (documentPath.isNotEmpty()) {
            if (volumePath.endsWith(documentPath)) {
                volumePath
            } else {
                if (documentPath.startsWith(File.separator)) {
                    volumePath + documentPath
                } else {
                    volumePath + File.separator + documentPath
                }
            }
        } else {
            volumePath
        }
    }

    private fun getDocumentPathFromTreeUri(treeUri: Uri): String {
        val docId = DocumentsContract.getTreeDocumentId(treeUri)
        val split = docId.split(":".toRegex()).dropLastWhile { it.isEmpty() }.toTypedArray()
        return if ((split.size >= 2)) split[1]
        else File.separator
    }

    private fun recursiveDeleteFile(file: File?) {
        if (file == null || !file.exists()) {
            return
        }

        if (file.listFiles() != null && file.isDirectory) {
            for (child in file.listFiles().orEmpty()) {
                recursiveDeleteFile(child)
            }
        }

        file.delete()
    }
}