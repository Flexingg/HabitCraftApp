package com.habitcraft.habitcraft_app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "habitcraft/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openHealthConnectPermissions" -> result.success(openHealthConnectPermissions())
                    "openHealthConnectSettings" -> result.success(openHealthConnectSettings())
                    else -> result.notImplemented()
                }
            }
    }

    /** Deep-link straight into HabitCraft's data-access screen inside the Health Connect app. */
    private fun openHealthConnectPermissions(): Boolean {
        val hc = "com.google.android.apps.healthdata"
        for (action in listOf(
            "android.health.connect.action.MANAGE_HEALTH_DATA",
            "androidx.health.ACTION_MANAGE_HEALTH_DATA"
        )) {
            try {
                startActivity(Intent(action).setPackage(hc))
                return true
            } catch (_: Exception) { /* try next */ }
        }
        return openHealthConnectSettings()
    }

    private fun openHealthConnectSettings(): Boolean {
        val hc = "com.google.android.apps.healthdata"
        try {
            startActivity(Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS").setPackage(hc))
            return true
        } catch (_: Exception) {
            return try {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$hc")))
                true
            } catch (_: Exception) {
                try {
                    startActivity(Intent(Intent.ACTION_VIEW,
                        Uri.parse("https://play.google.com/store/apps/details?id=$hc")))
                    true
                } catch (_: Exception) { false }
            }
        }
    }
}
