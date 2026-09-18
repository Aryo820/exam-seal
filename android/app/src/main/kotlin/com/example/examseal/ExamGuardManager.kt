package com.yows.examseal

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Monitoring mentah ke Flutter via EventChannel; aktif hanya saat Exam Mode. Idempoten, tanpa vonis.
 * Event: map {type, atMillis, detail?}.
 */
class ExamGuardManager {

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var active = false

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    val observer = ExamLifecycleObserver { type, detail -> emit(type, detail) }

    fun isActive(): Boolean = active

    /** Idempoten: panggilan berulang tanpa efek ganda. */
    fun start(): Boolean {
        val wasActive = active
        active = true
        observer.guardActive = true
        if (!wasActive) emit(EVENT_GUARD_STARTED, null)
        return true
    }

    /** Idempoten: aman dipanggil saat sudah berhenti. */
    fun stop(): Boolean {
        val wasActive = active
        active = false
        observer.guardActive = false
        if (wasActive) emit(EVENT_GUARD_STOPPED, null)
        return true
    }

    fun attachSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun detachSink() {
        eventSink = null
    }

    private fun emit(type: String, detail: String?) {
        val sink = eventSink ?: return
        val payload = HashMap<String, Any?>()
        payload["type"] = type
        payload["atMillis"] = System.currentTimeMillis()
        if (detail != null) payload["detail"] = detail
        // EventSink harus dipanggil di main thread.
        if (Looper.myLooper() == Looper.getMainLooper()) {
            safeSend(sink, payload)
        } else {
            mainHandler.post { safeSend(sink, payload) }
        }
    }

    private fun safeSend(sink: EventChannel.EventSink, payload: Map<String, Any?>) {
        try {
            sink.success(payload)
        } catch (_: IllegalStateException) {
            // Sink mati (listener dibatalkan bersamaan): bukan error fatal.
            detachSink()
        } catch (_: RuntimeException) {
            detachSink()
        }
    }

    companion object {
        const val EVENT_GUARD_STARTED = "examGuardStarted"
        const val EVENT_GUARD_STOPPED = "examGuardStopped"
    }
}
