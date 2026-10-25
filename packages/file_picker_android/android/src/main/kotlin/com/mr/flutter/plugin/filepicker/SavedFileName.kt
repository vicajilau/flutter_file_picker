package com.mr.flutter.plugin.filepicker

/**
 * Works out the name a saved document should have, from the name the
 * document provider actually gave it.
 *
 * Kept free of Android APIs so it can be unit tested on the JVM.
 */
internal object SavedFileName {
    /**
     * The base name and the " (N)" duplicate suffix, if any, of
     * [currentName], a document saved with [extension].
     *
     * Duplicate suffixes the provider stacked on the base name, like
     * "report (1) (2)", are merged into one so they do not nest.
     */
    fun baseNameAndSuffix(currentName: String, extension: String): Pair<String, Int?> {
        val (baseName, suffix) = extractBaseNameAndSuffix(currentName, Regex.escape(extension))
        return normalizeBaseNameAndSuffix(baseName, suffix)
    }

    private fun extractBaseNameAndSuffix(currentName: String, escapedExtension: String): Pair<String, Int?> {
        // Android duplicate style "name.ext (N)" that we normalize. Example: "report.pdf (1)"
        val androidCollisionRegex = Regex("^(.*)\\.$escapedExtension \\((\\d+)\\)$")
        // Desired style "name (N).ext"
        val normalizedCollisionRegex = Regex("^(.*) \\((\\d+)\\)\\.$escapedExtension$")
        // Regular "name.ext"
        val plainNameRegex = Regex("^(.*)\\.$escapedExtension$")
        // The system's document picker can append its own extension on top
        // of ours when the MIME type we declared doesn't match what it
        // expects for our extension (e.g. "trace.gpx" becoming
        // "trace.gpx.xml"). Detect our extension immediately followed by
        // exactly one more extension and strip both, recovering the true
        // base name, instead of leaving the mismatched extension in place
        // and appending ours on top of it (which would produce
        // "trace.gpx.xml.gpx").
        val systemAppendedExtensionRegex = Regex("^(.*)\\.$escapedExtension\\.[^./\\\\]+$")

        return when {
            androidCollisionRegex.matches(currentName) -> {
                val match = androidCollisionRegex.matchEntire(currentName)!!
                match.groupValues[1] to match.groupValues[2].toInt()
            }
            normalizedCollisionRegex.matches(currentName) -> {
                val match = normalizedCollisionRegex.matchEntire(currentName)!!
                match.groupValues[1] to match.groupValues[2].toInt()
            }
            plainNameRegex.matches(currentName) -> {
                val match = plainNameRegex.matchEntire(currentName)!!
                match.groupValues[1] to null
            }
            systemAppendedExtensionRegex.matches(currentName) -> {
                val match = systemAppendedExtensionRegex.matchEntire(currentName)!!
                match.groupValues[1] to null
            }
            else -> {
                currentName to null
            }
        }
    }

    private fun normalizeBaseNameAndSuffix(baseName: String, suffix: Int?): Pair<String, Int?> {
        var normalizedBaseName = baseName
        var normalizedSuffix = suffix
        // Trailing numeric suffix chunk "name (N)" we repeatedly strip and accumulate.
        // Example: "report (1)" -> base "report", suffix +1
        val baseNameSuffixRegex = Regex("^(.*) \\((\\d+)\\)$")

        while (true) {
            val baseMatch = baseNameSuffixRegex.matchEntire(normalizedBaseName) ?: break

            val realBase = baseMatch.groupValues[1]
            val baseSuffix = baseMatch.groupValues[2].toInt()
            normalizedBaseName = realBase
            normalizedSuffix = (normalizedSuffix ?: 0) + baseSuffix
        }

        return normalizedBaseName to normalizedSuffix
    }
}
