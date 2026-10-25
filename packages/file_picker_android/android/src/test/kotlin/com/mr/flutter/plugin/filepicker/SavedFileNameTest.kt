package com.mr.flutter.plugin.filepicker

import org.junit.Assert.assertEquals
import org.junit.Test

class SavedFileNameTest {
    @Test
    fun plainNameHasNoDuplicateSuffix() {
        val result = SavedFileName.baseNameAndSuffix(currentName = "report.pdf", extension = "pdf")

        assertEquals("report" to null, result)
    }

    @Test
    fun androidDuplicateSuffixAfterTheExtensionIsRead() {
        val result = SavedFileName.baseNameAndSuffix(currentName = "report.pdf (1)", extension = "pdf")

        assertEquals("report" to 1, result)
    }

    @Test
    fun duplicateSuffixBeforeTheExtensionIsRead() {
        val result = SavedFileName.baseNameAndSuffix(currentName = "report (2).pdf", extension = "pdf")

        assertEquals("report" to 2, result)
    }

    @Test
    fun stackedDuplicateSuffixesAreAddedUp() {
        val result = SavedFileName.baseNameAndSuffix(currentName = "report (1) (1).pdf", extension = "pdf")

        assertEquals("report" to 2, result)
    }

    // The system picker appended its own extension for a type it did not
    // know, which used to end up as "trace.gpx.xml.gpx" (#2199).
    @Test
    fun extensionAppendedBySystemIsDropped() {
        val result = SavedFileName.baseNameAndSuffix(currentName = "trace.gpx.xml", extension = "gpx")

        assertEquals("trace" to null, result)
    }

    @Test
    fun extensionWithRegexCharactersIsMatchedLiterally() {
        val result = SavedFileName.baseNameAndSuffix(currentName = "notes.c++", extension = "c++")

        assertEquals("notes" to null, result)
    }

    @Test
    fun nameWithAnotherExtensionIsKeptWhole() {
        val result = SavedFileName.baseNameAndSuffix(currentName = "other.txt", extension = "pdf")

        assertEquals("other.txt" to null, result)
    }
}
