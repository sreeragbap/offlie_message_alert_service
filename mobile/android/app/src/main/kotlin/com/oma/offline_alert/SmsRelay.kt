package com.oma.offline_alert

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import androidx.core.content.ContextCompat

/**
 * Relay mode: sends an SMS from this phone's SIM and reports what Android says happened.
 * Outcomes match the backend's relay API: SENT, RETRYABLE_FAILURE, FAILED, UNKNOWN.
 * "SENT" means the SIM sent it; it is not a delivery confirmation.
 */
object SmsRelay {
    private const val TIMEOUT_MS = 60_000L

    fun send(context: Context, to: String, text: String, reference: String, done: (String, String?) -> Unit) {
        val sms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        val parts = sms.divideMessage(text)
        val action = "${context.packageName}.SMS_SENT.$reference"
        val main = Handler(Looper.getMainLooper())
        var remaining = parts.size
        var firstError: Int? = null
        var finished = false
        lateinit var receiver: BroadcastReceiver
        lateinit var timeout: Runnable

        fun finish(outcome: String, error: String?) {
            if (finished) return
            finished = true
            main.removeCallbacks(timeout)
            runCatching { context.unregisterReceiver(receiver) }
            done(outcome, error)
        }

        receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                if (resultCode != Activity.RESULT_OK && firstError == null) firstError = resultCode
                remaining--
                if (remaining > 0) return
                val error = firstError
                if (error == null) finish("SENT", null) else finish(outcomeFor(error), errorName(error))
            }
        }
        timeout = Runnable { finish("UNKNOWN", "No result from Android within 60 s") }

        ContextCompat.registerReceiver(context, receiver, IntentFilter(action), ContextCompat.RECEIVER_NOT_EXPORTED)
        val sentIntents = ArrayList<PendingIntent>(parts.size)
        for (i in parts.indices) {
            val intent = Intent(action).setPackage(context.packageName)
            sentIntents.add(
                PendingIntent.getBroadcast(context, i, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_ONE_SHOT),
            )
        }
        main.postDelayed(timeout, TIMEOUT_MS)
        try {
            sms.sendMultipartTextMessage(to, null, parts, sentIntents, null)
        } catch (e: Exception) {
            // Thrown before anything was handed to the radio (e.g. permission missing).
            finish("FAILED", e.javaClass.simpleName)
        }
    }

    /** No signal or airplane mode: nothing was sent, trying again later can work. */
    private fun outcomeFor(code: Int) = when (code) {
        SmsManager.RESULT_ERROR_NO_SERVICE, SmsManager.RESULT_ERROR_RADIO_OFF -> "RETRYABLE_FAILURE"
        else -> "FAILED"
    }

    private fun errorName(code: Int) = when (code) {
        SmsManager.RESULT_ERROR_NO_SERVICE -> "No mobile service"
        SmsManager.RESULT_ERROR_RADIO_OFF -> "Mobile radio off (airplane mode?)"
        SmsManager.RESULT_ERROR_NULL_PDU -> "Message could not be encoded"
        SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "Generic failure (no SIM or no SMS credit?)"
        else -> "SMS error $code"
    }
}
