package com.example.examseal

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Peringatan native ExamSeal: getar + nada (PRD FR10).
 *
 * Batasan jujur yang ditegakkan di sini:
 * - Durasi dibatasi maksimal 2000ms per panggilan (FR10: singkat, tanpa
 *   pengulangan terus-menerus).
 * - Volume maksimum TIDAK dijamin: vendor/Android bisa menolak perubahan.
 *   Kegagalan dilaporkan sebagai false, bukan crash.
 * - Volume pengguna SELALU dipulihkan (termasuk saat gagal dan saat
 *   [release]), agar tidak ada volume yang tertinggal berubah.
 * - Perangkat tanpa vibrator: getar mengembalikan false dengan aman.
 *
 * Tidak ada aturan bisnis ujian di sini (tidak ada counter/strike):
 * kapan memperingatkan diputuskan Flutter.
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

    /**
     * Getarkan peringatan sekali, maksimal [MAX_ALERT_MS]. Izin VIBRATE
     * sudah dideklarasikan di manifest (normal permission). False bila
     * perangkat tidak bisa bergetar — bukan error fatal.
     */
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

    /**
     * Bunyikan nada peringatan: simpan volume → coba naikkan ke maksimum
     * yang diizinkan → bunyi → (pemulihan dilakukan di [stopWarningSound]
     * atau otomatis oleh pemanggil setelah selesai).
     *
     * Mengembalikan false bila nada tidak bisa dibunyikan; volume yang
     * sempat diubah tetap dipulihkan sebelum returning false.
     */
    fun playWarningSound(durationMs: Long): Boolean {
        val capped = durationMs.coerceIn(1L, MAX_ALERT_MS).toInt()
        synchronized(lock) {
            if (sounding) return true
            return try {
                val manager = audioManager
                // Simpan volume pengguna SEBELUM mengubah apa pun.
                savedVolume = manager.getStreamVolume(AudioManager.STREAM_MUSIC)
                val max = manager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                // Best-effort: vendor boleh menolak; jangan gagal karenanya.
                try {
                    manager.setStreamVolume(AudioManager.STREAM_MUSIC, max, 0)
                } catch (_: SecurityException) {
                    // Lanjut dengan volume apa adanya.
                } catch (_: RuntimeException) {
                    // Lanjut dengan volume apa adanya.
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

    /**
     * Hentikan nada (bila berbunyi) dan pulihkan volume pengguna.
     * Idempoten: aman dipanggil berulang atau saat tidak berbunyi.
     */
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

    /**
     * Lepaskan semua resource native. Wajib dipanggil saat activity/engine
     * dihancurkan agar tidak ada MediaPlayer/ToneGenerator gantung dan
     * tidak ada volume yang tertinggal berubah.
     */
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
        /** FR10: bunyi/getar singkat maksimal dua detik per pelanggaran. */
        const val MAX_ALERT_MS = 2000L

        /**
         * Nada peringatan. Fondasi V1 memakai ToneGenerator bawaan agar
         * tanpa file aset; dapat diganti file nada khusus tanpa mengubah
         * kontrak channel.
         */
        private const val TONE = ToneGenerator.TONE_CDMA_ABBR_ALERT
    }
}
