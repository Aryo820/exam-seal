package com.example.examseal

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.os.Build
import java.lang.ref.WeakReference

/**
 * Kunci layar ExamSeal via screen pinning OS (tanpa device owner,
 * tanpa provisioning, tanpa wipe HP, tanpa izin manifest).
 *
 * Efek yang diberikan OS saat ter-pin: bilah notifikasi tidak bisa
 * ditarik, tombol Home/Recent tidak berfungsi. Satu-satunya jalan keluar
 * yang disisakan OS adalah kombinasi tahan Back+Recent — momen itu selalu
 * melewati lifecycle (pause/leaveHint) sehingga terdeteksi Flutter dan
 * dihitung sebagai pelanggaran langsung (matriks v3, PRD FR05/Q03).
 *
 * Batasan jujur:
 * - Pertama kali selalu muncul dialog persetujuan sistem yang harus
 *   ditekan pengguna. Penolakan/pembatalan berarti pin tidak aktif —
 *   Flutter wajib memverifikasi lewat [isPinned], bukan memercayai
 *   permintaan yang terkirim.
 * - Verifikasi tidak bisa sinkron sesaat setelah [requestPin] karena
 *   persetujuan bersifat asinkron; Flutter melakukan polling.
 * - Panggilan telepon dan tombol power tetap bisa menginterupsi.
 *
 * Memakai [WeakReference] agar tidak membocorkan Activity saat recreate.
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
            // LOCK_TASK_MODE_PINNED = pinning tanpa device owner (kasus
            // kita); LOCK_TASK_MODE_LOCKED = device owner (tak dipakai,
            // tapi tetap dianggap terkunci bila entah bagaimana aktif).
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
     * Minta OS mem-pin activity. Tanpa device owner, OS menampilkan dialog
     * persetujuan sistem — mengembalikan true hanya berarti permintaan
     * terkirim, BUKAN berarti sudah ter-pin. Pemanggil wajib memverifikasi
     * lewat [isPinned] (polling) sebelum menganggap layar terkunci.
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

    /**
     * Lepas pin. Sinkron dan tanpa dialog — hasil diverifikasi langsung.
     * Idempoten: aman dipanggil saat tidak ter-pin.
     */
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
