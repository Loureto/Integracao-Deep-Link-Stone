package com.example.example.pagbank

import br.com.uol.pagseguro.plugpagservice.wrapper.CustomEvent
import br.com.uol.pagseguro.plugpagservice.wrapper.DigitPasswordEvent
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPag
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagAbortResult
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagEventData
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagPaymentData
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagPrintResult
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagTransactionResult
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagVoidData
import br.com.uol.pagseguro.plugpagservice.wrapper.exception.PlugPagException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class PagBankRequestHandlerTest {

    private val terminal = FakeTerminal()
    private val operations = QueuedExecutor()
    private val aborts = QueuedExecutor()
    private val mainThread = QueuedExecutor()
    private val events = mutableListOf<Map<String, Any?>>()
    private var terminalFactory: () -> PagBankTerminal = { terminal }

    private val handler = PagBankRequestHandler(
        terminal = { terminalFactory() },
        operations = operations,
        aborts = aborts,
        mainThread = mainThread,
        onEvent = { events += it }
    )

    @Test
    fun `paga na fila de operacoes e responde na main thread`() {
        val result = RecordingResult()

        handler.handle(payment(), result)
        assertTrue(terminal.payments.isEmpty())

        operations.runAll()
        assertEquals(1, terminal.payments.size)
        assertTrue("responde só na main thread", result.replies.isEmpty())

        mainThread.runAll()
        assertEquals(listOf("success"), result.replies)
        val transaction = result.values.single() as Map<*, *>
        assertEquals(PlugPag.RET_OK, transaction["result"])
        assertEquals("TC1", transaction["transactionCode"])
        assertEquals("CREDIT", transaction["paymentType"])
        assertEquals("PAYMENT", transaction["voidType"])
    }

    @Test
    fun `repassa os eventos do terminal na main thread`() {
        terminal.eventsDuringOperation = listOf(CustomEvent("APROXIME, INSIRA OU PASSE O CARTAO"), DigitPasswordEvent())

        handler.handle(payment(), RecordingResult())
        operations.runAll()
        assertTrue(events.isEmpty())
        mainThread.runAll()

        assertEquals("APROXIME, INSIRA OU PASSE O CARTAO", events[0]["message"])
        assertEquals(PlugPagEventData.EVENT_CODE_DIGIT_PASSWORD, events[1]["code"])
    }

    @Test
    fun `responde INVALID_ARGUMENT sem chamar o terminal`() {
        listOf(
            payment("type" to "BOLETO"),
            payment("amount" to 0),
            payment("amount" to "1000"),
            payment("installmentType" to "A_VISTA", "installments" to 2),
            payment("installmentType" to "PARC_VENDEDOR", "installments" to 1),
            payment("userReference" to "VENDAÇÃO"),
            payment("userReference" to "VENDA123456"),
            payment("userReference" to 10),
            MethodCall(PagBankRequestHandler.METHOD_VOID_PAYMENT, mapOf("transactionCode" to "TC1")),
            MethodCall(PagBankRequestHandler.METHOD_PAYMENT, null)
        ).forEach { invalid ->
            val result = RecordingResult()

            handler.handle(invalid, result)

            assertEquals("${invalid.arguments<Any?>()}", listOf("error:INVALID_ARGUMENT"), result.replies)
        }
        operations.runAll()
        assertTrue(terminal.payments.isEmpty())
    }

    @Test
    fun `nao opera com o terminal desativado ou ocupado`() {
        terminal.authenticated = false
        assertEquals(listOf("error:NOT_AUTHENTICATED"), send(payment()))

        terminal.authenticated = true
        terminal.busy = true
        assertEquals(listOf("error:SERVICE_BUSY"), send(payment()))

        assertTrue(terminal.payments.isEmpty())
    }

    @Test
    fun `responde TERMINAL_UNAVAILABLE fora de um terminal PagBank`() {
        terminalFactory = {
            throw PagBankException(PagBankException.TERMINAL_UNAVAILABLE, "PlugPagService não encontrado.")
        }

        assertEquals(listOf("error:TERMINAL_UNAVAILABLE"), send(payment()))
    }

    @Test
    fun `responde com o errorCode da PlugPagException ou um codigo generico`() {
        terminal.failure = PlugPagException("Serviço ocupado.", "PP1047")
        assertEquals(listOf("error:PP1047"), send(payment()))

        terminal.failure = PlugPagException("Erro sem código.", "")
        assertEquals(listOf("error:PLUGPAG_ERROR"), send(payment()))

        terminal.failure = IllegalStateException("Falha inesperada.")
        assertEquals(listOf("error:PAGBANK_ERROR"), send(payment()))
    }

    @Test
    fun `aborta na fila propria, sem esperar o pagamento em andamento`() {
        val paymentResult = RecordingResult()
        val abortResult = RecordingResult()

        handler.handle(payment(), paymentResult)
        handler.handle(MethodCall(PagBankRequestHandler.METHOD_ABORT, null), abortResult)
        aborts.runAll()
        mainThread.runAll()

        assertEquals(1, terminal.aborts)
        assertEquals(listOf("success"), abortResult.replies)
        assertEquals(PlugPag.RET_OK, abortResult.values.single())
        assertTrue("o pagamento continua na fila", paymentResult.replies.isEmpty())
    }

    @Test
    fun `estorna com o voidType enviado`() {
        val call = MethodCall(
            PagBankRequestHandler.METHOD_VOID_PAYMENT,
            mapOf("transactionCode" to "TC1", "transactionId" to "TID1", "voidType" to "QRCODE", "printReceipt" to true)
        )

        assertEquals(listOf("success"), send(call))

        val void = terminal.voids.single()
        assertEquals("TC1", void.transactionCode)
        assertEquals("TID1", void.transactionId)
        assertEquals(PlugPag.VOID_QRCODE, void.voidType)
        assertTrue(void.printReceipt)
    }

    @Test
    fun `consulta a ultima transacao aprovada e reimprime as vias`() {
        val transaction = RecordingResult()
        val customer = RecordingResult()
        val establishment = RecordingResult()

        handler.handle(MethodCall(PagBankRequestHandler.METHOD_LAST_APPROVED_TRANSACTION, null), transaction)
        handler.handle(MethodCall(PagBankRequestHandler.METHOD_REPRINT_CUSTOMER_RECEIPT, null), customer)
        handler.handle(MethodCall(PagBankRequestHandler.METHOD_REPRINT_ESTABLISHMENT_RECEIPT, null), establishment)
        operations.runAll()
        mainThread.runAll()

        assertEquals("TC1", (transaction.values.single() as Map<*, *>)["transactionCode"])
        assertEquals(listOf("customer", "establishment"), terminal.reprints)
        assertEquals(PlugPag.RET_OK, (customer.values.single() as Map<*, *>)["result"])
        assertEquals(PlugPag.RET_OK, (establishment.values.single() as Map<*, *>)["result"])
    }

    @Test
    fun `metodo desconhecido nao e implementado`() {
        val result = RecordingResult()

        handler.handle(MethodCall("refund", null), result)

        assertEquals(listOf("notImplemented"), result.replies)
    }

    private fun send(call: MethodCall): List<String> {
        val result = RecordingResult()
        handler.handle(call, result)
        operations.runAll()
        mainThread.runAll()
        return result.replies
    }

    private fun payment(vararg overrides: Pair<String, Any?>) = MethodCall(
        PagBankRequestHandler.METHOD_PAYMENT,
        mapOf(
            "type" to "CREDIT",
            "amount" to 3000,
            "installmentType" to "PARC_VENDEDOR",
            "installments" to 3,
            "userReference" to "VENDA01",
            "printReceipt" to false
        ) + overrides
    )

    private class QueuedExecutor : Executor {
        private val tasks = ArrayDeque<Runnable>()

        override fun execute(command: Runnable) {
            tasks.addLast(command)
        }

        fun runAll() {
            while (tasks.isNotEmpty()) tasks.removeFirst().run()
        }
    }

    private class FakeTerminal : PagBankTerminal {
        var authenticated = true
        var busy = false
        var failure: RuntimeException? = null
        var eventsDuringOperation: List<PlugPagEventData> = emptyList()
        val payments = mutableListOf<PlugPagPaymentData>()
        val voids = mutableListOf<PlugPagVoidData>()
        val reprints = mutableListOf<String>()
        var aborts = 0

        private var eventListener: ((PlugPagEventData) -> Unit)? = null
        private val approved = PlugPagTransactionResult(
            result = PlugPag.RET_OK,
            errorCode = PlugPag.ERROR_CODE_OK,
            transactionCode = "TC1",
            transactionId = "TID1",
            amount = "3000",
            installments = 3,
            paymentType = PlugPag.TYPE_CREDITO
        )

        override fun isAuthenticated() = authenticated

        override fun isServiceBusy() = busy

        override fun setEventListener(listener: (PlugPagEventData) -> Unit) {
            eventListener = listener
        }

        override fun doPayment(data: PlugPagPaymentData): PlugPagTransactionResult {
            failure?.let { throw it }
            payments += data
            eventsDuringOperation.forEach { eventListener?.invoke(it) }
            return approved
        }

        override fun voidPayment(data: PlugPagVoidData): PlugPagTransactionResult {
            voids += data
            return approved
        }

        override fun abort(): PlugPagAbortResult {
            aborts++
            return PlugPagAbortResult(PlugPag.RET_OK)
        }

        override fun getLastApprovedTransaction() = approved

        override fun reprintCustomerReceipt(): PlugPagPrintResult {
            reprints += "customer"
            return PlugPagPrintResult(PlugPag.RET_OK, null, null, 1)
        }

        override fun reprintEstablishmentReceipt(): PlugPagPrintResult {
            reprints += "establishment"
            return PlugPagPrintResult(PlugPag.RET_OK, null, null, 1)
        }
    }

    private class RecordingResult : MethodChannel.Result {
        val replies = mutableListOf<String>()
        val values = mutableListOf<Any?>()

        override fun success(result: Any?) {
            replies += "success"
            values += result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            replies += "error:$errorCode"
        }

        override fun notImplemented() {
            replies += "notImplemented"
        }
    }
}
