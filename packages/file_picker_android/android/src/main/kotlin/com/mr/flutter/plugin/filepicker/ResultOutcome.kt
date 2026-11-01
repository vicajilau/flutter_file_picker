package com.mr.flutter.plugin.filepicker

/**
 * What the delegate does with the result of a picker or save activity.
 *
 * Kept free of Android APIs so it can be unit tested on the JVM.
 */
enum class ResultOutcome {
    /** The user confirmed and there is something to process. */
    DELIVER,

    /** The user cancelled, answered as `null`. */
    CANCEL,

    /** Anything else, answered as an error so the Dart call never hangs. */
    FAIL;

    companion object {
        /** `Activity.RESULT_OK`. */
        const val RESULT_OK = -1

        /** `Activity.RESULT_CANCELED`. */
        const val RESULT_CANCELED = 0

        /**
         * The outcome of an activity that ended with [resultCode]. A confirmed
         * result that needs data but has none, such as a save without a
         * location, fails instead of being dropped.
         */
        fun of(resultCode: Int, hasData: Boolean = true): ResultOutcome = when {
            resultCode == RESULT_OK && hasData -> DELIVER
            resultCode == RESULT_CANCELED -> CANCEL
            else -> FAIL
        }
    }
}
