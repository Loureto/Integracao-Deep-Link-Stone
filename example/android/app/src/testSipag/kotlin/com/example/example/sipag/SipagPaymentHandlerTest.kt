package com.example.example.sipag

import android.app.Application
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf

/** O canal `sipag_sdk`: argumentos, resposta única na main thread, operação substituída e última operação. */
@RunWith(RobolectricTestRunner::class)
class SipagPaymentHandlerTest {

    private val context: Application = RuntimeEnvironment.getApplication()
    private val terminal = FakeSipagTerminal()
    private val store = PendingOperationStore(context)
    private val lastOperation = File(context.cacheDir, "operation_result.json")
    private val handler = SipagPaymentHandler(terminal, store) { lastOperation }

    private val approved = SipagOutcome.Approved(mapOf("NSU_SITEF" to "T1"))

    private fun call(method: String, arguments: Map<String, Any?>? = null) =
        RecordingResult().also { handler.handle(MethodCall(method, arguments), it) }

    @Test
    fun `cada metodo chega ao terminal com o argumento`() {
        call("pay_credit", mapOf("amount" to "1,00"))
        call("pay_debit", mapOf("amount" to "2,00"))
        call("pay_pix", mapOf("amount" to "3,00"))
        call("refund", mapOf("nsu" to "N1"))
        call("refund_pix", mapOf("nsu" to "P1"))

        assertEquals(
            listOf(
                "credit" to "1,00",
                "debit" to "2,00",
                "pix" to "3,00",
                "refund" to "N1",
                "pixRefund" to "P1"
            ),
            terminal.requests
        )
    }

    @Test
    fun `argumento ausente responde e nao chama o terminal`() {
        assertEquals(listOf<Any?>("error:amount:amount is null"), call("pay_credit").replies)
        assertEquals(listOf<Any?>("error:nsu:nsu is null"), call("refund_pix", mapOf("nsu" to null)).replies)
        assertTrue(terminal.requests.isEmpty())
    }

    @Test
    fun `metodo desconhecido responde notImplemented`() {
        assertEquals(listOf<Any?>("notImplemented"), call("wallet").replies)
    }

    @Test
    fun `aprovado responde o mapa e falha responde o erro com os detalhes`() {
        val payment = call("pay_credit", mapOf("amount" to "1,00"))
        terminal.replies.last()(approved)

        val refused = call("pay_debit", mapOf("amount" to "1,00"))
        val details = mapOf("MESSAGE" to "NEGADA")
        terminal.replies.last()(SipagOutcome.Failed("ERRO_NA_OPERACAO", "NEGADA", details))

        assertEquals(listOf<Any?>(approved.response), payment.replies)
        assertEquals(listOf<Any?>("error:ERRO_NA_OPERACAO:NEGADA"), refused.replies)
        assertEquals(listOf<Any?>(mapOf("MESSAGE" to "NEGADA")), refused.details)
    }

    @Test
    fun `o mesmo reply chamado duas vezes responde uma vez so`() {
        val result = call("pay_pix", mapOf("amount" to "1,00"))

        terminal.replies.single()(approved)
        terminal.replies.single()(approved)

        assertEquals(1, result.replies.size)
    }

    @Test
    fun `reply de outra thread responde na main thread`() {
        val result = call("pay_credit", mapOf("amount" to "1,00"))

        Thread { terminal.replies.single()(approved) }.apply { start() }.join()
        assertTrue(result.replies.isEmpty())
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(listOf(Looper.getMainLooper().thread), result.threads)
    }

    @Test
    fun `operacao nova responde a anterior e ignora o reply atrasado dela`() {
        val credit = call("pay_credit", mapOf("amount" to "1,00"))
        val debit = call("pay_debit", mapOf("amount" to "2,00"))

        terminal.replies[0](approved)
        terminal.replies[1](SipagOutcome.Approved(mapOf("NSU_SITEF" to "D1")))

        val replaced = "error:ERRO_NA_OPERACAO:Operação substituída por uma nova."
        assertEquals(listOf<Any?>(replaced), credit.replies)
        assertEquals(listOf<Any?>(mapOf("NSU_SITEF" to "D1")), debit.replies)
    }

