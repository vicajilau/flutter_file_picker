package com.mr.flutter.plugin.filepicker

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.mr.flutter.plugin.filepicker.FileUtils.maybeRenameGenericMimeDuplicate
import com.mr.flutter.plugin.filepicker.FileUtils.processFiles
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class FilePickerDelegate(
    val activity: Activity,
    var pendingResult: MethodChannel.Result? = null
) : ActivityResultListener {

    companion object {
        const val TAG = "FilePickerDelegate"
        const val REQUEST_CODE = 0x4F50
        const val SAVE_FILE_CODE = 0x4F51

        fun finishWithAlreadyActiveError(result: MethodChannel.Result) {
            result.error("already_active", "File picker is already active", null)
        }
    }

    var isMultipleSelection = false
    var type: String? = null
    var compressionQuality = 0
    var allowedExtensions: ArrayList<String>? = null
    var eventSink: EventSink? = null
    var bytes: ByteArray? = null
    var saveFileName: String? = null
    var saveMimeType: String? = null
    var androidSafOptions: java.util.HashMap<*, *>? = null

    fun setEventHandler(eventSink: EventSink?) {
        this.eventSink = eventSink
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return when (requestCode) {
            SAVE_FILE_CODE -> handleSaveFileResult(resultCode, data)
            REQUEST_CODE -> {
                if (pendingResult == null && !restoreLostRequest()) {
                    false
                } else {
                    handleFilePickerResult(resultCode, data)
                }
            }
            // Results of activities this plugin did not start, such as
            // those of other plugins, are not ours to answer.
            else -> false
        }
    }

    private fun handleSaveFileResult(resultCode: Int, data: Intent?): Boolean {
        val uri = data?.data
        when (ResultOutcome.of(resultCode, hasData = uri != null)) {
            ResultOutcome.DELIVER -> saveFile(uri!!)
            ResultOutcome.CANCEL -> finishWithSuccess(null)
            ResultOutcome.FAIL -> finishWithError(
                "unknown_result",
                "The save dialog ended without a location, with result code $resultCode."
            )
        }
        return true
    }

    private fun saveFile(uri: Uri) {
        dispatchEventStatus(true)
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val savedUri = FileUtils.writeBytesData(context = activity, uri, bytes) ?: uri
                val renamedUri = maybeRenameGenericMimeDuplicate(
                    context = activity,
                    uri = savedUri,
                    originalFileName = saveFileName,
                    mimeType = saveMimeType
                )
                Handler(Looper.getMainLooper()).post {
                    finishWithSuccess(renamedUri.path)
                }
            } catch (e: Exception) {
                // Not only IOException: a SecurityException from the provider
                // would otherwise escape the coroutine and crash the app.
                Log.e(TAG, "Error while saving file", e)
                Handler(Looper.getMainLooper()).post {
                    finishWithError("Error while saving file", e.message)
                }
            }
        }
    }

    private fun handleFilePickerResult(resultCode: Int, data: Intent?): Boolean {
        when (ResultOutcome.of(resultCode)) {
            ResultOutcome.DELIVER -> {
                dispatchEventStatus(true)
                processFiles(activity, data, compressionQuality, type.orEmpty(), androidSafOptions)
            }

            ResultOutcome.CANCEL -> finishWithSuccess(null)
            ResultOutcome.FAIL -> finishWithError(
                "unknown_result",
                "The picker ended with result code $resultCode."
            )
        }
        return true
    }

    /**
     * Restores the options of a request whose activity was destroyed while the
     * picker was open. Returns `false` when there is nothing to restore.
     */
    private fun restoreLostRequest(): Boolean {
        val request = LostDataStore.beginRestore(activity.applicationContext) ?: return false
        type = request.type
        compressionQuality = request.compressionQuality
        androidSafOptions = request.androidSafOptions
        return true
    }

    fun setPendingMethodCallResult(result: MethodChannel.Result): Boolean {
        return if (pendingResult == null) {
            pendingResult = result
            true
        } else {
            false
        }
    }

    fun finishWithSuccess(data: Any?) {
        dispatchEventStatus(false)
        val context = activity.applicationContext
        if (isLostResult()) {
            val files = (data as? ArrayList<*>)?.filterIsInstance<FileInfo>()
            LostDataStore.finishRestore(context, files)
            return
        }
        LostDataStore.clearRequest(context)
        pendingResult?.let {
            it.success(data?.takeIf { it is String }
                ?: (data as? ArrayList<*>)?.mapNotNull { (it as? FileInfo)?.toMap() })
            clearPendingResult()
        }
    }

    fun finishWithError(errorCode: String, errorMessage: String?) {
        dispatchEventStatus(false)
        val context = activity.applicationContext
        if (isLostResult()) {
            LostDataStore.finishRestoreWithError(context, errorCode, errorMessage)
            return
        }
        LostDataStore.clearRequest(context)
        pendingResult?.error(errorCode, errorMessage, null)
        clearPendingResult()
    }

    private fun dispatchEventStatus(status: Boolean) {
        if (eventSink != null && type != "dir") {
            Handler(Looper.getMainLooper()).post { eventSink?.success(status) }
        }
    }

    /**
     * Whether the result being finished belongs to a restored request, whose
     * outcome goes to LostDataStore instead of a pending method call.
     */
    private fun isLostResult(): Boolean = pendingResult == null && LostDataStore.isRestoring

    private fun clearPendingResult() {
        pendingResult = null
        // The delegate outlives each export; release the complete byte payload.
        bytes = null
        saveFileName = null
        saveMimeType = null
    }
}