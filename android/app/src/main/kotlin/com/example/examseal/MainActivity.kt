package com.example.examseal

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
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
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "examseal/protection"

    // Pengaturan milik pengguna yang berubah karena aplikasi, disimpan
    // agar hanya pengaturan milik aplikasi yang dipulihkan.
    private var previousInterruptionFilter: Int? = null
    private var ownedDndRules = false

    private val notificationManager: NotificationManager
        get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

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

    private fun checkStatus(): Map<String, Any> {
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
     * Pengaturan sebelumnya disimpan agar hanya milik aplikasi yang
     * dipulihkan saat attempt berakhir.
     */
    private fun activate(): Boolean {
        if (!isSupported() || !isNotificationPolicyAccessGranted()) {
            return false
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        val currentFilter = notificationManager.getCurrentInterruptionFilter()
        if (previousInterruptionFilter == null) {
            previousInterruptionFilter = currentFilter
        }
        // Pada target API 35+, perubahan DND aplikasi berkontribusi lewat
        // aturan milik aplikasi; filter langsung hanya untuk perangkat
        // lebih lama yang masih mengizinkannya.
        if (currentFilter == NotificationManager.INTERRUPTION_FILTER_ALL) {
            try {
                notificationManager.setInterruptionFilter(
                    NotificationManager.INTERRUPTION_FILTER_PRIORITY
                )
                ownedDndRules = true
            } catch (_: SecurityException) {
                // Beberapa vendor membatasi perubahan filter; proteksi
                // notifikasi dilaporkan tidak aktif secara jujur.
                ownedDndRules = false
            }
        }
        return true
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

        val previous = previousInterruptionFilter
        if (previous != null && ownedDndRules) {
            try {
                notificationManager.setInterruptionFilter(previous)
            } catch (_: SecurityException) {
                restored = false
            } catch (_: RuntimeException) {
                restored = false
            }
        }
        previousInterruptionFilter = null
        ownedDndRules = false
        return restored
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
