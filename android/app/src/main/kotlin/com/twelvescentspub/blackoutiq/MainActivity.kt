package com.twelvescentspub.blackoutiq

import android.app.ActivityManager
import android.bluetooth.BluetoothManager
import android.content.Context
import android.net.wifi.WifiManager
import android.os.StatFs
import android.provider.Settings
import android.telephony.TelephonyManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of the "survival_node/device" channel (lib/core/device_info.dart).
 * Reads state only. Nothing here can (or tries to) change a radio: Android forbids that for apps.
 */
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Documents vault: hide the screen from screenshots / recents while it is unlocked.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "survival_node/secure")
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecure") {
                    val on = call.argument<Boolean>("on") ?: false
                    if (on) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                } else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "survival_node/device")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "freeBytes" -> {
                            val path = call.argument<String>("path") ?: filesDir.path
                            result.success(StatFs(path).availableBytes)
                        }
                        "totalRam" -> result.success(memInfo().totalMem)
                        "availableRam" -> result.success(memInfo().availMem)
                        "cpuCores" -> result.success(Runtime.getRuntime().availableProcessors())
                        "radioState" -> result.success(radioState())
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("device_info", e.message, null)
                }
            }
    }

    private fun memInfo(): ActivityManager.MemoryInfo {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
    }

    private fun radioState(): Map<String, Any?> {
        val airplane = Settings.Global.getInt(contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0) == 1

        // ACCESS_WIFI_STATE is a normal (install-time) permission.
        val wifiOn: Boolean? = try {
            (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager).isWifiEnabled
        } catch (e: Exception) { null }

        // isEnabled needs BLUETOOTH (legacy, API <= 30) or nothing (API 31+). Null if the OEM disagrees.
        val btOn: Boolean? = try {
            (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter?.isEnabled
        } catch (e: SecurityException) { null }

        // Without READ_PHONE_STATE we cannot read service state. A ready SIM with airplane mode off
        // means the modem is transmitting, which is what matters for the air gap.
        val cellOn: Boolean? = try {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            if (tm.phoneType == TelephonyManager.PHONE_TYPE_NONE) false
            else !airplane && tm.simState == TelephonyManager.SIM_STATE_READY
        } catch (e: Exception) { null }

        return mapOf(
            "airplaneMode" to airplane,
            "wifiRadioOn" to wifiOn,
            "bluetoothOn" to btOn,
            "cellularRadioOn" to cellOn,
        )
    }
}
