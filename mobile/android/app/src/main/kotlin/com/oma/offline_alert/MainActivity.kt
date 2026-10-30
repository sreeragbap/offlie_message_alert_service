package com.oma.offline_alert

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "oma/sms_relay").setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> requestSmsPermission(result)
                "send" -> SmsRelay.send(
                    applicationContext,
                    to = call.argument<String>("to")!!,
                    text = call.argument<String>("text")!!,
                    reference = call.argument<String>("reference")!!,
                ) { outcome, error -> result.success(mapOf("outcome" to outcome, "error" to error)) }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), SMS_PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != SMS_PERMISSION_REQUEST) return
        pendingPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
    }

    private companion object {
        const val SMS_PERMISSION_REQUEST = 4021
    }
}
