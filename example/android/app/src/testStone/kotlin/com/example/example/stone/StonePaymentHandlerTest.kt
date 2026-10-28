package com.example.example.stone.payment

import android.app.Application
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
class StonePaymentHandlerTest {

    private val application: Application = RuntimeEnvironment.getApplication()
    private val handler = StonePaymentHandler(application, RETURN_SCHEME)

    @Test
    fun `abre o app de pagamento e responde uma unica vez`() {
        val result = RecordingResult()

        handler.sendPayment(call("amount" to 100, "transactionType" to "DEBIT"), result)

        assertEquals(listOf("success:true"), result.replies)
        assertEquals(
            "payment-app://pay?return_scheme=$RETURN_SCHEME&amount=100&transaction_type=DEBIT",
            shadowOf(application).nextStartedActivity.dataString
        )
    }

    @Test
    fun `aceita order_id maior que Int MAX_VALUE`() {
        val result = RecordingResult()

        handler.sendPayment(call("orderId" to 3_000_000_000L), result)

        assertEquals(listOf("success:true"), result.replies)
        assertEquals(
            "3000000000",
            shadowOf(application).nextStartedActivity.data?.getQueryParameter("order_id")
        )
    }

    @Test
    fun `responde PAYMENT_APP_NOT_FOUND quando o app Stone nao esta instalado`() {
        shadowOf(application).checkActivities(true)
        val result = RecordingResult()

        handler.sendPayment(call("amount" to 100), result)

        assertEquals(listOf("error:PAYMENT_APP_NOT_FOUND"), result.replies)
    }

    @Test
    fun `responde INVALID_ARGUMENT sem abrir o app de pagamento`() {
        listOf(
            call("amount" to -1),
            call("amount" to "100"),
            call("amount" to 10.5),
            call("installmentCount" to 1),
            call("editableAmount" to 1),
            call("transactionType" to "CASH"),
            call("returnScheme" to "outroapp")
        ).forEach { invalid ->
            val result = RecordingResult()

            handler.sendPayment(invalid, result)

            assertEquals(invalid.arguments.toString(), listOf("error:INVALID_ARGUMENT"), result.replies)
        }
        assertNull(shadowOf(application).nextStartedActivity)
    }

    private fun call(vararg arguments: Pair<String, Any?>) =
        MethodCall("sendStoneDeeplink", mapOf(*arguments))

    private class RecordingResult : MethodChannel.Result {
        val replies = mutableListOf<String>()

        override fun success(result: Any?) {
            replies += "success:$result"
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            replies += "error:$errorCode"
        }

        override fun notImplemented() {
            replies += "notImplemented"
        }
    }

    private companion object {
        const val RETURN_SCHEME = "paymentintegrationsstone"
    }
}
