package com.mr.flutter.plugin.filepicker

import java.io.File

/**
 * Builds the file system paths the plugin returns or writes to.
 *
 * Kept free of Android APIs so it can be unit tested on the JVM.
 */
internal object PickerPaths {
    /**
     * The path of the directory behind a tree document id, such as
     * `primary:Documents/Sub` or `1234-5678:Music`, given the primary
     * [externalStorageDirectory].
     */
    fun directoryPath(treeDocumentId: String, externalStorageDirectory: String): String {
        val volumePath = getVolumePath(treeDocumentId, externalStorageDirectory)
        val documentPath = getDocumentPath(treeDocumentId)

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

    /**
     * Where a picked file is cached: its own directory, named after [stamp],
     * under `file_picker` in [cacheDir].
     *
     * Throws a [SecurityException] if [fileName], which comes from the
     * document provider, would place the file outside that directory.
     */
    fun cachedFile(cacheDir: File, stamp: Long, fileName: String?): File {
        val path = cacheDir.absolutePath + "/file_picker/" + stamp + "/" + (fileName ?: "unamed")
        val file = File(path)

        val safeDir = File(cacheDir.absolutePath + "/file_picker/").canonicalPath
        return file.takeIf { it.canonicalPath.startsWith(safeDir) }
            ?: throw SecurityException("Path traversal detected. Escaping the intended cache directory is not allowed.")
    }

    /** The path of the volume, without a trailing separator. */
    private fun getVolumePath(treeDocumentId: String, externalStorageDirectory: String): String {
        val parts = treeDocumentId.split(":")

        // Check if the URI corresponds to external storage
        val volumePath = if (parts.size > 1) {
            val volumeId = parts[0]
            val path = parts[1]

            // Map volume ID to external storage path
            if ("primary".equals(volumeId, ignoreCase = true)) {
                "$externalStorageDirectory/$path"
            } else {
                "/storage/$volumeId/$path"
            }
        } else {
            "$externalStorageDirectory/${parts.last()}"
        }
        return volumePath.removeSuffix(File.separator)
    }

    /** The path inside the volume, without a trailing separator. */
    private fun getDocumentPath(treeDocumentId: String): String {
        val split = treeDocumentId.split(":".toRegex()).dropLastWhile { it.isEmpty() }.toTypedArray()
        val path = if ((split.size >= 2)) split[1] else File.separator
        return path.removeSuffix(File.separator)
    }
}
