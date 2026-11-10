package com.mr.flutter.plugin.filepicker

import java.io.File
import java.nio.file.Files
import java.util.UUID
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class PickerPathsTest {
    private val storage = "/storage/emulated/0"
    private val cacheDir: File = Files.createTempDirectory("cache").toFile()

    @After
    fun tearDown() {
        cacheDir.deleteRecursively()
    }

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
    fun uniqueCachedFileGetsItsOwnDirectory() {
        val file = PickerPaths.uniqueCachedFile(cacheDir, "report.pdf")
        val directory = file.parentFile!!
        assertEquals(File(cacheDir, "file_picker").canonicalFile, directory.parentFile)
        assertEquals(directory.name, UUID.fromString(directory.name).toString())
        assertEquals("report.pdf", file.name)
    }

    @Test
    fun uniqueCachedFileWithoutNameGetsAPlaceholder() {
        val file = PickerPaths.uniqueCachedFile(cacheDir, null)

        assertEquals("unamed", file.name)
    }

    @Test
    fun identicallyNamedDocumentsNeverShareACachedDestination() {
        val paths = (0 until 100).map {
            PickerPaths.uniqueCachedFile(cacheDir, "book.pdf")
        }
        assertEquals(100, paths.map { it.path }.toSet().size)
        paths.forEach { file ->
            assertEquals("book.pdf", file.name)
            assertEquals("file_picker", file.parentFile?.parentFile?.name)
        }
    }

    @Test
    fun cacheDirectoryCannotBeEscapedByProviderFilename() {
        assertThrows(SecurityException::class.java) {
            PickerPaths.uniqueCachedFile(cacheDir, "../another.pdf")
        }
    }

    // The name comes from the document provider, which an app does not
    // control.
    @Test
    fun uniqueCachedFileCannotEscapeTheCacheDirectory() {
        assertThrows(SecurityException::class.java) {
            PickerPaths.uniqueCachedFile(cacheDir, "../../../shared_prefs/evil.xml")
        }
    }

    @Test
    fun nestedProviderNamesCanBeCreatedAndWritten() {
        val file = PickerPaths.uniqueCachedFile(cacheDir, "photos/a.jpg")
        file.parentFile!!.mkdirs()
        file.writeBytes(byteArrayOf(1, 2, 3))
        assertEquals("photos", file.parentFile!!.name)
        assertEquals(File(cacheDir, "file_picker").canonicalFile, file.parentFile!!.parentFile!!.parentFile)
        assertEquals(3L, file.length())
    }

    @Test
    fun traversalThatStaysInsideTheUniqueDirectoryIsAllowed() {
        val file = PickerPaths.uniqueCachedFile(cacheDir, "photos/../a.jpg")
        assertEquals("a.jpg", file.name)
        assertEquals(File(cacheDir, "file_picker").canonicalFile, file.parentFile!!.parentFile)
    }

    @Test
    fun nestedTraversalCannotEscapeTheUniqueDirectory() {
        for (name in listOf("photos/../../another.pdf", "../file_picker_evil/a.jpg", ".", "photos/..")) {
            assertThrows(SecurityException::class.java) {
                PickerPaths.uniqueCachedFile(cacheDir, name)
            }
        }
    }
}
