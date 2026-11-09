package com.mr.flutter.plugin.filepicker

// Bound the long edge even when the short edge is already small.
internal object ImageSampling {
    fun forMaximumDimension(width: Int, height: Int, maxDimension: Int): Int {
        require(maxDimension > 0) { "maxDimension must be positive" }
        if (width <= 0 || height <= 0) return 1

        var sampleSize = 1
        while (width.toLong() > maxDimension.toLong() * sampleSize ||
            height.toLong() > maxDimension.toLong() * sampleSize) {
            require(sampleSize <= Int.MAX_VALUE / 2) { "Image exceeds supported sample range" }
            sampleSize *= 2
        }
        return sampleSize
    }
}
