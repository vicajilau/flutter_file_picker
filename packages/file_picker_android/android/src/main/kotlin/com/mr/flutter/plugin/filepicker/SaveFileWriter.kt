package com.mr.flutter.plugin.filepicker

import java.io.IOException
import java.io.OutputStream

// A provider may return no stream; that must fail the export.
internal object SaveFileWriter {
    @Throws(IOException::class)
    fun write(stream: OutputStream?, bytes: ByteArray) {
        val destination = stream
            ?: throw IOException("Document provider did not return a writable output stream.")
        destination.use {
            it.write(bytes)
            it.flush()
        }
    }
}
