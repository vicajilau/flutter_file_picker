package com.mr.flutter.plugin.filepicker

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.OutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class SaveStreamsTest {
    private class TrackingStream : ByteArrayOutputStream() {
        var flushed = false
        var closed = false
        override fun flush() {
            flushed = true
            super.flush()
        }
        override fun close() {
            closed = true
            super.close()
        }
    }

    private fun open(stream: OutputStream) =
        SaveStreams.open(SaveStreamSession(stream, null, "a.bin", "application/octet-stream"))

    @Test
    fun chunksAreWrittenInOrderAndTheStreamIsClosed() {
        val stream = TrackingStream()
        val id = open(stream)

        SaveStreams.write(id, byteArrayOf(1, 2))
        SaveStreams.write(id, byteArrayOf(3, -1))
        SaveStreams.close(id)

        assertArrayEquals(byteArrayOf(1, 2, 3, -1), stream.toByteArray())
        assertTrue(stream.flushed)
        assertTrue(stream.closed)
    }

    @Test
    fun saveKeepsTheNameAndMimeType() {
        val id = open(TrackingStream())
        val session = SaveStreams.close(id)
        assertEquals("a.bin", session.fileName)
        assertEquals("application/octet-stream", session.mimeType)
    }

    @Test
    fun savesAreIndependent() {
        val first = TrackingStream()
        val second = TrackingStream()
        val firstId = open(first)
        val secondId = open(second)
        assertNotEquals(firstId, secondId)

        SaveStreams.write(firstId, byteArrayOf(1))
        SaveStreams.write(secondId, byteArrayOf(2))
        SaveStreams.close(firstId)
        SaveStreams.close(secondId)

        assertArrayEquals(byteArrayOf(1), first.toByteArray())
        assertArrayEquals(byteArrayOf(2), second.toByteArray())
    }

    @Test
    fun unknownIdIsAnError() {
        assertThrows(IOException::class.java) { SaveStreams.write(-1, byteArrayOf(1)) }
        assertThrows(IOException::class.java) { SaveStreams.close(-1) }
    }

    @Test
    fun aClosedSaveCannotBeWrittenTo() {
        val id = open(TrackingStream())
        SaveStreams.close(id)
        assertThrows(IOException::class.java) { SaveStreams.write(id, byteArrayOf(1)) }
    }

    @Test
    fun abortClosesWithoutFlushingAndForgetsTheSave() {
        val stream = TrackingStream()
        val id = open(stream)
        SaveStreams.write(id, byteArrayOf(1))

        assertNotNull(SaveStreams.abort(id))

        assertTrue(stream.closed)
        assertTrue(!stream.flushed)
        assertNull(SaveStreams.abort(id))
    }

    @Test
    fun abortSurvivesAStreamThatFailsToClose() {
        val stream = object : OutputStream() {
            override fun write(b: Int) {}
            override fun close() {
                throw IOException("provider close failed")
            }
        }
        val id = open(stream)
        assertNotNull(SaveStreams.abort(id))
    }

    @Test
    fun writeErrorsReachTheCaller() {
        val stream = object : OutputStream() {
            override fun write(b: Int) {
                throw IOException("provider write failed")
            }
        }
        val id = open(stream)
        assertThrows(IOException::class.java) { SaveStreams.write(id, byteArrayOf(1)) }
        SaveStreams.abort(id)
    }
}
