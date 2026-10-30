package com.example.example.sipag

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Canal `sipag_sdk`, com os métodos, argumentos e respostas do `FlutterSipagSdkPlugin` do plugin
 * `flutter_sipag_sdk`. As operações vão ao [terminal] do modelo, e a última operação lê o arquivo do DX.
 *
 * A resposta pendente leva um id. Só o reply desse id responde, uma vez só e na main thread: o apix990 chama
 * o callback de uma thread de IO, e o poller dele, como o `AsyncTask` do pos7api, não para com uma operação
 * nova. Uma operação nova responde a anterior com erro, porque os dois pollers leriam o mesmo arquivo e
 * entregariam o mesmo resultado às duas chamadas: o PDV registraria a venda em dobro.
 *
 * A marca de operação pendente, que no plugin ficava no Dart, fica no [store]. Só o handler da activity
 * atual mexe nela: se a activity for recriada com o pagamento na frente, o poller ainda entrega o resultado
 * ao handler antigo, cujo Dart morreu; ele não responde nem desliga a marca, e o Dart novo recupera a venda
 * pela última operação, como no plugin.
 */
internal class SipagPaymentHandler(
    private val terminal: SipagTerminal,
    private val store: PendingOperationStore,
    private val lastOperationFile: () -> File
) {

    private class Pending(val id: Long, val result: MethodChannel.Result)

    private val mainThread = Handler(Looper.getMainLooper())
    private var pending: Pending? = null
    private var lastId = 0L

    init {
        active = this
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            GET_LAST_OPERATION -> lastOperation(result)
            PAY_CREDIT -> operation(call, AMOUNT, result, terminal::creditPayment)
            PAY_DEBIT -> operation(call, AMOUNT, result, terminal::debitPayment)
            PAY_PIX -> operation(call, AMOUNT, result, terminal::pixPayment)
            REFUND -> operation(call, NSU, result, terminal::refund)
            REFUND_PIX -> operation(call, NSU, result, terminal::pixRefund)
            else -> result.notImplemented()
        }
    }

    /** No plugin, um argumento ausente não respondia (`amount`) ou ia vazio ao SDK (`nsu`). */
    private fun operation(
        call: MethodCall,
        key: String,
        result: MethodChannel.Result,
        run: (String, SipagReply) -> Unit
    ) {
        val argument = call.argument<String>(key) ?: return result.error(key, "$key is null", null)

        pending?.result?.error(ERRO_NA_OPERACAO, REPLACED_OPERATION_MESSAGE, null)
        val id = ++lastId
        pending = Pending(id, result)
        store.markPending()

        run(argument) { outcome -> onMainThread { deliver(id, outcome) } }
    }

    private fun deliver(id: Long, outcome: SipagOutcome) {
        if (active !== this) {
            Log.w(TAG, "Resposta para a activity anterior ignorada; a marca fica para a última operação.")
            return
        }
        val current = pending
        if (current?.id != id) {
            Log.w(TAG, "Resposta de uma operação já respondida ignorada.")
            return
        }
        pending = null
        if (outcome !is SipagOutcome.Failed || !outcome.keepPending) store.clear()
        reply(current.result, outcome)
    }

    /**
     * Uma operação em andamento neste processo é dona da marca: a resposta é `LAST_OPERATION_NOT_FOUND`, e a
     * marca continua ligada para ela.
     */
    private fun lastOperation(result: MethodChannel.Result) {
        if (pending != null || !store.isPending) {
            return result.error(LAST_OPERATION_NOT_FOUND, LAST_OPERATION_NOT_FOUND_MESSAGE, null)
        }
        store.clear()

        val file = lastOperationFile()
        if (!file.exists()) {
            Log.e(TAG, "Arquivo da última operação ausente: ${file.absolutePath}")
            return result.error(FILE_DOES_NOT_EXIST, LAST_OPERATION_FAILED_MESSAGE, null)
        }

        val outcome = try {
            DxResultParser.parse(file.readText(Charsets.UTF_8))
        } catch (exception: Exception) {
            Log.e(TAG, "Falha ao ler a última operação.", exception)
            return result.error(READ_OPERATION_FILE_FAILED, LAST_OPERATION_FAILED_MESSAGE, null)
        }
        reply(result, outcome)
    }

    private fun reply(result: MethodChannel.Result, outcome: SipagOutcome) = when (outcome) {
        is SipagOutcome.Approved -> result.success(outcome.response)
        is SipagOutcome.Failed -> result.error(outcome.code, outcome.message, outcome.details)
    }

    private fun onMainThread(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainThread.post(block)
    }

    companion object {
        const val CHANNEL = "sipag_sdk"

        /** O handler da activity atual. A integração cria um a cada `configure`. */
        @Volatile
        private var active: SipagPaymentHandler? = null

        private const val TAG = "SipagPaymentHandler"

        private const val GET_LAST_OPERATION = "get_last_operation"
        private const val PAY_CREDIT = "pay_credit"
        private const val PAY_DEBIT = "pay_debit"
        private const val PAY_PIX = "pay_pix"
        private const val REFUND = "refund"
        private const val REFUND_PIX = "refund_pix"

        private const val AMOUNT = "amount"
        private const val NSU = "nsu"
    }
}
