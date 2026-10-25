package com.mr.flutter.plugin.filepicker

import android.content.Context
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persists the in-flight pick request and its result, so a pick survives
 * Android destroying the activity (or the whole process) while the system
 * picker is open.
 *
 * The request options are stored before the picker opens. When a result
 * arrives with no pending request, the delegate restores those options,
 * processes the files as usual and stores the result here instead of dropping
 * it. Dart later reads it once through `retrieveLostData`.
 */
object LostDataStore {
    private const val PREFS_NAME = "flutter_file_picker_lost_data"
    private const val KEY_REQUEST = "pending_request"
    private const val KEY_RESULT = "lost_result"

    /** The options of a pick request, enough to process its result later. */
    data class PendingRequest(
        val type: String,
        val compressionQuality: Int,
        val androidSafOptions: HashMap<*, *>?
    )

    // True while the result of a restored request is being processed, which
    // includes copying the picked files and can take a while.
    private var restoring = false

    // A retrieveLostData call that arrived while restoring. It is answered
    // once the restored result has been stored.
    private var waitingResult: MethodChannel.Result? = null

    /** Whether the result of a restored request is being processed. */
    val isRestoring: Boolean
        @Synchronized get() = restoring

    fun saveRequest(context: Context, request: PendingRequest) {
        prefs(context).edit().putString(KEY_REQUEST, encodeRequest(request)).apply()
    }

    fun clearRequest(context: Context) {
        prefs(context).edit().remove(KEY_REQUEST).apply()
    }

    /**
     * Starts restoring the request whose activity was destroyed while the
     * picker was open, and returns its options, or `null` if there is none.
     */
    @Synchronized
    fun beginRestore(context: Context): PendingRequest? {
        val request = loadRequest(context) ?: return null
        restoring = true
        return request
    }

    /**
     * Stores the files of the restored request, or nothing if the pick was
     * cancelled ([files] is `null`), and finishes restoring.
     */
    @Synchronized
    fun finishRestore(context: Context, files: List<FileInfo>?) {
        if (files != null) saveFiles(context, files) else clearRequest(context)
        endRestore(context)
    }

    /** Stores the error of the restored request and finishes restoring. */
    @Synchronized
    fun finishRestoreWithError(context: Context, code: String, message: String?) {
        saveError(context, code, message)
        endRestore(context)
    }

    /**
     * Answers [result] with the stored outcome of a lost pick, or `null`.
     * Waits if a restored result is still being processed.
     */
    @Synchronized
    fun retrieve(context: Context, result: MethodChannel.Result) {
        if (restoring) {
            waitingResult = result
        } else {
            result.success(takeResult(context))
        }
    }

    private fun endRestore(context: Context) {
        restoring = false
        waitingResult?.let {
            waitingResult = null
            it.success(takeResult(context))
        }
    }

    private fun loadRequest(context: Context): PendingRequest? {
        val raw = prefs(context).getString(KEY_REQUEST, null) ?: return null
        return decodeRequest(raw)
    }

    /** Stores the files of an orphaned pick, replacing any previous one. */
    private fun saveFiles(context: Context, files: List<FileInfo>) {
        storeResult(context, encodeFiles(files.map { it.toMap() }))
    }

    /** Stores the error of an orphaned pick, replacing any previous one. */
    private fun saveError(context: Context, code: String, message: String?) {
        storeResult(context, encodeError(code, message))
    }

    /**
     * Returns the stored result as a map for the method channel, or `null`
     * when there is none, and clears it so it is only delivered once.
     */
    private fun takeResult(context: Context): HashMap<String, Any?>? {
        val prefs = prefs(context)
        val raw = prefs.getString(KEY_RESULT, null) ?: return null
        prefs.edit().remove(KEY_RESULT).apply()
        return decodeResult(raw)
    }

    private fun storeResult(context: Context, raw: String) {
        prefs(context).edit()
            .putString(KEY_RESULT, raw)
            .remove(KEY_REQUEST)
            .apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // The encoding below only needs org.json, so it is unit tested on the JVM.

    internal fun encodeRequest(request: PendingRequest): String = JSONObject()
        .put("type", request.type)
        .put("compressionQuality", request.compressionQuality)
        .put("androidSafOptions", request.androidSafOptions?.let { JSONObject(it) })
        .toString()

    /** Reads a stored request back, or `null` if it is unreadable. */
    internal fun decodeRequest(raw: String): PendingRequest? = try {
        val json = JSONObject(raw)
        PendingRequest(
            type = json.getString("type"),
            compressionQuality = json.optInt("compressionQuality", 0),
            androidSafOptions = json.optJSONObject("androidSafOptions")?.let { toMap(it) }
        )
    } catch (e: Exception) {
        null
    }

    internal fun encodeFiles(files: List<Map<String, Any?>>): String {
        val array = JSONArray()
        files.forEach { array.put(JSONObject(it)) }
        return JSONObject().put("files", array).toString()
    }

    internal fun encodeError(code: String, message: String?): String =
        JSONObject().put("errorCode", code).put("errorMessage", message).toString()

    /** Reads a stored result back as a method channel map, or `null`. */
    internal fun decodeResult(raw: String): HashMap<String, Any?>? = try {
        toMap(JSONObject(raw))
    } catch (e: Exception) {
        null
    }

    private fun toMap(json: JSONObject): HashMap<String, Any?> {
        val map = HashMap<String, Any?>()
        json.keys().forEach { key -> map[key] = fromJson(json.get(key)) }
        return map
    }

    private fun fromJson(value: Any?): Any? = when (value) {
        JSONObject.NULL -> null
        is JSONObject -> toMap(value)
        is JSONArray -> (0 until value.length()).map { fromJson(value.get(it)) }
        else -> value
    }
}
