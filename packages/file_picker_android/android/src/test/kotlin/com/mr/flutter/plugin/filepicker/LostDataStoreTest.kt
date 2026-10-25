package com.mr.flutter.plugin.filepicker

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LostDataStoreTest {
    @Test
    fun decodeRequestRoundTrip() {
        val request = LostDataStore.PendingRequest(
            type = "image",
            compressionQuality = 50,
            androidSafOptions = hashMapOf("grant" to "lifetime", "access" to "readWrite")
        )

        val restored = LostDataStore.decodeRequest(LostDataStore.encodeRequest(request))

        assertEquals(request, restored)
    }

    @Test
    fun decodeRequestWithoutSafOptionsRoundTrip() {
        val request = LostDataStore.PendingRequest("any", 0, null)

        val restored = LostDataStore.decodeRequest(LostDataStore.encodeRequest(request))

        assertEquals(request, restored)
    }

    @Test
    fun filesRoundTrip() {
        val raw = LostDataStore.encodeFiles(
            listOf(
                mapOf(
                    "path" to "/cache/file_picker/1/a.pdf",
                    "name" to "a.pdf",
                    "size" to 3L,
                    "identifier" to "content://docs/a",
                    "safHandle" to hashMapOf("uri" to "content://docs/a", "access" to "readWrite"),
                ),
            )
        )

        val files = LostDataStore.decodeResult(raw)!!["files"] as List<*>
        val file = files.single() as Map<*, *>

        assertEquals("/cache/file_picker/1/a.pdf", file["path"])
        assertEquals("a.pdf", file["name"])
        assertEquals(3L, (file["size"] as Number).toLong())
        assertEquals(mapOf("uri" to "content://docs/a", "access" to "readWrite"), file["safHandle"])
    }

    @Test
    fun errorRoundTrip() {
        val raw = LostDataStore.encodeError("out_of_memory", "Too large.")

        val result = LostDataStore.decodeResult(raw)!!

        assertEquals("out_of_memory", result["errorCode"])
        assertEquals("Too large.", result["errorMessage"])
    }

    @Test
    fun unreadableRequestIsIgnored() {
        assertNull(LostDataStore.decodeRequest("not json"))
    }

    @Test
    fun unreadableResultIsIgnored() {
        assertNull(LostDataStore.decodeResult("not json"))
    }
}
