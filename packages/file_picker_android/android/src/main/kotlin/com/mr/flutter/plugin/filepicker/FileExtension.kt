package com.mr.flutter.plugin.filepicker

import java.util.Locale

/**
 * File extensions in the form [android.webkit.MimeTypeMap] and the CSV check
 * expect them.
 *
 * Kept free of Android APIs so it can be unit tested on the JVM.
 */
internal object FileExtension {
    /**
     * [extension] in lower case, whatever the device language. With the
     * default locale, a Turkish device turns "ZIP" into "zıp", a dotless i,
     * which no MIME type matches.
     */
    fun normalize(extension: String): String = extension.lowercase(Locale.ROOT)
}
