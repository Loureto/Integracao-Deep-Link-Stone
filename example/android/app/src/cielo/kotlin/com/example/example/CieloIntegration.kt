
package com.example.example

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import com.example.example.cielo.CieloRequestHandler
import com.example.example.cielo.CieloResponseHandler

internal fun createAcquirerIntegration(): AcquirerIntegration = CieloIntegration()

/** Operações pelo deep link `lio://` da Cielo Smart: os retornos voltam como URI, em [onNewIntent]. */
internal class CieloIntegration : AcquirerIntegration {

    private lateinit var responseHandler: CieloResponseHandler

    override fun configure(activity: Activity, messenger: BinaryMessenger) {
        val scheme = activity.getString(R.string.cielo_scheme_return)
        val channel = MethodChannel(messenger, CHANNEL)
        val requestHandler = CieloRequestHandler(activity, scheme)

        responseHandler = CieloResponseHandler(scheme) { response ->
            channel.invokeMethod(METHOD_ON_RESPONSE, response)
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_SEND_DEEP_LINK -> requestHandler.send(call, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        if (intent.action == Intent.ACTION_VIEW) responseHandler.handle(intent)
    }

    companion object {
        private const val CHANNEL = "cieloDeeplinkChannel"
        private const val METHOD_SEND_DEEP_LINK = "sendCieloDeeplink"
        private const val METHOD_ON_RESPONSE = "onCieloResponse"
    }
}
