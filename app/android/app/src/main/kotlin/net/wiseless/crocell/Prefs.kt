package net.wiseless.crocell

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings

/** The Android-only choices the Flutter side sets over the crocell/core channel. */
object Prefs {
    private const val FILE = "crocell"
    private const val HIDE_NOTIFICATION = "hide_notification"

    fun hideNotification(context: Context): Boolean =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getBoolean(HIDE_NOTIFICATION, false)

    fun setHideNotification(context: Context, hide: Boolean) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().putBoolean(HIDE_NOTIFICATION, hide).apply()
        CrocellVpnService.notificationChoiceChanged(context)
    }

    fun batteryUnrestricted(context: Context): Boolean =
        context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(context.packageName)

    /** Android's own "let this app run in the background" dialog. */
    @SuppressLint("BatteryLife")
    fun askBatteryUnrestricted(context: Context) {
        if (batteryUnrestricted(context)) return
        context.startActivity(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${context.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}
