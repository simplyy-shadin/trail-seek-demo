package com.trailseek.trailseek

import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // The Digital Rope heartbeat is advertised as the adapter name (that is how
    // the BLE plugin sets a local name on Android), which would leave the phone
    // showing up as "TS…" to cars and headsets. Remember the real name before
    // the rope starts and put it back when it stops, even after a crash.
    @SuppressLint("MissingPermission")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "trailseek/bt_name").setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("bt_name", Context.MODE_PRIVATE)
            val adapter = (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
            try {
                when (call.method) {
                    "remember" -> {
                        // Keep the first saved name: after a crash the adapter
                        // may still carry a heartbeat, which must not be saved.
                        if (!prefs.contains("name")) {
                            val name = adapter?.name
                            if (name != null) prefs.edit().putString("name", name).apply()
                        }
                        result.success(null)
                    }
                    "restore" -> {
                        val name = prefs.getString("name", null)
                        if (name != null && adapter != null) adapter.setName(name)
                        prefs.edit().remove("name").apply()
                        result.success(name)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: SecurityException) {
                result.success(null) // no BLUETOOTH_CONNECT yet: nothing to save or restore
            }
        }
    }
}
