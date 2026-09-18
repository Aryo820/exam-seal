package com.example.examseal

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Getar + nada (FR10, maks 3000ms). Volume tak dijamin vendor; selalu dipulihkan. Tanpa counter ujian.
 */
class WarningManager(context: Context) {

    private val appContext = context.applicationContext

    private val audioManager: AudioManager
        get() = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val vibrator: Vibrator?
        get() = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = appContext.getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                    as VibratorManager
                manager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                appContext.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
        } catch (_: RuntimeException) {
            null
        } catch (_: SecurityException) {
            null
        }

    private val lock = Any()

    private var toneGenerator: ToneGenerator? = null

    /** Volume STREAM_MUSIC milik pengguna sebelum diubah, null bila belum diubah. */
    private var savedVolume: Int? = null

    private var sounding = false

    /** Izin VIBRATE sudah di manifest. False berarti tak bisa getar, bukan fatal. */
    fun vibrateWarning(durationMs: Long): Boolean {
        val capped = durationMs.coerceIn(1L, MAX_ALERT_MS)
        return try {
            val vib = vibrator ?: return false
            if (!vib.hasVibrator()) return false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vib.vibrate(
                    VibrationEffect.createOneShot(
                        capped,
                        VibrationEffect.DEFAULT_AMPLITUDE
                    )
                )
            } else {
                @Suppress("DEPRECATION")
                vib.vibrate(capped)
            }
            true
        } catch (_: SecurityException) {
            false
        } catch (_: RuntimeException) {
            false
        }
    }

    /** Simpan volume, coba maksimum best-effort, bunyi; pulih di stop. Gagal tetap pulihkan volume. */
    fun playWarningSound(durationMs: Long): Boolean {
        val capped = durationMs.coerceIn(1L, MAX_ALERT_MS).toInt()
        synchronized(lock) {
            if (sounding) return true
            return try {
                val manager = audioManager
                savedVolume = manager.getStreamVolume(AudioManager.STREAM_MUSIC)
                val max = manager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                // Best-effort: vendor boleh menolak; jangan gagal karenanya.
                try {
                    manager.setStreamVolume(AudioManager.STREAM_MUSIC, max, 0)
                } catch (_: SecurityException) {
                } catch (_: RuntimeException) {
                }
                val generator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                toneGenerator = generator
                sounding = true
                generator.startTone(TONE, capped)
                true
            } catch (_: RuntimeException) {
                restoreVolumeLocked()
                false
            } catch (_: SecurityException) {
                restoreVolumeLocked()
                false
            }
        }
    }

    /** Hentikan nada dan pulihkan volume. Idempoten. */
    fun stopWarningSound(): Boolean {
        synchronized(lock) {
            return try {
                try {
                    toneGenerator?.stopTone()
                } catch (_: RuntimeException) {
                    // Nada mungkin sudah selesai sendiri; abaikan.
                }
                releaseGeneratorLocked()
                restoreVolumeLocked()
                sounding = false
                true
            } catch (_: RuntimeException) {
                restoreVolumeLocked()
                sounding = false
                false
            }
        }
    }

    /** True bila nada peringatan sedang berbunyi. */
    fun isSounding(): Boolean = synchronized(lock) { sounding }

    /** Wajib saat activity/engine hancur agar nada/volume tidak tertinggal. */
    fun release() {
        stopWarningSound()
    }

    private fun releaseGeneratorLocked() {
        try {
            toneGenerator?.release()
        } catch (_: RuntimeException) {
            // Abaikan: rilis best-effort.
        } finally {
            toneGenerator = null
        }
    }

    private fun restoreVolumeLocked() {
        val previous = savedVolume ?: return
        savedVolume = null
        try {
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, previous, 0)
        } catch (_: SecurityException) {
            // Best-effort: catat kegagalan lewat nilai kembalian pemanggil.
        } catch (_: RuntimeException) {
            // Best-effort.
        }
    }

    companion object {
        /** FR10: bunyi/getar singkat maksimal tiga detik per pelanggaran. */
        const val MAX_ALERT_MS = 3000L

        /** ToneGenerator bawaan agar tanpa aset; ganti nada tanpa ubah kontrak channel. */
        private const val TONE = ToneGenerator.TONE_CDMA_ABBR_ALERT
    }
}
