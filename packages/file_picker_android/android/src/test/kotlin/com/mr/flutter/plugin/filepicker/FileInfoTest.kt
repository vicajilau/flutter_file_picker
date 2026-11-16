package com.mr.flutter.plugin.filepicker

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class FileInfoTest {
    @Test
    fun aKnownSizeIsSent() {
        val map = FileInfo.Builder().withName("game.mp4").withSize(3L * 1024 * 1024 * 1024).build().toMap()

        assertEquals(3L * 1024 * 1024 * 1024, map["size"])
    }

    @Test
    fun anEmptyFileSendsZero() {
        val map = FileInfo.Builder().withName("empty.txt").withSize(0).build().toMap()

        assertEquals(0L, map["size"])
    }

    @Test
    fun anUnknownSizeIsLeftOut() {
        val map = FileInfo.Builder().withName("game.mp4").withSize(null).build().toMap()

        assertFalse(map.containsKey("size"))
    }
}
