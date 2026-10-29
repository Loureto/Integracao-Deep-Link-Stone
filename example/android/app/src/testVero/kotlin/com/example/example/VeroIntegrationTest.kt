package com.example.example

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.ByteBuffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/** Os canais e o retorno do app da Vero, de ponta a ponta na integração. */
@RunWith(RobolectricTestRunner::class)
class VeroIntegrationTest {

    private val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    private val messenger = FakeMessenger()
    private val integration = VeroIntegration().apply { configure(activity, messenger) }

    @Test
    fun `payCredit pelo canal vero_flutter abre o app e o onActivityResult responde ao Dart`() {
        val replies = messenger.call("vero_flutter", "payCredit", mapOf("amount" to 100))

        val started = shadowOf(activity).nextStartedActivityForResult
        assertEquals("br.com.execucao.PAGAR", started.intent.action)
        assertEquals(emptyList<Any?>(), replies)

        val handled = integration.onActivityResult(
            started.requestCode,
            Activity.RESULT_OK,
            Intent().putExtra("AUTORIZACAO", "A1")
        )

        assertTrue(handled)
        assertEquals(listOf<Any?>(mapOf("AUTORIZACAO" to "A1")), replies)
    }

    @Test
    fun `extras que o codec do Flutter nao carrega chegam ao Dart como texto`() {
        val replies = messenger.call("vero_flutter", "payCredit", mapOf("amount" to 100))
        val started = shadowOf(activity).nextStartedActivityForResult

        integration.onActivityResult(
            started.requestCode,
            Activity.RESULT_OK,
            Intent().putExtra("AUTORIZACAO", "A1").putExtra("LETRA", 'c').putExtra("LISTA", arrayOf("a"))
        )

        val response = replies.single() as Map<*, *>
        assertEquals("c", response["LETRA"])
        assertTrue(response["LISTA"] is String)
    }

    @Test
    fun `o canal acquirers_sdk do driver esta registrado`() {
        assertEquals(listOf<Any?>("notImplemented"), messenger.call("acquirers_sdk", "metodoInexistente", null))
    }

    /** Guarda os handlers que a integração registra, um por canal. */
    private class FakeMessenger : BinaryMessenger {
        private val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler?>()

        fun call(channel: String, method: String, arguments: Any?): MutableList<Any?> {
            val replies = mutableListOf<Any?>()
            val message = codec.encodeMethodCall(MethodCall(method, arguments)).apply { rewind() }

            handlers.getValue(channel)!!.onMessage(message) { reply ->
                replies += when (reply) {
                    null -> "notImplemented"
                    else -> try {
                        codec.decodeEnvelope(reply.apply { rewind() })
                    } catch (exception: FlutterException) {
                        "error:${exception.code}"
                    }
                }
            }
            return replies
        }

        override fun send(channel: String, message: ByteBuffer?) = Unit

        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) = Unit

        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
            handlers[channel] = handler
        }

        private companion object {
            val codec: StandardMethodCodec = StandardMethodCodec.INSTANCE
        }
    }
}
