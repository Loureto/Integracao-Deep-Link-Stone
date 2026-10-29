
package com.example.example

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import com.example.example.stone.payment.StonePaymentHandler
import com.example.example.stone.payment.StonePaymentResponseHandler
import com.example.example.stone.print.StonePrintHandler

internal fun createAcquirerIntegration(): AcquirerIntegration = StoneIntegration()

/** Pagamento e impressão pelos deep links da Stone: cada retorno volta como URI, em [onNewIntent], no seu host. */
internal class StoneIntegration : AcquirerIntegration {

    private lateinit var responseHandler: StonePaymentResponseHandler
    private lateinit var printHandler: StonePrintHandler

    override fun configure(activity: Activity, messenger: BinaryMessenger) {
        val scheme = activity.getString(R.string.scheme_return)
        val channel = MethodChannel(messenger, CHANNEL)
        val paymentHandler = StonePaymentHandler(activity, scheme)
        printHandler = StonePrintHandler(activity, scheme)

        responseHandler = StonePaymentResponseHandler(scheme) { response ->
            channel.invokeMethod(METHOD_ON_PAYMENT_RESPONSE, response)
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_SEND_DEEP_LINK -> paymentHandler.sendPayment(call, result)
                METHOD_PRINT_RECEIPT -> printHandler.printReceipt(call, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        if (intent.action != Intent.ACTION_VIEW) return

        if (intent.data?.host == StonePrintHandler.PRINT_HOST) {
            printHandler.handle(intent)
        } else {
            responseHandler.handle(intent)
        }
    }

    companion object {
        private const val CHANNEL = "stoneDeeplinkChannel"
        private const val METHOD_SEND_DEEP_LINK = "sendStoneDeeplink"
        private const val METHOD_ON_PAYMENT_RESPONSE = "onStonePaymentResponse"

        /** Mesmo nome do stone_sdk, usado hoje pelo flutter_acquirers_sdk. */
        private const val METHOD_PRINT_RECEIPT = "print_receipt"
    }
}
