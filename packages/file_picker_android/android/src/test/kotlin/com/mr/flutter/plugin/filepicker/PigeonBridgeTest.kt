package com.mr.flutter.plugin.filepicker

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PigeonBridgeTest {
    @Test
    fun fileTypesMapToTheDelegateFilters() {
        assertEquals("*/*", FileTypeMessage.ANY.mimeType())
        assertEquals("*/*", FileTypeMessage.CUSTOM.mimeType())
        assertEquals("image/*", FileTypeMessage.IMAGE.mimeType())
        assertEquals("video/*", FileTypeMessage.VIDEO.mimeType())
        assertEquals("audio/*", FileTypeMessage.AUDIO.mimeType())
        assertEquals("media", FileTypeMessage.MEDIA.mimeType())
    }

    // The map must read back the same through SafOptions.from, which the
    // delegate and LostDataStore use (#2257).
    @Test
    fun safOptionsRoundTripThroughTheDelegateMap() {
        val options = SafOptions.from(
            SafOptionsMessage(
                SafGrantMessage.LIFETIME,
                SafAccessMessage.READ_WRITE,
                autoPersist = false
            ).toMap()
        )

        assertEquals(true, options.lifetimeGrant)
        assertEquals(true, options.readWrite)
        assertEquals(false, options.autoPersist)

        val defaults = SafOptions.from(
            SafOptionsMessage(SafGrantMessage.TRANSIENT, SafAccessMessage.READ_ONLY, true).toMap()
        )
        assertEquals(false, defaults.lifetimeGrant)
        assertEquals(false, defaults.readWrite)
    }

    @Test
    fun pickedFilesKeepEveryField() {
        val file = pickedFileOf(
            hashMapOf(
                "path" to "/cache/a.pdf",
                "name" to "a.pdf",
                "size" to 42L,
                "identifier" to "content://a",
                "safHandle" to hashMapOf("uri" to "content://a", "access" to "readWrite"),
            )
        )

        assertEquals("/cache/a.pdf", file.path)
        assertEquals("a.pdf", file.name)
        assertEquals(42L, file.size)
        assertEquals("content://a", file.identifier)
        assertEquals(SafHandleMessage("content://a", SafAccessMessage.READ_WRITE), file.safHandle)
    }

    @Test
    fun aCancelledPickHasNoFiles() {
        assertNull(pickedFilesOf(null))
        assertNull(lostDataOf(null))
    }

    @Test
    fun lostDataKeepsItsFilesOrItsError() {
        val files = lostDataOf(hashMapOf("files" to listOf(hashMapOf("name" to "a", "size" to 1))))
        assertEquals("a", files?.files?.single()?.name)
        assertNull(files?.errorCode)

        val error = lostDataOf(hashMapOf("errorCode" to "unknown_path", "errorMessage" to "gone"))
        assertNull(error?.files)
        assertEquals("unknown_path", error?.errorCode)
        assertEquals("gone", error?.errorMessage)
    }
}
