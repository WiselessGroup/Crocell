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
import net.wiseless.crocell.core.mobile.Mobile
import org.json.JSONObject

/**
 * Holds the VPN while connected: builds the interface the core asks for,
 * keeps a notification up so Android leaves the process alone, and hands
 * the system's own VPN events (always-on start, revoke) to the core.
 */
class CrocellVpnService : VpnService() {
    companion object {
        private const val CHANNEL = "vpn"
        private const val NOTIFICATION = 10
        private const val ACTION_HOLD = "net.wiseless.crocell.HOLD"
        private const val ACTION_DISCONNECT = "net.wiseless.crocell.DISCONNECT"
        private const val ACTION_NOTIFICATION = "net.wiseless.crocell.NOTIFICATION"

        /** The person changed "hide notification": apply it to a running VPN. */
        fun notificationChoiceChanged(context: Context) {
            if (synchronized(lock) { instance } != null) {
                context.startService(Intent(context, CrocellVpnService::class.java).setAction(ACTION_NOTIFICATION))
            }
        }

        private val lock = Object()
        private var instance: CrocellVpnService? = null

        /** Whether Android blocks connections without the VPN. It only tells a running VPN, from Android 10 on. */
        fun lockdown(): Boolean? {
            val service = synchronized(lock) { instance } ?: return null
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) service.isLockdownEnabled else null
        }

        private const val EXTRA_PROXY_PORT = "proxy_port"

        /** Called by the core on its own thread: start the service, build the interface, return its fd. */
        fun open(context: Context, request: JSONObject): Int = start(context, 0).establish(request)

        /** Proxy mode: the same service and notification, no interface. */
        fun hold(context: Context, port: Int) {
            start(context, port)
        }

        private fun start(context: Context, proxyPort: Int): CrocellVpnService {
            context.startForegroundService(
                Intent(context, CrocellVpnService::class.java).setAction(ACTION_HOLD).putExtra(EXTRA_PROXY_PORT, proxyPort),
            )
            val deadline = System.currentTimeMillis() + 10_000
            val service = synchronized(lock) {
                while (instance == null) {
                    val left = deadline - System.currentTimeMillis()
                    if (left <= 0) throw IllegalStateException(context.getString(R.string.vpn_service_timeout))
                    lock.wait(left)
                }
                instance!!
            }
            return service
        }

        fun close(@Suppress("UNUSED_PARAMETER") context: Context) {
            synchronized(lock) { instance.also { instance = null } }?.stop()
        }
    }

    /** Non-zero in proxy mode: the notification says where the proxy is. */
    private var proxyPort = 0

    /** The VPN interface is up: the system holds this service, no notification needed. */
    private var tunUp = false

    /**
     * With the VPN up, Android binds this service as a foreground one by
     * itself, so the notification can go if the person does not want it.
     * Proxy mode has no such binding and keeps it, or the proxy is frozen.
     */
    private fun applyNotificationChoice() {
        if (tunUp && proxyPort == 0 && Prefs.hideNotification(this)) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            startForeground()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DISCONNECT -> {
                Thread { Mobile.disconnect() }.start()
                return START_NOT_STICKY
            }
            ACTION_HOLD -> {
                proxyPort = intent.getIntExtra(EXTRA_PROXY_PORT, 0)
                if (proxyPort > 0) tunUp = false
            }
            ACTION_NOTIFICATION -> {
                applyNotificationChoice()
                return START_STICKY
            }
            // Started by the system: always-on VPN, or after a reboot.
            else -> Thread {
                try {
                    Mobile.connect()
                } catch (e: Exception) {
                    Core.log("always-on connect failed: ${e.message}")
                }
            }.start()
        }
        startForeground()
        synchronized(lock) {
            instance = this
            lock.notifyAll()
        }
        CrocellTile.refresh(this)
        return START_STICKY
    }

    /** Another VPN took over, or the person turned Crocell off in Settings. */
    override fun onRevoke() {
        Core.log("VPN revoked by the system (another VPN, or turned off in Settings)")
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
        val pfd = b.establish() ?: throw IllegalStateException(getString(R.string.vpn_establish_null))
        Core.log("VPN interface up")
        tunUp = true
        applyNotificationChoice()
        return pfd.detachFd()
    }

    private fun stop() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        CrocellTile.refresh(this)
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
            NotificationChannel(CHANNEL, getString(R.string.vpn_channel), NotificationManager.IMPORTANCE_LOW).apply {
                description = getString(R.string.vpn_channel_description)
                setShowBadge(false)
            },
        )
        val disconnect = PendingIntent.getService(
            this, 1, Intent(this, CrocellVpnService::class.java).setAction(ACTION_DISCONNECT), PendingIntent.FLAG_IMMUTABLE,
        )
        val n = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(getString(R.string.vpn_connected))
            .setContentText(
                if (proxyPort > 0) getString(R.string.proxy_running, proxyPort) else getString(R.string.vpn_tap_to_open),
            )
            .setContentIntent(openApp())
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, getString(R.string.vpn_disconnect), disconnect).build())
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION, n)
        }
    }
}
