package com.example.examseal

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.os.Build
import java.lang.ref.WeakReference

/**
 * Screen pinning OS tanpa device owner via WeakReference. Keluar paksa via Back+Recent terdeteksi lifecycle (matriks v3).
 * Dialog sistem pertama wajib disetujui; verifikasi via polling. Panggilan/power tetap bisa interupsi.
 */
class ScreenPinManager(activity: Activity) {

    private val activityRef = WeakReference(activity)

    private fun isSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M

    private val activityManager: ActivityManager?
        get() = try {
            activityRef.get()?.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        } catch (_: RuntimeException) {
            null
        } catch (_: SecurityException) {
            null
        } catch (_: ClassCastException) {
            null
        }

    /** True bila aplikasi sedang ter-pin/terkunci tugas (terverifikasi). */
    fun isPinned(): Boolean {
        if (!isSupported()) return false
        return try {
            // PINNED = tanpa device owner; LOCKED = device owner, tetap dianggap terkunci.
            when (activityManager?.lockTaskModeState) {
                ActivityManager.LOCK_TASK_MODE_PINNED,
                ActivityManager.LOCK_TASK_MODE_LOCKED -> true
                else -> false
            }
        } catch (_: RuntimeException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    /**
     * True berarti permintaan terkirim, bukan sudah ter-pin. Verifikasi via [isPinned] sebelum mengunci.
     */
    fun requestPin(): Boolean {
        if (!isSupported()) return false
        val activity = activityRef.get() ?: return false
        if (isPinned()) return true
        return try {
            activity.startLockTask()
            true
        } catch (_: SecurityException) {
            false
        } catch (_: IllegalStateException) {
            false
        } catch (_: RuntimeException) {
            false
        }
    }

    /** Sinkron, tanpa dialog, terverifikasi. Idempoten. */
    fun stopPin(): Boolean {
        if (!isSupported()) return true
        val activity = activityRef.get() ?: return true
        if (!isPinned()) return true
        return try {
            activity.stopLockTask()
            !isPinned()
        } catch (_: SecurityException) {
            !isPinned()
        } catch (_: IllegalStateException) {
            !isPinned()
        } catch (_: RuntimeException) {
            !isPinned()
        }
    }
}
