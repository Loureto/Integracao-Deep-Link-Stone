package com.example.example

import android.app.Activity
import com.example.example.rede.FakeConnectorPrinter
import com.example.example.rede.FakeRedePaymentApp
import com.example.example.rede.ProcessPrinter
import com.example.example.rede.paymentResult
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
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import rede.smartrede.sdk.PaymentStatus

/** O canal `rede_sdk` e o retorno do app da Rede, de ponta a ponta na integração. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [30])
class RedeIntegrationTest {

    private val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    private val messenger = FakeMessenger()
    private val integration = RedeIntegration(
        paymentApp = { FakeRedePaymentApp() },
        openPrinter = { FakeConnectorPrinter() }
    ).apply { configure(activity, messenger) }

    @Test
    fun `credit_payment pelo canal rede_sdk abre o app e o onActivityResult responde ao Dart`() {
        val replies = messenger.call("rede_sdk", "credit_payment", mapOf("amount" to 100))

        val started = shadowOf(activity).nextStartedActivityForResult
        assertEquals(4, started.requestCode)
        assertEquals(emptyList<Any?>(), replies)

        val handled = integration.onActivityResult(
            started.requestCode,
            Activity.RESULT_OK,
            paymentResult(PaymentStatus.AUTHORIZED)
        )

        assertTrue(handled)
        val response = replies.single() as Map<*, *>
        assertEquals(1.0, response["AMOUNT"])
        assertEquals(1, response["INSTALLMENTS"])
        assertEquals("123", response["NSU_SITEF"])
    }

    @Test
    fun `impressao durante um pagamento nao responde por ele`() {
        val payment = messenger.call("rede_sdk", "credit_payment", mapOf("amount" to 100))

        val print = messenger.call("rede_sdk", "print_txt", mapOf("text" to "LINHA"))
        integration.onActivityResult(4, Activity.RESULT_OK, paymentResult(PaymentStatus.AUTHORIZED))

        assertEquals(listOf<Any?>("Sucesso ao efetuar a impressão"), print)
        assertEquals("123", (payment.single() as Map<*, *>)["NSU_SITEF"])
    }

    @Test
    fun `pagamento funciona num aparelho sem o SDK da impressora`() {
        val messenger = FakeMessenger()
        RedeIntegration(
            paymentApp = { FakeRedePaymentApp() },
            openPrinter = { throw IllegalStateException("SDK da Rede indisponível neste aparelho") }
        ).configure(activity, messenger)

        val payment = messenger.call("rede_sdk", "credit_payment", mapOf("amount" to 100))

        assertEquals(4, shadowOf(activity).nextStartedActivityForResult.requestCode)
        assertEquals(emptyList<Any?>(), payment)
        val print = messenger.call("rede_sdk", "test_print", null)
        assertEquals(listOf<Any?>("error:IMPRESSORA_INDISPONIVEL"), print)
    }

    @Test
    fun `configure abre a impressora antes da primeira impressao`() {
        // O SDK liga o serviço de impressão de forma assíncrona: aberto só na hora, a primeira impressão caía
        // sempre em "Init failed".
        var opened = 0
        val printer = FakeConnectorPrinter()

        RedeIntegration(
            paymentApp = { FakeRedePaymentApp() },
            openPrinter = {
                opened++
                printer
            }
        ).configure(activity, FakeMessenger())

        assertEquals(1, opened)
        assertEquals(1, printer.callbackRegistrations)
        assertTrue(printer.printed.isEmpty())
    }

    @Test
    fun `Activity recriada com o processo vivo continua imprimindo sem abrir o SDK de novo`() {
        // O IRedeSdk.newInstance lança "Already initialized!" na segunda vez no mesmo processo.
        var opened = 0
        val printer = FakeConnectorPrinter()
        val sdk = ProcessPrinter {
            if (opened++ > 0) throw IllegalStateException("Already initialized!")
            printer
        }
        val recreated = FakeMessenger()

        RedeIntegration(paymentApp = { FakeRedePaymentApp() }, openPrinter = sdk::get)
            .configure(activity, FakeMessenger())
        RedeIntegration(paymentApp = { FakeRedePaymentApp() }, openPrinter = sdk::get)
            .configure(activity, recreated)

        val print = recreated.call("rede_sdk", "test_print", null)
        assertEquals(listOf<Any?>("Sucesso ao efetuar a impressão"), print)
        assertEquals(1, opened)
        // Cada integração registra o próprio callback, e o da Activity nova é o que recebe os erros.
        assertEquals(2, printer.callbackRegistrations)
    }

    @Test
    fun `metodo desconhecido responde notImplemented`() {
        assertEquals(listOf<Any?>("notImplemented"), messenger.call("rede_sdk", "metodoInexistente", null))
    }

    /** Guarda os handlers que a integração registra, um por canal, e responde pelo codec real. */
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

        override fun send(
            channel: String,
            message: ByteBuffer?,
            callback: BinaryMessenger.BinaryReply?
        ) = Unit

        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
            handlers[channel] = handler
        }

        private companion object {
            val codec: StandardMethodCodec = StandardMethodCodec.INSTANCE
        }
    }
}
