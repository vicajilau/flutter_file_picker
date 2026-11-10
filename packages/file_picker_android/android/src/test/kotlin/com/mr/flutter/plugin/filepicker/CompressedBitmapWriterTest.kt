package com.mr.flutter.plugin.filepicker

import java.io.IOException
import java.io.OutputStream
import java.nio.file.Files
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Test

class CompressedBitmapWriterTest {
    @Test
    fun successfulCompressionPersistsEveryByte() {
        val file = Files.createTempFile("picker-image-", ".jpg").toFile()
        try {
            CompressedBitmapWriter.write(file) { output ->
                output.write(byteArrayOf(1, 2, 3, 4))
                true
            }
            assertArrayEquals(byteArrayOf(1, 2, 3, 4), file.readBytes())
        } finally {
            file.delete()
        }
    }

    @Test
    fun falseCompressionResultDeletesTheIncompleteFile() {
        val file = Files.createTempFile("picker-image-", ".jpg").toFile()
        assertThrows(IOException::class.java) {
            CompressedBitmapWriter.write(file) { output ->
                output.write(byteArrayOf(1, 2))
                false
            }
        }
        assertFalse(file.exists())
    }

    @Test
    fun exceptionsDeleteThePartialFile() {
        val file = Files.createTempFile("picker-image-", ".jpg").toFile()
        assertThrows(IOException::class.java) {
            CompressedBitmapWriter.write(file) { output ->
                output.write(7)
                throw IOException("Disk full")
            }
        }
        assertFalse(file.exists())
    }
    @Test
    fun errorsDeletePartialFilesAndCloseTheStream() {
        val file = Files.createTempFile("picker-image-", ".jpg").toFile()
        var destination: OutputStream? = null
        assertThrows(AssertionError::class.java) {
            CompressedBitmapWriter.write(file) { output ->
                destination = output
                output.write(7)
                throw AssertionError("Encoder failed")
            }
        }
        assertFalse(file.exists())
        assertThrows(IOException::class.java) { destination!!.write(8) }
    }
}
