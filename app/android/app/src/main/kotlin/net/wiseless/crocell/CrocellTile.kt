package net.wiseless.crocell

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import net.wiseless.crocell.core.mobile.Mobile

/**
 * The Crocell button in Quick Settings: one tap connects to the last node,
 * another disconnects. Before the first VPN permission it opens the app,
 * since only an activity can ask for it.
 */
class CrocellTile : TileService() {
    companion object {
        /** Asks the system to redraw the tile, after the VPN went up or down. */
        fun refresh(context: Context) {
            requestListeningState(context, ComponentName(context, CrocellTile::class.java))
        }
    }

    override fun onStartListening() = render(Mobile.state())

    override fun onClick() {
        when (Mobile.state()) {
            "connected" -> {
                render("disconnecting")
                background { Mobile.disconnect() }
            }
            "connecting", "disconnecting" -> Unit
            else -> {
                if (VpnService.prepare(this) != null) {
                    openApp()
                    return
                }
                render("connecting")
                background {
                    try {
                        Mobile.connect()
                    } catch (e: Exception) {
                        Core.log("tile connect failed: ${e.message}")
                    }
                }
            }
        }
    }

    // While the panel is open the tile is already listening, so asking the
    // system to refresh it does nothing: draw the outcome ourselves.
    private fun background(work: () -> Unit) = Thread {
        work()
        val state = Mobile.state()
        main.post { render(state) }
    }.start()

    private val main = Handler(Looper.getMainLooper())

    private fun render(state: String) {
        val tile = qsTile ?: return
        tile.icon = Icon.createWithResource(this, AppIcons.small(this))
        tile.label = getString(R.string.tile_label)
        tile.state = if (state == "connected") Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = when (state) {
                "connecting" -> getString(R.string.tile_connecting)
                "disconnecting" -> getString(R.string.tile_disconnecting)
                else -> null
            }
        }
        tile.updateTile()
    }

    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE))
        } else {
            @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
            startActivityAndCollapse(intent)
        }
    }
}
