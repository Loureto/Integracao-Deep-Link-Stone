package com.example.example

import android.Manifest
import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import com.example.example.printer.PosPrinter
import com.example.example.printer.PosPrinterListener
import com.example.example.sipag.FakeDxSdk
import com.example.example.sipag.FakeP2Sdk
import com.example.example.sipag.approvedDxJson
import com.example.example.sipag.approvedParamOut
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.nio.ByteBuffer
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/** O canal `sipag_sdk` de ponta a ponta na integração, com o terminal escolhido pelo modelo. */
@RunWith(RobolectricTestRunner::class)
class SipagIntegrationTest {

    private val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    private val messenger = FakeMessenger()
    private val dx = FakeDxSdk()
    private val p2 = FakeP2Sdk()
    private val printer = FakePosPrinter()
    private var openedPrinters = 0
    private var openPrinter: (Context) -> PosPrinter = {
        openedPrinters++
        printer
    }

    private fun configure(model: String) = SipagIntegration(
        model = model,
        dxSdk = dx,
        p2Sdk = p2,
        lastOperationFile = { File(activity.cacheDir, "operation_result.json") },
        openPrinter = { openPrinter(it) }
    ).configure(activity, messenger)

    @Test
    fun `na X990, pay_credit abre o app Sicoob e o resultado responde ao Dart`() {
        shadowOf(activity.application).grantPermissions(
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        )
        configure("X990")

        val replies = messenger.call("sipag_sdk", "pay_credit", mapOf("amount" to "1,00"))
        assertEquals(emptyList<Any?>(), replies)
        assertEquals("1,00", dx.started.single().amount)

        dx.onResult!!.invoke(approvedDxJson())

        val response = replies.single() as Map<*, *>
        assertEquals(1.0, response["AMOUNT"])
        assertEquals("T1", response["NSU_SITEF"])
    }

    @Test
    fun `no P2-B, o resultado do app da Ger7 responde ao Dart`() {
        configure("P2-B")

        val replies = messenger.call("sipag_sdk", "pay_debit", mapOf("amount" to "1,00"))
        p2.onResult!!.invoke(approvedParamOut())

        assertEquals("R1", (replies.single() as Map<*, *>)["NSU_SITEF"])
        assertEquals("100", p2.processed.single().trsAmount)
    }

    @Test
    fun `a impressora do driver abre uma vez, ao configurar, e serve as impressoes seguintes`() {
        // Na X990, o posmpapi cria uma impressora nova a cada Printer.getInstance, e ela só liga ao serviço
        // da Verifone depois; criada na hora da impressão, imprimia desligada e lançava NullPointerException.
        configure("X990")
        assertEquals(1, openedPrinters)

        val first = messenger.call("acquirers_sdk", "testPrint", null)
        val second = messenger.call("acquirers_sdk", "printTxt", mapOf("text" to "LINHA"))

        assertEquals(1, openedPrinters)
        assertEquals(2, printer.printed)
        assertEquals(listOf<Any?>("Sucesso ao efetuar a impressão"), first)
        assertEquals(listOf<Any?>("Sucesso ao efetuar a impressão"), second)
    }

    @Test
    fun `impressora que nao abre ao configurar nao derruba o app e a impressao responde o erro`() {
        openPrinter = { throw IllegalStateException("modelo desconhecido") }

        configure("X990")

        val replies = messenger.call("acquirers_sdk", "testPrint", null)

        assertEquals(listOf<Any?>("error:ERRO_DESCONHECIDO"), replies)
    }

    @Test
    fun `o canal acquirers_sdk do driver generico fica registrado`() {
        configure("X990")

        assertEquals(listOf<Any?>("notImplemented"), messenger.call("acquirers_sdk", "desconhecido", null))
    }

    /** Impressora do driver que conclui na hora cada impressão. */
    private class FakePosPrinter : PosPrinter {
        var printed = 0

        override fun open() = Unit

        override fun print(bitmap: Bitmap, listener: PosPrinterListener) {
            printed++
            listener.onFinish()
        }

        override fun close() = Unit
    }

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
