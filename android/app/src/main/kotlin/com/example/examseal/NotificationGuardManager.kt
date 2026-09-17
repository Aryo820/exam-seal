package com.example.examseal

import android.app.NotificationManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build

/**
 * Pengendali DND (Do Not Disturb) milik ExamSeal (PRD FR09).
 *
 * Perilaku dipindahkan persis dari implementasi MainActivity sebelumnya:
 * - Tidak pernah meminta/mengubah DND otomatis; [activate] gagal bila akses
 *   Notification Policy belum diberikan pengguna lewat pengaturan.
 * - Nilai filter sebelumnya dicommit sinkron SEBELUM diubah, supaya crash
 *   tidak menghilangkan data pemulihan.
 * - [restore] hanya mengembalikan nilai yang benar-benar diubah aplikasi;
 *   perubahan pengguna/aplikasi lain dihormati, tidak ditimpa.
 *
 * Arti "blokir" dibatasi jujur: meredam suara/getaran gangguan dan banner
 * pada cakupan yang didukung perangkat. Panel sistem TIDAK dijanjikan
 * tidak bisa dibuka (batas BYOD, PRD FR09).
 */
class NotificationGuardManager(context: Context) {

    private val appContext = context.applicationContext

    private val preferences: SharedPreferences by lazy {
        appContext.getSharedPreferences("examseal_protection", Context.MODE_PRIVATE)
    }

    private val notificationManager: NotificationManager
        get() = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N

    fun isAccessGranted(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            notificationManager.isNotificationPolicyAccessGranted
        } else {
            false
        }

    /** True bila filter saat ini meredam gangguan (bukan ALL). */
    fun isProtectionActive(): Boolean {
        if (!isAccessGranted()) return false
        return notificationManager.getCurrentInterruptionFilter() !=
            NotificationManager.INTERRUPTION_FILTER_ALL
    }

    private fun previousFilter(): Int? =
        if (preferences.contains(KEY_PREVIOUS_FILTER)) {
            preferences.getInt(KEY_PREVIOUS_FILTER, 0)
        } else {
            null
        }

    private fun ownsChange(): Boolean =
        preferences.getBoolean(KEY_OWNS_CHANGE, false)

    private fun prepareRestore(filter: Int): Boolean = preferences.edit()
        .putInt(KEY_PREVIOUS_FILTER, filter)
        .putBoolean(KEY_OWNS_CHANGE, true)
        .commit()

    private fun clearRestore(): Boolean = preferences.edit().clear().commit()

    /**
     * Aktifkan kontribusi DND milik aplikasi. False bila tidak didukung,
     * akses belum diberikan, atau filter tidak bisa diubah (mis. aturan
     * API 35+ tidak mengizinkan perubahan langsung).
     */
    fun activate(): Boolean {
        if (!isSupported() || !isAccessGranted()) return false
        val currentFilter = notificationManager.getCurrentInterruptionFilter()
        // Pada target API 35+, perubahan DND aplikasi berkontribusi lewat
        // aturan milik aplikasi; filter langsung hanya untuk perangkat
        // lebih lama yang masih mengizinkannya.
        if (currentFilter == NotificationManager.INTERRUPTION_FILTER_ALL) {
            if (!prepareRestore(currentFilter)) return false
            try {
                notificationManager.setInterruptionFilter(
                    NotificationManager.INTERRUPTION_FILTER_PRIORITY
                )
                if (notificationManager.getCurrentInterruptionFilter() ==
                    NotificationManager.INTERRUPTION_FILTER_ALL
                ) {
                    clearRestore()
                    return false
                }
            } catch (_: SecurityException) {
                if (notificationManager.getCurrentInterruptionFilter() == currentFilter) {
                    clearRestore()
                }
                return false
            } catch (_: RuntimeException) {
                if (notificationManager.getCurrentInterruptionFilter() == currentFilter) {
                    clearRestore()
                }
                return false
            }
        }
        return notificationManager.getCurrentInterruptionFilter() !=
            NotificationManager.INTERRUPTION_FILTER_ALL
    }

    /**
     * Pulihkan filter yang diubah aplikasi. True hanya bila pemulihan
     * benar-benar berhasil, agar Flutter menyediakan retry dan tidak
     * mengaku sudah dipulihkan.
     */
    fun restore(): Boolean {
        var restored = true
        val previous = previousFilter()
        if (previous != null && ownsChange()) {
            try {
                // Bila filter telah berubah ke nilai lain, hormati perubahan
                // pengguna/aplikasi lain dan jangan menimpanya.
                if (notificationManager.getCurrentInterruptionFilter() ==
                    NotificationManager.INTERRUPTION_FILTER_PRIORITY
                ) {
                    notificationManager.setInterruptionFilter(previous)
                    if (notificationManager.getCurrentInterruptionFilter() != previous) {
                        restored = false
                    }
                }
            } catch (_: SecurityException) {
                restored = false
            } catch (_: RuntimeException) {
                restored = false
            }
        }
        return restored && clearRestore()
    }

    companion object {
        private const val KEY_PREVIOUS_FILTER = "previous_interruption_filter"
        private const val KEY_OWNS_CHANGE = "owns_dnd_change"
    }
}
