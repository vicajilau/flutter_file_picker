package com.mr.flutter.plugin.filepicker

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class PickerPathsTest {
    private val storage = "/storage/emulated/0"
    private val cacheDir: File = Files.createTempDirectory("cache").toFile()

    @Test
    fun primaryStorageDirectory() {
        assertEquals(
            "/storage/emulated/0/Documents/Sub",
            PickerPaths.directoryPath("primary:Documents/Sub", storage)
        )
    }

    @Test
    fun sdCardDirectory() {
        assertEquals(
            "/storage/1234-5678/Music",
            PickerPaths.directoryPath("1234-5678:Music", storage)
        )
    }

    @Test
    fun primaryStorageRoot() {
        assertEquals(storage, PickerPaths.directoryPath("primary:", storage))
    }

    @Test
    fun trailingSeparatorIsDropped() {
        assertEquals(
            "/storage/emulated/0/Download",
            PickerPaths.directoryPath("primary:Download/", storage)
        )
    }

    @Test
    fun cachedFileGetsItsOwnDirectory() {
        val file = PickerPaths.cachedFile(cacheDir, 42, "report.pdf")

        assertEquals(File(cacheDir, "file_picker/42/report.pdf").path, file.path)
    }

    @Test
    fun cachedFileWithoutNameGetsAPlaceholder() {
        val file = PickerPaths.cachedFile(cacheDir, 42, null)

        assertEquals("unamed", file.name)
    }

    // The name comes from the document provider, which an app does not
    // control.
    @Test
    fun cachedFileCannotEscapeTheCacheDirectory() {
        assertThrows(SecurityException::class.java) {
            PickerPaths.cachedFile(cacheDir, 42, "../../../shared_prefs/evil.xml")
        }
    }
}
