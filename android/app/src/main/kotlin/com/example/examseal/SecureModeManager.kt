package com.yows.examseal

import android.app.Activity
import android.view.WindowManager
import java.lang.ref.WeakReference

/**
 * FLAG_SECURE (FR08) via WeakReference. Cegah screenshot/rekaman yang didukung; tidak cegah Home/Recent.
 */
class SecureModeManager(activity: Activity) {

    private val activityRef = WeakReference(activity)

    fun isActive(): Boolean {
        val activity = activityRef.get() ?: return false
        return activity.window.attributes.flags and
            WindowManager.LayoutParams.FLAG_SECURE != 0
    }

    /** True hanya bila flag terverifikasi terpasang. */
    fun enable(): Boolean {
        val activity = activityRef.get() ?: return false
        activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        return isActive()
    }

    /** True hanya bila flag terverifikasi sudah lepas. */
    fun disable(): Boolean {
        val activity = activityRef.get() ?: return false
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        return !isActive()
    }
}
