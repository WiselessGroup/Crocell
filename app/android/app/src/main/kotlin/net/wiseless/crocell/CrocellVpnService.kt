package net.wiseless.crocell

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.util.Log
import net.wiseless.crocell.core.mobile.Mobile
import org.json.JSONObject

/**
 * Holds the VPN while connected: builds the interface the core asks for,
 * keeps a notification up so Android leaves the process alone, and hands
 * the system's own VPN events (always-on start, revoke) to the core.
 */
class CrocellVpnService : VpnService() {
    companion object {
        private const val TAG = "Crocell"
        private const val CHANNEL = "vpn"
        private const val NOTIFICATION = 10
        private const val ACTION_HOLD = "net.wiseless.crocell.HOLD"
        private const val ACTION_DISCONNECT = "net.wiseless.crocell.DISCONNECT"

        private val lock = Object()
        private var instance: CrocellVpnService? = null

        /** Called by the core on its own thread: start the service, build the interface, return its fd. */
        fun open(context: Context, request: JSONObject): Int {
            context.startForegroundService(Intent(context, CrocellVpnService::class.java).setAction(ACTION_HOLD))
            val deadline = System.currentTimeMillis() + 10_000
            val service = synchronized(lock) {
                while (instance == null) {
                    val left = deadline - System.currentTimeMillis()
                    if (left <= 0) throw IllegalStateException("Служба VPN не запустилась")
                    lock.wait(left)
                }
                instance!!
            }
            return service.establish(request)
        }

        fun close(@Suppress("UNUSED_PARAMETER") context: Context) {
            synchronized(lock) { instance.also { instance = null } }?.stop()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DISCONNECT -> {
                Thread { Mobile.disconnect() }.start()
                return START_NOT_STICKY
            }
            ACTION_HOLD -> Unit
            // Started by the system: always-on VPN, or after a reboot.
            else -> Thread {
                try {
                    Mobile.connect()
                } catch (e: Exception) {
                    Log.w(TAG, "always-on connect failed", e)
                }
            }.start()
        }
        startForeground()
        synchronized(lock) {
            instance = this
            lock.notifyAll()
        }
        return START_STICKY
    }

    /** Another VPN took over, or the person turned Crocell off in Settings. */
    override fun onRevoke() {
        Thread { Mobile.disconnect() }.start()
    }

    override fun onDestroy() {
        synchronized(lock) { if (instance === this) instance = null }
        super.onDestroy()
    }

    private fun establish(r: JSONObject): Int {
        val b = Builder().setSession("Crocell").setMtu(r.optInt("MTU", 9000))
        addCidr(b, r.getString("Address4"))
        b.addRoute("0.0.0.0", 0)
        r.optString("Address6").takeIf { it.isNotEmpty() }?.let {
            addCidr(b, it)
            b.addRoute("::", 0)
        }
        b.addDnsServer(r.getString("DNS"))
        val allow = r.optJSONArray("Allow")
        val disallow = r.optJSONArray("Disallow")
        if (allow != null && allow.length() > 0) {
            for (i in 0 until allow.length()) skipMissing { b.addAllowedApplication(allow.getString(i)) }
        } else if (disallow != null) {
            for (i in 0 until disallow.length()) skipMissing { b.addDisallowedApplication(disallow.getString(i)) }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) b.setMetered(false)
        b.setConfigureIntent(openApp())
        val pfd = b.establish() ?: throw IllegalStateException("Android не дал создать VPN: разрешение отозвано")
        return pfd.detachFd()
    }

    private fun stop() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun addCidr(b: Builder, cidr: String) {
        val (addr, bits) = cidr.split("/")
        b.addAddress(addr, bits.toInt())
    }

    // An app from the rules may have been uninstalled since.
    private inline fun skipMissing(add: () -> Unit) {
        try {
            add()
        } catch (_: Exception) {
        }
    }

    private fun openApp(): PendingIntent = PendingIntent.getActivity(
        this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
    )

    private fun startForeground() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "VPN включён", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Пока висит это уведомление, Crocell держит VPN"
                setShowBadge(false)
            },
        )
        val disconnect = PendingIntent.getService(
            this, 1, Intent(this, CrocellVpnService::class.java).setAction(ACTION_DISCONNECT), PendingIntent.FLAG_IMMUTABLE,
        )
        val n = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Crocell подключён")
            .setContentText("Нажмите, чтобы открыть")
            .setContentIntent(openApp())
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, "Отключить", disconnect).build())
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION, n)
        }
    }
}
