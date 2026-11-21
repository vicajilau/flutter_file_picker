package com.mr.flutter.plugin.filepicker

import android.net.Uri
import java.io.IOException
import java.io.OutputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/**
 * A document being written chunk by chunk, after the user picked where to
 * save it. [target] is `null` only in unit tests.
 */
internal class SaveStreamSession(
    val stream: OutputStream,
    val target: Uri?,
    val fileName: String?,
    val mimeType: String?,
)

/**
 * The saves that are open, keyed by an id Dart sends back with every chunk.
 *
 * The output stream stays here, and not in the activity, so a chunk written
 * after the activity was recreated still reaches the same document.
 */
internal object SaveStreams {
    private val sessions = ConcurrentHashMap<Int, SaveStreamSession>()
    private val nextId = AtomicInteger(1)

    fun open(session: SaveStreamSession): Int {
        val id = nextId.getAndIncrement()
        sessions[id] = session
        return id
    }

    @Throws(IOException::class)
    fun write(id: Int, bytes: ByteArray) {
        session(id).stream.write(bytes)
    }

    /** Flushes and closes the document, and forgets it. */
    @Throws(IOException::class)
    fun close(id: Int): SaveStreamSession {
        val session = sessions.remove(id) ?: throw unknown(id)
        session.stream.use { it.flush() }
        return session
    }

    /** Closes the stream without flushing, for a save that failed. `null` if it is already gone. */
    fun abort(id: Int): SaveStreamSession? {
        val session = sessions.remove(id) ?: return null
        try {
            session.stream.close()
        } catch (_: IOException) {
            // The save already failed, there is nothing left to report.
        }
        return session
    }

    private fun session(id: Int): SaveStreamSession = sessions[id] ?: throw unknown(id)

    private fun unknown(id: Int) = IOException("There is no save in progress with id $id.")
}
