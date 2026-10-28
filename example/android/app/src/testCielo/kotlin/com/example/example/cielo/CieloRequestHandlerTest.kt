package com.example.example.cielo

import android.app.Activity
import android.app.Application
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
class CieloRequestHandlerTest {

    private val application: Application = RuntimeEnvironment.getApplication()
    private val activity: Activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    private val handler = CieloRequestHandler(activity, RETURN_SCHEME)

    @Test
    fun `abre o app da Cielo e responde uma unica vez`() {
        val result = RecordingResult()

        handler.send(call("action" to "payment-reversal", "request" to """{"id":"pedido"}"""), result)

        assertEquals(listOf("success:true"), result.replies)
        val uri = shadowOf(application).nextStartedActivity.data!!
        assertEquals("payment-reversal", uri.authority)
        assertEquals("$RETURN_SCHEME://payment-reversal", uri.getQueryParameter("urlCallback"))
    }

    @Test
    fun `responde PAYMENT_APP_NOT_FOUND quando o app da Cielo nao esta instalado`() {
        shadowOf(application).checkActivities(true)
        val result = RecordingResult()

        handler.send(call("action" to "terminalinfo"), result)

        assertEquals(listOf("error:PAYMENT_APP_NOT_FOUND"), result.replies)
    }

    @Test
    fun `responde INVALID_ARGUMENT sem abrir o app da Cielo`() {
        listOf(
            call("request" to "{}"),
            call("action" to "refund", "request" to "{}"),
            call("action" to 1, "request" to "{}"),
            call("action" to "payment"),
            call("action" to "payment", "request" to 10)
        ).forEach { invalid ->
            val result = RecordingResult()

            handler.send(invalid, result)

            assertEquals(invalid.arguments.toString(), listOf("error:INVALID_ARGUMENT"), result.replies)
        }
        assertNull(shadowOf(application).nextStartedActivity)
    }

    private fun call(vararg arguments: Pair<String, Any?>) =
        MethodCall("sendCieloDeeplink", mapOf(*arguments))

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
        const val RETURN_SCHEME = "paymentintegrationscielo"
    }
}
