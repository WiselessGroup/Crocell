package net.wiseless.crocell

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.util.Log
import java.io.File
import net.wiseless.crocell.core.mobile.Mobile
import net.wiseless.crocell.core.mobile.Platform
import org.json.JSONArray
import org.json.JSONObject

/**
 * The Go core inside the app: the same service as crocelld on the desktop,
 * on a unix socket in the private directory. The Flutter client talks to it
 * over that socket; VpnService builds the interface when it asks.
 */
object Core {
    private const val TAG = "Crocell"

    @Volatile var startError: String? = null
        private set

    /** Into the log the app's "Logs" button copies, and logcat. */
    fun log(text: String) {
        Log.i(TAG, text)
        try {
            Mobile.log(text)
        } catch (_: Throwable) {
        }
    }

    fun socketPath(context: Context): String = File(context.noBackupFilesDir, "core.sock").path

    fun start(context: Context) {
        val app = context.applicationContext
        try {
            Mobile.start(
                File(app.noBackupFilesDir, "state").path,
                socketPath(app),
                app.packageName,
                KeyVault.stateKey(app),
                AndroidPlatform(app),
            )
        } catch (e: Exception) {
            startError = e.message
            Log.e(TAG, "core did not start", e)
        }
    }

    private class AndroidPlatform(private val context: Context) : Platform {
        override fun openTun(request: String): Int {
            try {
                if (VpnService.prepare(context) != null) {
                    throw IllegalStateException(context.getString(R.string.vpn_not_allowed))
                }
                return CrocellVpnService.open(context, JSONObject(request))
            } catch (e: Exception) {
                log("openTun: ${e.javaClass.simpleName}: ${e.message}")
                throw e
            }
        }

        override fun holdProxy(port: Int) {
            try {
                CrocellVpnService.hold(context, port)
            } catch (e: Exception) {
                log("holdProxy: ${e.javaClass.simpleName}: ${e.message}")
                throw e
            }
        }

        override fun closeTun() = CrocellVpnService.close(context)

        override fun installedApps(): String {
            val pm = context.packageManager
            val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            val seen = HashSet<String>()
            val out = JSONArray()
            for (info in pm.queryIntentActivities(launcher, PackageManager.MATCH_ALL)) {
                val pkg = info.activityInfo.packageName
                if (pkg == context.packageName || !seen.add(pkg)) continue
                out.put(JSONObject().put("package", pkg).put("label", info.loadLabel(pm).toString()))
            }
            return out.toString()
        }
    }
}
