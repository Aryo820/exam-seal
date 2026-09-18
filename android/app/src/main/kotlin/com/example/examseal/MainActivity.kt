package com.example.examseal

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Activity tipis: teruskan Method/EventChannel ke manager. Tanpa counter/aturan pelanggaran.
 * API lama dipertahankan persis untuk kompatibilitas Dart/test.
 */
class MainActivity : FlutterActivity() {

    private lateinit var secureMode: SecureModeManager
    private lateinit var notificationGuard: NotificationGuardManager
    private lateinit var warningManager: WarningManager
    private lateinit var examGuard: ExamGuardManager
    private lateinit var screenPin: ScreenPinManager

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        secureMode = SecureModeManager(this)
        notificationGuard = NotificationGuardManager(this)
        warningManager = WarningManager(this)
        examGuard = ExamGuardManager()
        screenPin = ScreenPinManager(this)
        // Daftarkan observer lifecycle sekali ke Application (aman
        // dipanggil berulang; pendaftarannya sendiri idempoten).
        application?.let { examGuard.observer.registerOnce(it) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        methodChannel = MethodChannel(messenger, CHANNEL_METHODS)
            .also { it.setMethodCallHandler(::handleMethodCall) }
        eventChannel = EventChannel(messenger, CHANNEL_EVENTS)
            .also {
                it.setStreamHandler(
                    object : EventChannel.StreamHandler {
                        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                            examGuard.attachSink(events)
                        }

                        override fun onCancel(arguments: Any?) {
                            examGuard.detachSink()
                        }
                    }
                )
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Lepas sink agar tidak ada callback ke engine yang sudah mati.
        examGuard.detachSink()
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (::examGuard.isInitialized) {
            examGuard.observer.onWindowFocusChanged(hasFocus)
        }
    }

    /**
     * Hanya untuk keluar disengaja (Home/Recent); bukan panggilan/dialog. Diteruskan mentah untuk matriks FR05.
     */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (::examGuard.isInitialized) {
            examGuard.observer.onUserLeaveHint()
        }
    }

    override fun onDestroy() {
        // Pastikan tidak ada monitoring, nada, atau volume yang tertinggal.
        if (::examGuard.isInitialized) examGuard.stop()
        if (::warningManager.isInitialized) warningManager.release()
        super.onDestroy()
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "checkStatus" -> result.success(checkStatus())
                "activate" -> result.success(activate())
                "restore", "deactivate" -> result.success(restore())
                "openNotificationPolicySettings" -> {
                    openNotificationPolicySettings()
                    result.success(true)
                }
                "enableSecureMode" -> result.success(secureMode.enable())
                "disableSecureMode" -> result.success(secureMode.disable())
                "startExamGuard" -> result.success(examGuard.start())
                "stopExamGuard" -> result.success(examGuard.stop())
                "isExamGuardActive" -> result.success(examGuard.isActive())
                "vibrateWarning" -> {
                    val duration = (call.argument<Number>("durationMs")?.toLong() ?: 3000L)
                        .coerceIn(1L, WarningManager.MAX_ALERT_MS)
                    result.success(warningManager.vibrateWarning(duration))
                }
                "playWarningSound" -> {
                    val duration = (call.argument<Number>("durationMs")?.toLong() ?: 3000L)
                        .coerceIn(1L, WarningManager.MAX_ALERT_MS)
                    result.success(warningManager.playWarningSound(duration))
                }
                "stopWarningSound" -> result.success(warningManager.stopWarningSound())
                "isWarningSounding" -> result.success(warningManager.isSounding())
                // Permintaan terkirim belum berarti ter-pin; Flutter verifikasi via polling karena dialog sistem asinkron.
                "requestScreenPin" -> result.success(screenPin.requestPin())
                "stopScreenPin" -> result.success(screenPin.stopPin())
                "isScreenPinned" -> result.success(screenPin.isPinned())
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("protection_error", e.message, null)
        }
    }

    private fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N

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
        return mapOf(
            "supported" to true,
            "secureWindowActive" to secureMode.isActive(),
            "notificationAccessGranted" to notificationGuard.isAccessGranted(),
            "notificationProtectionActive" to notificationGuard.isProtectionActive(),
            "error" to null
        )
    }

    /**
     * FLAG_SECURE + DND milik aplikasi, terverifikasi. False bila akses Policy belum diberikan.
     */
    private fun activate(): Boolean {
        if (!isSupported() || !notificationGuard.isAccessGranted()) {
            return false
        }
        if (!notificationGuard.activate()) {
            return false
        }
        if (!secureMode.enable()) {
            notificationGuard.restore()
            return false
        }
        val verified = secureMode.isActive() && notificationGuard.isProtectionActive()
        if (!verified) restore()
        return verified
    }

    /** Lepas FLAG_SECURE dan pulihkan DND yang diubah aplikasi. */
    private fun restore(): Boolean {
        val secureRestored = secureMode.disable()
        val dndRestored = notificationGuard.restore()
        return secureRestored && dndRestored
    }

    /** Buka pengaturan akses Notification Policy atas aksi eksplisit. */
    private fun openNotificationPolicySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    companion object {
        /** MethodChannel lama — dipertahankan agar Dart + test lama kompatibel. */
        const val CHANNEL_METHODS = "examseal/protection"

        /** EventChannel baru untuk sinyal native → Flutter. */
        const val CHANNEL_EVENTS = "examseal/exam_guard_events"
    }
}
