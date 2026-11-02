package com.mr.flutter.plugin.filepicker

import android.app.Activity
import android.app.Application
import android.os.Bundle
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.mr.flutter.plugin.filepicker.FileUtils.clearCache
import com.mr.flutter.plugin.filepicker.FileUtils.getFileExtension
import com.mr.flutter.plugin.filepicker.FileUtils.getMimeTypes
import com.mr.flutter.plugin.filepicker.FileUtils.saveFile
import com.mr.flutter.plugin.filepicker.FileUtils.startFileExplorer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

/**
 * FilePickerPlugin
 */
class FilePickerPlugin : FilePickerApi, FlutterPlugin,
    ActivityAware {

    companion object {
        private const val TAG = "FilePicker"
        private const val EVENT_CHANNEL = "miguelruivo.flutter.plugins.filepickerevent"
    }

    private inner class LifeCycleObserver
        (private val thisActivity: Activity) : Application.ActivityLifecycleCallbacks,
        DefaultLifecycleObserver {
        override fun onCreate(owner: LifecycleOwner) {
        }

        override fun onStart(owner: LifecycleOwner) {
        }

        override fun onResume(owner: LifecycleOwner) {
        }

        override fun onPause(owner: LifecycleOwner) {
        }

        override fun onStop(owner: LifecycleOwner) {
            this.onActivityStopped(this.thisActivity)
        }

        override fun onDestroy(owner: LifecycleOwner) {
            this.onActivityDestroyed(this.thisActivity)
        }

        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        }

        override fun onActivityStarted(activity: Activity) {
        }

        override fun onActivityResumed(activity: Activity) {
        }

        override fun onActivityPaused(activity: Activity) {
        }

        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {
        }

        override fun onActivityDestroyed(activity: Activity) {
            // Use getApplicationContext() to avoid casting failures
            if (this.thisActivity === activity && activity.applicationContext != null) {
                (activity.applicationContext as Application).unregisterActivityLifecycleCallbacks(
                    this
                )
            }
        }

        override fun onActivityStopped(activity: Activity) {
        }
    }

    private var activityBinding: ActivityPluginBinding? = null
    private var delegate: FilePickerDelegate? = null
    private var application: Application? = null
    private var pluginBinding: FlutterPluginBinding? = null

    private var lifecycle: Lifecycle? = null
    private var observer: LifeCycleObserver? = null
    private var activity: Activity? = null
    private var messenger: BinaryMessenger? = null

    /** The delegate of the foreground activity, or a `no_activity` error. */
    private fun requireDelegate(): FilePickerDelegate =
        delegate.takeIf { activity != null } ?: throw FilePickerFlutterError(
            "no_activity",
            "file picker plugin requires a foreground activity",
            null
        )

    /**
     * Runs [start] with the delegate, and answers [callback] with the error it
     * throws, since the generated handler does not catch it.
     */
    private fun <T> withDelegate(
        callback: (Result<T>) -> Unit,
        start: (FilePickerDelegate) -> Unit
    ) {
        val delegate = try {
            requireDelegate()
        } catch (e: FilePickerFlutterError) {
            callback(Result.failure(e))
            return
        }
        start(delegate)
    }

    override fun pickFiles(
        type: FileTypeMessage,
        allowMultiple: Boolean,
        allowedExtensions: List<String>,
        compressionQuality: Long,
        safOptions: SafOptionsMessage?,
        callback: (Result<List<PickedFileMessage>?>) -> Unit
    ) = withDelegate(callback) { delegate ->
        val mimeTypes = if (type == FileTypeMessage.CUSTOM) {
            getMimeTypes(ArrayList(allowedExtensions))
        } else {
            arrayListOf()
        }
        delegate.startFileExplorer(
            type.mimeType(),
            allowMultiple,
            mimeTypes,
            compressionQuality.toInt(),
            safOptions?.toMap(),
            resultOf(callback, ::pickedFilesOf)
        )
    }

    override fun pickDirectory(
        safOptions: SafOptionsMessage?,
        callback: (Result<String?>) -> Unit
    ) = withDelegate(callback) { delegate ->
        delegate.startFileExplorer(
            "dir",
            false,
            arrayListOf(),
            0,
            safOptions?.toMap(),
            resultOf(callback) { it as String? }
        )
    }

    override fun saveFile(
        fileName: String,
        mimeType: String,
        initialDirectory: String?,
        bytes: ByteArray,
        callback: (Result<String?>) -> Unit
    ) = withDelegate(callback) { delegate ->
        val name = if (fileName.isNotEmpty() && !fileName.contains(".")) {
            "$fileName.${getFileExtension(bytes)}"
        } else {
            fileName
        }
        // The delegate works the MIME type out from the name and the bytes,
        // so mimeType has never been used on Android. It only checks the type
        // for "dir", which a saved file never is.
        delegate.saveFile(name, null, initialDirectory, bytes, resultOf(callback) { it as String? })
    }

    override fun retrieveLostData(callback: (Result<LostDataMessage?>) -> Unit) =
        withDelegate(callback) {
            val context = activity?.applicationContext
            if (context == null) {
                callback(Result.success(null))
            } else {
                LostDataStore.retrieve(context, resultOf(callback, ::lostDataOf))
            }
        }

    override fun clearTemporaryFiles() {
        requireDelegate()
        activity?.applicationContext?.let { clearCache(it) }
    }

    override fun releaseSafGrant(uri: String) {
        requireDelegate()
        try {
            val flags = android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    android.content.Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            activity?.applicationContext?.contentResolver
                ?.releasePersistableUriPermission(android.net.Uri.parse(uri), flags)
        } catch (e: SecurityException) {
            // Ignore if we didn't have the permission or it was already released
            android.util.Log.e(TAG, "Failed to release SAF permission for $uri", e)
        }
    }

    private fun setup(
        messenger: BinaryMessenger,
        application: Application,
        activity: Activity,
        activityBinding: ActivityPluginBinding
    ) {
        this.activity = activity
        this.application = application
        this.delegate = FilePickerDelegate(activity)
        this.messenger = messenger
        FilePickerApi.setUp(messenger, this)
        delegate?.let { it ->
            EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(object :
                EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventSink?) {
                    it.setEventHandler(events)
                }

                override fun onCancel(arguments: Any?) {
                    it.setEventHandler(null)
                }
            })
            this.observer = LifeCycleObserver(activity)

            // V2 embedding setup for activity listeners.
            activityBinding.addActivityResultListener(it)
            this.lifecycle = (activityBinding.activity as? LifecycleOwner)?.lifecycle
            observer?.let { it -> lifecycle?.addObserver(it) }
        }
    }

    private fun tearDown() {
        delegate?.let { it ->
            activityBinding?.removeActivityResultListener(it)
        }
        this.activityBinding = null
        observer?.let { it ->
            lifecycle?.removeObserver(it)
            application?.unregisterActivityLifecycleCallbacks(it)
        }
        this.lifecycle = null
        delegate?.setEventHandler(null)
        this.delegate = null
        messenger?.let { FilePickerApi.setUp(it, null) }
        this.messenger = null
        this.application = null
    }

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        this.pluginBinding = binding
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        this.pluginBinding = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activityBinding = binding
        pluginBinding?.let { it ->
            this.setup(
                it.binaryMessenger,
                it.applicationContext as Application,
                activityBinding!!.activity,
                activityBinding!!
            )
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        this.onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this.onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        this.tearDown()
    }
}
