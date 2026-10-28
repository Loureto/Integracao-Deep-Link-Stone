
package com.example.example

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import com.example.example.stone.payment.StonePaymentHandler
import com.example.example.stone.payment.StonePaymentResponseHandler

internal fun createAcquirerIntegration(): AcquirerIntegration = StoneIntegration()

/** Pagamento pelo deep link da Stone: o retorno volta como URI, em [onNewIntent]. */
internal class StoneIntegration : AcquirerIntegration {

    private lateinit var responseHandler: StonePaymentResponseHandler

    override fun configure(activity: Activity, messenger: BinaryMessenger) {
        val scheme = activity.getString(R.string.scheme_return)
        val channel = MethodChannel(messenger, CHANNEL)
        val paymentHandler = StonePaymentHandler(activity, scheme)

        responseHandler = StonePaymentResponseHandler(scheme) { response ->
            channel.invokeMethod(METHOD_ON_PAYMENT_RESPONSE, response)
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_SEND_DEEP_LINK -> paymentHandler.sendPayment(call, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        if (intent.action == Intent.ACTION_VIEW) responseHandler.handle(intent)
    }

    companion object {
        private const val CHANNEL = "stoneDeeplinkChannel"
        private const val METHOD_SEND_DEEP_LINK = "sendStoneDeeplink"
        private const val METHOD_ON_PAYMENT_RESPONSE = "onStonePaymentResponse"
    }
}