    @Test
    fun `a marca fica ligada durante a operacao e desliga na resposta`() {
        call("pay_credit", mapOf("amount" to "1,00"))
        assertTrue(store.isPending)

        terminal.replies.single()(approved)
        assertFalse(store.isPending)

        terminal.immediate = SipagOutcome.Failed("ERRO_NA_OPERACAO", "sem app")
        call("pay_debit", mapOf("amount" to "1,00"))
        assertFalse(store.isPending)
    }

    @Test
    fun `falha que pede a marca ligada responde o erro e nao desliga a marca`() {
        val result = call("pay_credit", mapOf("amount" to "1,00"))

        terminal.replies.single()(SipagOutcome.Failed("ERRO_NA_OPERACAO", "Falha", keepPending = true))

        assertEquals(listOf<Any?>("error:ERRO_NA_OPERACAO:Falha"), result.replies)
        assertTrue(store.isPending)
    }

    @Test
    fun `handler de uma activity recriada nao desliga a marca nem responde, e o novo recupera a venda`() {
        // A activity morreu com o pagamento na frente; o processo e o poller do AAR continuam vivos.
        val old = call("pay_credit", mapOf("amount" to "1,00"))
        val recreated = SipagPaymentHandler(FakeSipagTerminal(), store) { lastOperation }

        terminal.replies.single()(approved)
        lastOperation.writeText(approvedDxJson())
        val recovered = RecordingResult()
        recreated.handle(MethodCall("get_last_operation", null), recovered)

        assertTrue(old.replies.isEmpty())
        assertEquals("T1", (recovered.replies.single() as Map<*, *>)["NSU_SITEF"])
    }

    @Test
    fun `ultima operacao sem a marca responde LAST_OPERATION_NOT_FOUND`() {
        lastOperation.writeText(approvedDxJson())

        assertEquals(
            listOf<Any?>("error:LAST_OPERATION_NOT_FOUND:Não foi encontrado nenhuma operação no histórico!"),
            call("get_last_operation").replies
        )
    }

    @Test
    fun `ultima operacao com a marca e sem arquivo responde FILE_DOES_NOT_EXIST e desliga a marca`() {
        store.markPending()

        assertEquals(
            listOf<Any?>("error:FILE_DOES_NOT_EXIST:Não foi possível recuperar a última operação!"),
            call("get_last_operation").replies
        )
        assertFalse(store.isPending)
    }

    @Test
    fun `ultima operacao com arquivo ilegivel responde READ_OPERATION_FILE_FAILED`() {
        store.markPending()
        lastOperation.writeText("{")

        assertEquals(
            listOf<Any?>("error:READ_OPERATION_FILE_FAILED:Não foi possível recuperar a última operação!"),
            call("get_last_operation").replies
        )
    }

    @Test
    fun `ultima operacao com a marca le o arquivo do DX`() {
        store.markPending()
        lastOperation.writeText(approvedDxJson())

        val response = call("get_last_operation").replies.single() as Map<*, *>

        assertEquals("T1", response["NSU_SITEF"])
        assertFalse(store.isPending)
    }

    @Test
    fun `ultima operacao com uma operacao em andamento nao mexe na marca dela`() {
        lastOperation.writeText(approvedDxJson())
        call("pay_credit", mapOf("amount" to "1,00"))

        val result = call("get_last_operation")

        val code = (result.replies.single() as String).substringBeforeLast(":")
        assertEquals("error:LAST_OPERATION_NOT_FOUND", code)
        assertTrue(store.isPending)
    }

    @Test
    fun `o P2 e escolhido pelo modelo, como no plugin`() {
        assertEquals(listOf(true, true, false, false), listOf("P2-B", "P2-A11", "DX8000", "X990").map(::isP2))
    }
}
