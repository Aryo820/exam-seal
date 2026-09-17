package com.example.examseal

import android.app.Activity
import android.app.Application
import android.os.Bundle

/**
 * Pengamat lifecycle native ExamSeal.
 *
 * MELAPORKAN sinyal, BUKAN menuduh. Tidak ada logika pelanggaran di sini:
 * - TIDAK ada `onPause → violation`.
 * - TIDAK ada `onStop → violation`.
 *
 * Android bisa pause/stop/hilang fokus karena panggilan masuk, dialog izin,
 * dialog sistem, UI notifikasi, transisi activity, atau perilaku vendor.
 * Karena itu setiap sinyal bersifat fakta mentah; Flutter yang memutuskan
 * artinya (PRD FR05: fokus hilang saja bukan bukti).
 *
 * Sinyal yang tidak bisa dibedakan secara andal (mis. background sangat
 * singkat yang kemungkinan hanya dialog sistem) tetap dilaporkan sebagai
 * [EVENT_POSSIBLE_INTERRUPTION], bukan sebagai kepergian aplikasi.
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
     * Dipanggil MainActivity.onUserLeaveHint.
     *
     * Sinyal paling andal untuk "pengguna sengaja keluar" (tombol Home /
     * Recent): Android TIDAK memanggilnya untuk panggilan masuk, dialog
     * izin/sistem, screen-off, maupun transisi internal. Karena itu sinyal
     * ini boleh dipakai Flutter sebagai penguat matriks (PRD FR05/Q03),
     * tetap sebagai fakta — bukan vonis.
     */
    fun onUserLeaveHint() {
        if (!guardActive) return
        onSignal(EVENT_USER_EXIT, "user initiated leave (home/recents)")
    }

    /** Dipanggil MainActivity.onWindowFocusChanged. */
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
            // Background sangat singkat kemungkinan hanya interupsi sistem
            // (dialog izin/sistem), bukan pengguna keluar aplikasi. Tandai
            // ambigu agar Flutter tidak salah mengklasifikasi.
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

        /**
         * Ambang interupsi singkat. Di bawah ini, background hampir pasti
         * artefak sistem (transisi/dialog), bukan kepergian pengguna.
         * Nilai konservatif; Flutter punya ambang matriksnya sendiri (PRD).
         */
        const val AMBIGUOUS_THRESHOLD_MS = 1500L
    }
}
