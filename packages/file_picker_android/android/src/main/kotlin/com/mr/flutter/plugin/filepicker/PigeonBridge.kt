package com.mr.flutter.plugin.filepicker

import io.flutter.plugin.common.MethodChannel

/**
 * A [MethodChannel.Result] that answers [callback] with its value through
 * [convert], once.
 *
 * The delegate is written against [MethodChannel.Result], so this lets the
 * Pigeon API keep it as is. Errors become a [FilePickerFlutterError], which
 * reaches Dart as a `PlatformException` with the same code.
 */
internal fun <T> resultOf(
    callback: (Result<T>) -> Unit,
    convert: (Any?) -> T,
): MethodChannel.Result = MethodResultWrapper(object : MethodChannel.Result {
    private var answered = false

    private fun answer(result: Result<T>) {
        if (answered) return
        answered = true
        callback(result)
    }

    override fun success(result: Any?) {
        answer(
            try {
                Result.success(convert(result))
            } catch (e: Exception) {
                Result.failure(FilePickerFlutterError("invalid_result", e.message, null))
            }
        )
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        answer(Result.failure(FilePickerFlutterError(errorCode, errorMessage, errorDetails)))
    }

    override fun notImplemented() {
        answer(Result.failure(FilePickerFlutterError("not_implemented", null, null)))
    }
})

/** The MIME type filter the delegate expects for a [FileTypeMessage]. */
internal fun FileTypeMessage.mimeType(): String = when (this) {
    FileTypeMessage.AUDIO -> "audio/*"
    FileTypeMessage.IMAGE -> "image/*"
    FileTypeMessage.VIDEO -> "video/*"
    FileTypeMessage.MEDIA -> "media"
    FileTypeMessage.ANY, FileTypeMessage.CUSTOM -> "*/*"
}

/**
 * The map the delegate and [LostDataStore] keep the SAF options in, read
 * back by [SafOptions.from].
 */
internal fun SafOptionsMessage.toMap(): java.util.HashMap<String, Any> = hashMapOf(
    "grant" to if (grant == SafGrantMessage.LIFETIME) "lifetime" else "transient",
    "access" to if (access == SafAccessMessage.READ_WRITE) "readWrite" else "readOnly",
    "autoPersist" to autoPersist,
)

/** A picked file from the map [FileInfo.toMap] builds. */
internal fun pickedFileOf(map: Map<*, *>): PickedFileMessage = PickedFileMessage(
    path = map["path"] as String?,
    name = map["name"] as String?,
    size = (map["size"] as? Number)?.toLong() ?: 0,
    identifier = map["identifier"] as String?,
    safHandle = (map["safHandle"] as? Map<*, *>)?.let { handle ->
        SafHandleMessage(
            uri = handle["uri"] as String,
            access = if (handle["access"] == "readWrite") {
                SafAccessMessage.READ_WRITE
            } else {
                SafAccessMessage.READ_ONLY
            },
        )
    },
)

/** The picked files of a delegate result, a list of [FileInfo.toMap] maps. */
internal fun pickedFilesOf(result: Any?): List<PickedFileMessage>? =
    (result as List<*>?)?.map { pickedFileOf(it as Map<*, *>) }

/** The lost data of a [LostDataStore.retrieve] result. */
internal fun lostDataOf(result: Any?): LostDataMessage? {
    val map = result as Map<*, *>? ?: return null
    return LostDataMessage(
        files = pickedFilesOf(map["files"]),
        errorCode = map["errorCode"] as String?,
        errorMessage = map["errorMessage"] as String?,
    )
}
