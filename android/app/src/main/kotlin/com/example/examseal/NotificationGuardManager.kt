package com.yows.examseal

import android.app.NotificationManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build

/**
 * DND milik aplikasi (FR09). Tanpa auto-minta akses; commit sync sebelum ubah; pulihkan hanya milik sendiri.
 * Meredam suara/getar/banner yang didukung; panel sistem BYOD tidak dijanjikan tertutup.
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
     * False bila tak didukung, akses ditolak, atau API 35+ menolak ubah langsung.
     */
    fun activate(): Boolean {
        if (!isSupported() || !isAccessGranted()) return false
        val currentFilter = notificationManager.getCurrentInterruptionFilter()
        // API 35+ via aturan aplikasi; perangkat lama via filter langsung.
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

    /** True hanya bila benar-benar pulih, agar Flutter bisa retry jujur. */
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
