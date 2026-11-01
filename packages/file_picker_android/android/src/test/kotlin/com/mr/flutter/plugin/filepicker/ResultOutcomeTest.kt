package com.mr.flutter.plugin.filepicker

import org.junit.Assert.assertEquals
import org.junit.Test

class ResultOutcomeTest {
    @Test
    fun okIsDelivered() {
        assertEquals(ResultOutcome.DELIVER, ResultOutcome.of(ResultOutcome.RESULT_OK))
    }

    @Test
    fun canceledIsACancel() {
        assertEquals(ResultOutcome.CANCEL, ResultOutcome.of(ResultOutcome.RESULT_CANCELED))
        assertEquals(
            ResultOutcome.CANCEL,
            ResultOutcome.of(ResultOutcome.RESULT_CANCELED, hasData = false)
        )
    }

    @Test
    fun okWithoutDataFails() {
        assertEquals(ResultOutcome.FAIL, ResultOutcome.of(ResultOutcome.RESULT_OK, hasData = false))
    }

    // RESULT_FIRST_USER and any custom code used to be dropped, leaving the
    // Dart call waiting forever.
    @Test
    fun otherCodesFail() {
        for (code in listOf(1, 2, -2, 42)) {
            assertEquals(ResultOutcome.FAIL, ResultOutcome.of(code))
        }
    }
}
