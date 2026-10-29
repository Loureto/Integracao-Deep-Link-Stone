package com.example.example

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.ByteBuffer
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/** O canal e os retornos do deep link, de ponta a ponta na integração. */
@RunWith(RobolectricTestRunner::class)
class StoneIntegrationTest {

    private val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    private val messenger = FakeMessenger()
    private val integration = StoneIntegration().apply { configure(activity, messenger) }
    private val scheme = activity.getString(R.string.scheme_return)

    @Test
    fun `print_receipt, o nome do stone_sdk, imprime e responde com o retorno do host print`() {
        val replies = messenger.call("print_receipt", mapOf("image_base64" to "iVBORw0KGgo="))

        assertEquals("printer-app://print", shadowOf(activity).nextStartedActivity.data?.run { "$scheme://$host" })
        assertEquals(emptyList<Any?>(), replies)

        integration.onNewIntent(Intent(Intent.ACTION_VIEW, Uri.parse("$scheme://print?DEEPLINK_RETURN=SUCCESS")))

        assertEquals(listOf<Any?>("SUCCESS"), replies)
    }

    @Test
    fun `o retorno do pagamento continua indo para onStonePaymentResponse`() {
        integration.onNewIntent(Intent(Intent.ACTION_VIEW, Uri.parse("$scheme://pay-response?code=0")))

        val sent = messenger.sent.single()
        assertEquals("onStonePaymentResponse", sent.method)
        assertEquals(mapOf("code" to "0"), sent.arguments)
    }

    /** Guarda o handler que a integração registra e as chamadas que ela envia ao Dart. */
    private class FakeMessenger : BinaryMessenger {
        private var handler: BinaryMessenger.BinaryMessageHandler? = null
        val sent = mutableListOf<MethodCall>()

        fun call(method: String, arguments: Any?): MutableList<Any?> {
            val replies = mutableListOf<Any?>()
            val message = codec.encodeMethodCall(MethodCall(method, arguments)).apply { rewind() }

            handler!!.onMessage(message) { reply ->
                replies += try {
                    codec.decodeEnvelope(reply!!.apply { rewind() })
                } catch (exception: FlutterException) {
                    "error:${exception.code}"
                }
            }
            return replies
        }

        override fun send(channel: String, message: ByteBuffer?) {
            send(channel, message, null)
        }

        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
            sent += codec.decodeMethodCall(message!!.apply { rewind() })
        }

        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
            this.handler = handler
        }

        private companion object {
            val codec: StandardMethodCodec = StandardMethodCodec.INSTANCE
        }
    }
}
