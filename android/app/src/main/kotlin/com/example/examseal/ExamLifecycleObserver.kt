package com.yows.examseal

import android.app.Activity
import android.app.Application
import android.os.Bundle

/**
 * Laporkan sinyal mentah, bukan vonis. Pause/fokus hilang bisa dari panggilan/dialog/vendor; Flutter yang menilai (FR05).
 */
class ExamLifecycleObserver(
    private val onSignal: (type: String, detail: String?) -> Unit,
) : Application.ActivityLifecycleCallbacks {

    /** Hanya emit saat ExamGuard aktif (diatur [ExamGuardManager]). */
    @Volatile
    var guardActive: Boolean = false

    private var registered = false

    /** Koalesensi: pause→stop beruntun hanya satu sinyal background. */
    private var lastBackgroundSent = false
    private var lastFocusSent: Boolean? = null
    private var backgroundSince: Long = 0L

    /** Daftarkan sekali ke Application; aman dipanggil berulang. */
    fun registerOnce(application: Application) {
        if (registered) return
        application.registerActivityLifecycleCallbacks(this)
        registered = true
    }

    /**
     * Sinyal keluar disengaja (Home/Recent); tidak untuk panggilan/dialog. Fakta untuk matriks FR05, bukan vonis.
     */
    fun onUserLeaveHint() {
        if (!guardActive) return
        onSignal(EVENT_USER_EXIT, "user initiated leave (home/recents)")
    }

    fun onWindowFocusChanged(hasFocus: Boolean) {
        if (!guardActive || lastFocusSent == hasFocus) return
        lastFocusSent = hasFocus
        if (hasFocus) {
            onSignal(EVENT_FOCUS_GAINED, null)
        } else {
            // Hilang fokus bukan bukti kepergian (bisa dialog sistem):
            // laporkan sebagai fakta fokus, bukan background.
            onSignal(EVENT_FOCUS_LOST, "window focus lost")
        }
    }

    override fun onActivityPaused(activity: Activity) {
        if (!guardActive || lastBackgroundSent) return
        lastBackgroundSent = true
        backgroundSince = now()
        onSignal(EVENT_BACKGROUNDED, "activity paused")
    }

    override fun onActivityResumed(activity: Activity) {
        if (!guardActive) {
            lastBackgroundSent = false
            lastFocusSent = null
            return
        }
        if (lastBackgroundSent) {
            lastBackgroundSent = false
            val awayMs = now() - backgroundSince
            onSignal(EVENT_FOREGROUNDED, "awayMs=$awayMs")
            // Background sangat singkat kemungkinan interupsi sistem; tandai ambigu agar tidak salah klasifikasi.
            if (awayMs in 1 until AMBIGUOUS_THRESHOLD_MS) {
                onSignal(EVENT_POSSIBLE_INTERRUPTION, "brief background ${awayMs}ms")
            }
        }
    }

    override fun onActivityStarted(activity: Activity) = Unit
    override fun onActivityStopped(activity: Activity) = Unit
    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
    override fun onActivityDestroyed(activity: Activity) = Unit

    private fun now(): Long = System.currentTimeMillis()

    companion object {
        const val EVENT_BACKGROUNDED = "appBackgrounded"
        const val EVENT_USER_EXIT = "userInitiatedExit"
        const val EVENT_FOREGROUNDED = "appForegrounded"
        const val EVENT_FOCUS_LOST = "windowFocusLost"
        const val EVENT_FOCUS_GAINED = "windowFocusGained"
        const val EVENT_POSSIBLE_INTERRUPTION = "possibleSystemInterruption"

        /** Di bawah ambang ini background dianggap artefak sistem; Flutter punya ambang matriks sendiri. */
        const val AMBIGUOUS_THRESHOLD_MS = 1500L
    }
}
