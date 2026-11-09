package com.mr.flutter.plugin.filepicker

import java.io.File
import java.util.UUID

internal object PickerPaths {
    /** Resolves a storage tree document ID to its directory path. */
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

    // Each pick owns a UUID directory, even when provider names and timestamps match.
    fun uniqueCachedFile(cacheDir: File, fileName: String?): File {
        val root = File(cacheDir, "file_picker").canonicalFile
        val directory = File(root, UUID.randomUUID().toString()).canonicalFile
        val file = File(directory, fileName ?: "unamed").canonicalFile
        return file.takeIf {
            directory.parentFile == root && it.path.startsWith(directory.path + File.separator)
        } ?: throw SecurityException("Path traversal detected. Escaping the intended cache directory is not allowed.")
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
