package com.mr.flutter.plugin.filepicker

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SafOptionsTest {
    @Test
    fun withoutOptionsRequestsNothing() {
        val options = SafOptions.from(null)

        assertFalse(options.requested)
        assertFalse(options.persistsGrant)
        assertEquals("readOnly", options.accessName)
    }

    @Test
    fun lifetimeReadWriteIsPersisted() {
        val options = SafOptions.from(
            mapOf("grant" to "lifetime", "access" to "readWrite", "autoPersist" to true)
        )

        assertTrue(options.requested)
        assertTrue(options.persistsGrant)
        assertEquals("readWrite", options.accessName)
    }

    @Test
    fun lifetimeWithoutAutoPersistIsNotPersisted() {
        val options = SafOptions.from(mapOf("grant" to "lifetime", "autoPersist" to false))

        assertTrue(options.lifetimeGrant)
        assertFalse(options.persistsGrant)
        assertEquals("readOnly", options.accessName)
    }

    @Test
    fun missingValuesDefaultToATransientReadOnlyGrant() {
        val options = SafOptions.from(emptyMap<String, Any>())

        assertTrue(options.requested)
        assertFalse(options.lifetimeGrant)
        assertFalse(options.readWrite)
        assertTrue(options.autoPersist)
        assertEquals("readOnly", options.accessName)
    }

    // Dart used to send the options one level deeper, where they were
    // silently ignored (#2257).
    @Test
    fun optionsNestedOneLevelDeeperAreNotRead() {
        val options = SafOptions.from(
            mapOf("safOptions" to mapOf("grant" to "lifetime", "access" to "readWrite"))
        )

        assertFalse(options.lifetimeGrant)
        assertFalse(options.readWrite)
        assertEquals("readOnly", options.accessName)
    }
}
