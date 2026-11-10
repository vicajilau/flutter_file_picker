package com.mr.flutter.plugin.filepicker

import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStream

// Never retain partial image data after an encoder or I/O failure.
internal object CompressedBitmapWriter {
    @Throws(IOException::class)
    fun write(target: File, compress: (OutputStream) -> Boolean) {
        try {
            FileOutputStream(target).use { output ->
                if (!compress(output)) {
                    throw IOException("Unable to write compressed image.")
                }
                output.flush()
            }
        } catch (failure: Throwable) {
            target.delete()
            throw failure
        }
    }
}
