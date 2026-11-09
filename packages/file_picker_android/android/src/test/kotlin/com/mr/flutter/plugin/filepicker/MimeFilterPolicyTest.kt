package com.mr.flutter.plugin.filepicker

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

class MimeFilterPolicyTest {
    private val known = mapOf(
        "pdf" to "application/pdf",
        "txt" to "text/plain",
        "csv" to "text/comma-separated-values"
    )

    @Test
    fun knownExtensionsRetainSpecificFilters() {
        assertEquals(
            listOf("application/pdf", "text/plain"),
            MimeFilterPolicy.resolve(listOf("PDF", "txt")) { known[it] }
        )
    }

    @Test
    fun anUnknownExtensionCannotBeHiddenByKnownOnes() {
        // Otzaria supports rare Word backup formats such as .wbk. The
        // platform MIME database differs between Android devices.
        assertEquals(
            listOf("*/*"),
            MimeFilterPolicy.resolve(listOf("pdf", "wbk", "txt")) { known[it] }
        )
    }

    @Test
    fun unsupportedOnlyAndEmptySelectionsUseWildcard() {
        assertEquals(
            listOf("*/*"),
            MimeFilterPolicy.resolve(listOf("wbk")) { known[it] }
        )
        assertEquals(
            listOf("*/*"),
            MimeFilterPolicy.resolve(emptyList()) { known[it] }
        )
        assertEquals(
            listOf("*/*"),
            MimeFilterPolicy.resolve(null) { known[it] }
        )
    }

    @Test
    fun csvHasAStandardMimeTypeEvenWhenAndroidDoesNotKnowIt() {
        assertEquals(
            listOf("text/csv"),
            MimeFilterPolicy.resolve(listOf("CSV")) { null }
        )
        assertEquals(
            listOf("text/comma-separated-values", "text/csv"),
            MimeFilterPolicy.resolve(listOf("csv")) { known[it] }
        )
    }

    @Test
    fun duplicateMimeMappingsAreDeduplicated() {
        assertEquals(
            listOf("text/plain"),
            MimeFilterPolicy.resolve(listOf("txt", "text")) {
                if (it == "txt" || it == "text") "text/plain" else null
            }
        )
    }

    @Test
    fun emptyAndBlankExtensionsUseWildcardWithoutLookingThemUp() {
        for (extension in listOf("", " ", "\t")) {
            assertEquals(
                listOf("*/*"),
                MimeFilterPolicy.resolve(listOf("pdf", extension)) {
                    if (it == "pdf") "application/pdf" else error("Invalid extension lookup")
                }
            )
        }
    }

    @Test
    fun blankMimeMappingsUseWildcard() {
        for (mapping in listOf(null, "", " ", "\t")) {
            assertEquals(
                listOf("*/*"),
                MimeFilterPolicy.resolve(listOf("pdf", "wbk")) {
                    if (it == "pdf") "application/pdf" else mapping
                }
            )
        }
    }

    @Test
    fun unknownMappingsUseWildcardRegardlessOfTheirPositionOrCsvFallback() {
        for (extensions in listOf(listOf("wbk", "pdf"), listOf("pdf", "wbk"), listOf("csv", "wbk"))) {
            assertEquals(listOf("*/*"), MimeFilterPolicy.resolve(extensions) { known[it] })
        }
    }

    @Test
    fun csvFallbackCanBeCombinedWithKnownTypesWithoutDuplicates() {
        assertEquals(
            listOf("text/csv", "application/pdf"),
            MimeFilterPolicy.resolve(listOf("CSV", "pdf", "csv")) {
                if (it == "pdf") "application/pdf" else "text/csv"
            }
        )
    }

    @Test
    fun mimeLookupsIgnoreTheDefaultLocale() {
        val original = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("tr"))
            assertEquals(
                listOf("application/zip", "text/csv"),
                MimeFilterPolicy.resolve(listOf("ZIP", "CSV")) {
                    if (it == "zip") "application/zip" else null
                }
            )
        } finally {
            Locale.setDefault(original)
        }
    }
}
