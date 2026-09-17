package com.example.examseal

import android.app.Activity
import android.view.WindowManager
import java.lang.ref.WeakReference

/**
 * Pengelola FLAG_SECURE ExamSeal (PRD FR08).
 *
 * Hanya mengaktifkan/mematikan flag pada window activity. TIDAK memutuskan
 * apa pun soal pelanggaran — itu milik logika Flutter.
 *
 * Batasan jujur: FLAG_SECURE mencegah tangkapan konten (screenshot,
 * perekaman, thumbnail recent-apps) pada jalur yang didukung Android.
 * Flag ini TIDAK mencegah pengguna keluar dari aplikasi (Home/Recent/Back).
 *
 * Memakai [WeakReference] agar tidak membocorkan Activity saat recreate.
 */
class SecureModeManager(activity: Activity) {

    private val activityRef = WeakReference(activity)

    /** True bila FLAG_SECURE sedang terpasang pada window. */
    fun isActive(): Boolean {
        val activity = activityRef.get() ?: return false
        return activity.window.attributes.flags and
            WindowManager.LayoutParams.FLAG_SECURE != 0
    }

    /**
     * Pasang FLAG_SECURE. Mengembalikan true hanya bila flag benar-benar
     * terpasang (terverifikasi, bukan sekadar diminta).
     */
    fun enable(): Boolean {
        val activity = activityRef.get() ?: return false
        activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        return isActive()
    }

    /**
     * Lepas FLAG_SECURE. Mengembalikan true hanya bila flag benar-benar
     * sudah lepas.
     */
    fun disable(): Boolean {
        val activity = activityRef.get() ?: return false
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        return !isActive()
    }
}
