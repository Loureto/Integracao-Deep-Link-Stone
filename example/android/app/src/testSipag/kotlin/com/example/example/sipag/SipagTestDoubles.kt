package com.example.example.sipag

import android.app.Activity
import android.content.Context
import ger7.com.br.pos7api.ParamIn
import ger7.com.br.pos7api.ParamOut
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import printx990.br.apix990.internal.domain.dto.TransactionData

/** [DxSdk] sem o app Sicoob: guarda os pedidos e o callback, que o teste chama com o JSON que quiser. */
internal class FakeDxSdk(var installed: Boolean = true) : DxSdk {
    val started = mutableListOf<TransactionData>()
    var onResult: ((String) -> Unit)? = null

    /** Quando definida, o [start] lança esta exceção, como o SDK que não consegue abrir o app. */
    var failure: Exception? = null

    override fun isSicoobInstalled(context: Context) = installed

    override fun start(activity: Activity, data: TransactionData, onResult: (String) -> Unit) {
        failure?.let { throw it }
        started += data
        this.onResult = onResult
    }
}

/** [P2Sdk] sem o app da Ger7: guarda os pedidos e o callback. */
internal class FakeP2Sdk : P2Sdk {
    val processed = mutableListOf<ParamIn>()
    var onResult: ((ParamOut) -> Unit)? = null
    var failure: Exception? = null

    override fun process(context: Context, params: ParamIn, onResult: (ParamOut) -> Unit) {
        failure?.let { throw it }
        processed += params
        this.onResult = onResult
    }
}

/** JSON do app Sicoob para um crédito aprovado de R$ 1,00, NSU "T1". */
internal fun approvedDxJson(): String = JSONObject()
    .put("label", "VISA")
    .put("authorizationCode", "A1")
    .put("installments", 1)
    .put("product", "CREDITO")
    .put("maskedPan", "****1234")
    .put("transactionID", "T1")
    .put("amount", "100")
    .put("mError", JSONArray())
    .put("receiptList", JSONArray().put(JSONObject().put("lines", JSONArray().put("LOJA"))))
    .toString()

/** `ParamOut` do app da Ger7 para um crédito aprovado de R$ 1,00, NSU "R1". */
internal fun approvedParamOut() = ParamOut().apply {
    setStatus(0)
    setConfig(2)
    setLicense(1)
    setResponse(0)
    setResProduct(1)
    setResLabel("MASTER")
    setResRrn("R1")
    setResAuthorization("A1")
    setPan("5555****")
    setResInstallments(1)
    setResAmount("100")
}

/** [SipagTerminal] que guarda cada pedido e o [SipagReply] dele; o teste responde quando quiser. */
internal class FakeSipagTerminal : SipagTerminal {
    val requests = mutableListOf<Pair<String, String>>()
    val replies = mutableListOf<SipagReply>()

    /** Quando definido, o terminal responde na hora, como o DX sem permissão ou sem o app Sicoob. */
    var immediate: SipagOutcome? = null

    private fun record(operation: String, argument: String, reply: SipagReply) {
        requests += operation to argument
        replies += reply
        immediate?.let(reply)
    }

    override fun creditPayment(amount: String, reply: SipagReply) = record("credit", amount, reply)
    override fun debitPayment(amount: String, reply: SipagReply) = record("debit", amount, reply)
    override fun pixPayment(amount: String, reply: SipagReply) = record("pix", amount, reply)
    override fun refund(nsu: String, reply: SipagReply) = record("refund", nsu, reply)
    override fun pixRefund(nsu: String, reply: SipagReply) = record("pixRefund", nsu, reply)
}

/** `MethodChannel.Result` que guarda as respostas, os detalhes dos erros e a thread de cada resposta. */
internal class RecordingResult : MethodChannel.Result {
    val replies = mutableListOf<Any?>()
    val details = mutableListOf<Any?>()
    val threads = mutableListOf<Thread>()

    override fun success(result: Any?) {
        threads += Thread.currentThread()
        replies += result
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        threads += Thread.currentThread()
        replies += "error:$errorCode:$errorMessage"
        details += errorDetails
    }

    override fun notImplemented() {
        threads += Thread.currentThread()
        replies += "notImplemented"
    }
}
