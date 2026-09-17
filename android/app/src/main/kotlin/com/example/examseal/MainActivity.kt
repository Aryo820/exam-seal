package com.example.examseal

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge proteksi ExamSeal. Satu MethodChannel `examseal/protection`:
 * - checkStatus: dukungan + FLAG_SECURE + akses Notification Policy,
 * - activate: FLAG_SECURE + filter notifikasi DND milik aplikasi,
 * - restore/deactivate: lepaskan FLAG_SECURE + pulihkan pengaturan,
 * - openNotificationPolicySettings: buka pengaturan atas aksi eksplisit.
 *
 * Klaim dibatasi pada kemampuan yang benar-benar tersedia di perangkat:
 * tidak mengklaim panel notifikasi pasti tidak dapat dibuka, screenshot
 * pasti terblokir di semua HP, atau Google Forms pasti sudah submit.
 * Akses DND tidak pernah diminta/diubah otomatis saat aplikasi dibuka.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "examseal/protection"
    private val protectionPreferences by lazy {
        getSharedPreferences("examseal_protection", Context.MODE_PRIVATE)
    }

    private val notificationManager: NotificationManager
        get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun previousInterruptionFilter(): Int? =
        if (protectionPreferences.contains("previous_interruption_filter")) {
            protectionPreferences.getInt("previous_interruption_filter", 0)
        } else {
            null
        }

    private fun ownsDndChange(): Boolean =
        protectionPreferences.getBoolean("owns_dnd_change", false)

    /** Commit sinkron sebelum DND diubah, supaya crash tidak melupakan nilai pengguna. */
    private fun prepareDndRestore(filter: Int): Boolean = protectionPreferences.edit()
        .putInt("previous_interruption_filter", filter)
        .putBoolean("owns_dnd_change", true)
        .commit()

    private fun clearDndRestore(): Boolean = protectionPreferences.edit().clear().commit()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "checkStatus" -> result.success(checkStatus())
                        "activate" -> {
                            val activated = activate()
                            result.success(activated)
                        }
                        "restore", "deactivate" -> {
                            val restored = restore()
                            result.success(restored)
                        }
                        "openNotificationPolicySettings" -> {
                            openNotificationPolicySettings()
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("protection_error", e.message, null)
                }
            }
    }

    private fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N

    private fun isNotificationPolicyAccessGranted(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            notificationManager.isNotificationPolicyAccessGranted
        } else {
            false
        }

    private fun checkStatus(): Map<String, Any?> {
        if (!isSupported()) {
            return mapOf(
                "supported" to false,
                "secureWindowActive" to false,
                "notificationAccessGranted" to false,
                "notificationProtectionActive" to false,
                "error" to "Proteksi ExamSeal membutuhkan Android 7.0 (API 24) ke atas."
            )
        }
        val accessGranted = isNotificationPolicyAccessGranted()
        val secureActive =
            window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0
        val dndActive = if (accessGranted) {
            notificationManager.getCurrentInterruptionFilter() !=
                NotificationManager.INTERRUPTION_FILTER_ALL
        } else {
            false
        }
        return mapOf(
            "supported" to true,
            "secureWindowActive" to secureActive,
            "notificationAccessGranted" to accessGranted,
            "notificationProtectionActive" to dndActive,
            "error" to null
        )
    }

    /**
     * Aktifkan proteksi: FLAG_SECURE + kontribusi DND sesuai aturan milik
     * aplikasi. Mengembalikan false bila akses Notification Policy belum
     * diberikan — readiness harus gagal dan tombol mulai tetap nonaktif.
     * Pengaturan sebelumnya dicommit sebelum filter diubah, sehingga crash
     * tidak menghilangkan data pemulihan.
     */
    private fun activate(): Boolean {
        if (!isSupported() || !isNotificationPolicyAccessGranted()) {
            return false
        }
        val currentFilter = notificationManager.getCurrentInterruptionFilter()
        // Pada target API 35+, perubahan DND aplikasi berkontribusi lewat
        // aturan milik aplikasi; filter langsung hanya untuk perangkat
        // lebih lama yang masih mengizinkannya.
        if (currentFilter == NotificationManager.INTERRUPTION_FILTER_ALL) {
            if (!prepareDndRestore(currentFilter)) {
                return false
            }
            try {
                notificationManager.setInterruptionFilter(
                    NotificationManager.INTERRUPTION_FILTER_PRIORITY
                )
                if (notificationManager.getCurrentInterruptionFilter() ==
                    NotificationManager.INTERRUPTION_FILTER_ALL
                ) {
                    clearDndRestore()
                    return false
                }
            } catch (_: SecurityException) {
                if (notificationManager.getCurrentInterruptionFilter() == currentFilter) {
                    clearDndRestore()
                }
                return false
            } catch (_: RuntimeException) {
                if (notificationManager.getCurrentInterruptionFilter() == currentFilter) {
                    clearDndRestore()
                }
                return false
            }
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        return window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0 &&
            notificationManager.getCurrentInterruptionFilter() !=
                NotificationManager.INTERRUPTION_FILTER_ALL
    }

    /**
     * Lepas FLAG_SECURE dan pulihkan pengaturan notifikasi yang diubah
     * aplikasi. Hanya mengembalikan nilai yang benar-benar dipulihkan;
     * kegagalan mengembalikan false agar UI menyediakan retry dan tidak
     * mengaku sudah dipulihkan.
     */
    private fun restore(): Boolean {
        var restored = true
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        if (window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0) {
            restored = false
        }

        val previous = previousInterruptionFilter()
        if (previous != null && ownsDndChange()) {
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
        return restored && clearDndRestore()
    }

    /** Buka pengaturan akses Notification Policy atas aksi eksplisit. */
    private fun openNotificationPolicySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    override fun onStop() {
        super.onStop()
        // FLAG_SECURE dipertahankan saat attempt berlangsung; status
        // dibaca ulang oleh Flutter saat resume.
    }
}
