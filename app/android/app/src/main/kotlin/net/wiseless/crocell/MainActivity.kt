package net.wiseless.crocell

import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val askVpn = 7
    private var pendingVpn: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "crocell/core").setMethodCallHandler { call, result ->
            when (call.method) {
                "socketPath" -> result.success(Core.socketPath(this))
                "startError" -> result.success(Core.startError)
                "setIcon" -> {
                    AppIcons.select(this, call.arguments as String)
                    result.success(null)
                }
                "hideNotification" -> result.success(Prefs.hideNotification(this))
                "setHideNotification" -> {
                    val hide = call.arguments as Boolean
                    Prefs.setHideNotification(this, hide)
                    if (hide) Prefs.askBatteryUnrestricted(this)
                    result.success(null)
                }
                "batteryUnrestricted" -> result.success(Prefs.batteryUnrestricted(this))
                // Android shows its "allow VPN" dialog once; after that prepare() returns null.
                "prepareVpn" -> {
                    val ask = VpnService.prepare(this)
                    if (ask == null) {
                        result.success(true)
                    } else {
                        pendingVpn = result
                        startActivityForResult(ask, askVpn)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("startActivityForResult is what VpnService.prepare is built for")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == askVpn) {
            pendingVpn?.success(resultCode == RESULT_OK)
            pendingVpn = null
        }
    }
}
