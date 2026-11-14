package com.mr.flutter.plugin.filepicker

import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class MimeTypesTest {
    private val knownTypes = mapOf(
        "zip" to "application/zip",
        "pdf" to "application/pdf",
        "csv" to "text/comma-separated-values"
    )

    @Test
    fun absentAndEmptyFiltersDoNotLookUpExtensions() {
        for (extensions in listOf(null, arrayListOf<String>())) {
            assertEquals(arrayListOf("*/*"), FileUtils.getMimeTypes(extensions) {
                error("An unrestricted pick must not look up extensions")
            })
        }
    }

    @Test
    fun knownExtensionsKeepTheirMimeTypesAndOrder() {
        assertEquals(
            arrayListOf("application/zip", "application/pdf"),
            FileUtils.getMimeTypes(arrayListOf("zip", "pdf"), knownTypes::get)
        )
    }

    @Test
    fun p12CanStillBeFilteredOnADeviceWithAMimeMapping() {
        assertEquals(
            arrayListOf("application/x-pkcs12"),
            FileUtils.getMimeTypes(arrayListOf("p12")) { extension ->
                if (extension == "p12") "application/x-pkcs12" else null
            }
        )
    }

    @Test
    fun csvKeepsBothAndroidAndStandardMimeTypes() {
        assertEquals(
            arrayListOf("text/comma-separated-values", "text/csv"),
            FileUtils.getMimeTypes(arrayListOf("CSV"), knownTypes::get)
        )
    }

    @Test
    fun normalizationDoesNotDependOnTheDeviceLocale() {
        val originalLocale = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("tr"))
            assertEquals(
                arrayListOf("application/zip"),
                FileUtils.getMimeTypes(arrayListOf("ZIP"), knownTypes::get)
            )
        } finally {
            Locale.setDefault(originalLocale)
        }
    }

    @Test
    fun aMixedFilterCannotSilentlyDropAnUnknownExtension() {
        for (extensions in listOf(arrayListOf("xyz", "zip"), arrayListOf("zip", "xyz"))) {
            assertUnsupported(extensions, "xyz")
        }
    }

    @Test
    fun aSingleUnknownExtensionCannotFallBackToEveryFile() {
        assertUnsupported(arrayListOf("xyz"), "xyz")
    }

    @Test
    fun anAllUnknownFilterCannotFallBackToEveryFile() {
        assertUnsupported(arrayListOf("pfx", "p12"), "pfx")
    }

    @Test
    fun anErrorIdentifiesTheOriginalExtension() {
        assertUnsupported(arrayListOf("XYZ"), "XYZ")
    }

    @Test
    fun anEmptyExtensionCannotBeSilentlyIgnored() {
        assertUnsupported(arrayListOf("", "zip"), "")
    }

    private fun assertUnsupported(extensions: ArrayList<String>, extension: String) {
        val error = assertThrows(IllegalArgumentException::class.java) {
            FileUtils.getMimeTypes(extensions, knownTypes::get)
        }
        assertEquals(
            "Android has no MIME type for extension '$extension'. " +
                    "Use FileType.any without allowedExtensions and validate the selected files in your app.",
            error.message
        )
    }
}
