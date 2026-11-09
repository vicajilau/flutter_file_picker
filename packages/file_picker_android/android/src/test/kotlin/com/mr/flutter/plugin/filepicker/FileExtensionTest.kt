package com.mr.flutter.plugin.filepicker

import java.util.Locale
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class FileExtensionTest {
    private lateinit var defaultLocale: Locale

    @Before
    fun setUp() {
        defaultLocale = Locale.getDefault()
    }

    @After
    fun tearDown() {
        Locale.setDefault(defaultLocale)
    }

    @Test
    fun upperCaseExtensionsAreLowered() {
        assertEquals("pdf", FileExtension.normalize("PDF"))
        assertEquals("csv", FileExtension.normalize("Csv"))
    }

    // Lowering with the default locale turned "ZIP" into "zıp" on Turkish
    // devices, with a dotless i, so no MIME type was found for it.
    @Test
    fun aTurkishDeviceKeepsTheDottedI() {
        Locale.setDefault(Locale.forLanguageTag("tr"))

        assertEquals("zip", FileExtension.normalize("ZIP"))
        assertEquals("ics", FileExtension.normalize("ICS"))
    }
}
