package com.mr.flutter.plugin.filepicker

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.OutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class SaveFileWriterTest {
    private class TrackingStream : ByteArrayOutputStream() {
        var closed = false
        override fun close() {
            closed = true
            super.close()
        }
    }

    @Test
    fun bytesAreWrittenAndStreamIsClosed() {
        val stream = TrackingStream()
        val bytes = byteArrayOf(0, 1, 2, 3, -1)
        SaveFileWriter.write(stream, bytes)
        assertArrayEquals(bytes, stream.toByteArray())
        assertTrue(stream.closed)
    }

    @Test
    fun absentOutputStreamIsAnError() {
        assertThrows(IOException::class.java) {
            SaveFileWriter.write(null, byteArrayOf(4, 5))
        }
    }

    @Test
    fun writeErrorsCloseTheStream() {
        var closed = false
        val stream = object : OutputStream() {
            override fun write(b: Int) {
                throw IOException("provider write failed")
            }
            override fun close() {
                closed = true
            }
        }
        assertThrows(IOException::class.java) {
            SaveFileWriter.write(stream, byteArrayOf(1))
        }
        assertTrue(closed)
    }
}
