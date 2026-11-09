package com.mr.flutter.plugin.filepicker

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ImageSamplingTest {
    @Test
    fun smallImagesAreNotDownsampled() {
        assertEquals(1, ImageSampling.forMaximumDimension(1024, 768, 4096))
        assertEquals(1, ImageSampling.forMaximumDimension(4096, 4096, 4096))
    }

    @Test
    fun widePanoramasAreLimitedByTheirLongSide() {
        assertEquals(4, ImageSampling.forMaximumDimension(10000, 500, 4096))
        assertEquals(2, ImageSampling.forMaximumDimension(8192, 1024, 4096))
    }

    @Test
    fun tallPanoramasAreAlsoLimited() {
        assertEquals(4, ImageSampling.forMaximumDimension(500, 10000, 4096))
        assertEquals(2, ImageSampling.forMaximumDimension(1024, 8192, 4096))
    }

    @Test
    fun largeSquareImagesStayWithinTheLimit() {
        assertEquals(4, ImageSampling.forMaximumDimension(16000, 16000, 4096))
    }

    @Test
    fun dimensionsJustAboveSampledLimitNeedTheNextPowerOfTwo() {
        assertEquals(4, ImageSampling.forMaximumDimension(8193, 500, 4096))
        assertEquals(4, ImageSampling.forMaximumDimension(500, 8193, 4096))
        assertEquals(8, ImageSampling.forMaximumDimension(16385, 500, 4096))
        assertEquals(524288, ImageSampling.forMaximumDimension(Int.MAX_VALUE, 1, 4096))
    }

    @Test
    fun impossibleSampleSizeDoesNotOverflow() {
        assertThrows(IllegalArgumentException::class.java) {
            ImageSampling.forMaximumDimension(Int.MAX_VALUE, 1, 1)
        }
    }

    @Test
    fun invalidDimensionsAvoidDivisionByZeroAndRejectInvalidLimit() {
        assertEquals(1, ImageSampling.forMaximumDimension(0, 0, 4096))
        assertEquals(1, ImageSampling.forMaximumDimension(-1, 5000, 4096))
        assertThrows(IllegalArgumentException::class.java) {
            ImageSampling.forMaximumDimension(100, 100, 0)
        }
    }
}
