package com.mr.flutter.plugin.filepicker

/**
 * The Storage Access Framework options of a pick, as sent by Dart in
 * `androidSafOptions`.
 *
 * Kept free of Android APIs so it can be unit tested on the JVM.
 */
data class SafOptions(
    /** Whether Dart sent SAF options at all, which adds a `safHandle`. */
    val requested: Boolean,
    /** Whether the grant should outlive the app process (`lifetime`). */
    val lifetimeGrant: Boolean,
    /** Whether write access was requested on top of read access. */
    val readWrite: Boolean,
    /** Whether a lifetime grant is persisted automatically. */
    val autoPersist: Boolean,
) {
    /** Whether the plugin should call `takePersistableUriPermission`. */
    val persistsGrant: Boolean
        get() = lifetimeGrant && autoPersist

    /** The access mode reported to Dart in the `safHandle`. */
    val accessName: String
        get() = if (readWrite) "readWrite" else "readOnly"

    companion object {
        /**
         * Reads the options from the `androidSafOptions` argument, defaulting
         * to a transient, read only grant for anything missing (#2257).
         */
        fun from(arguments: Map<*, *>?): SafOptions = SafOptions(
            requested = arguments != null,
            lifetimeGrant = arguments?.get("grant") == "lifetime",
            readWrite = arguments?.get("access") == "readWrite",
            autoPersist = (arguments?.get("autoPersist") as? Boolean) ?: true,
        )
    }
}
