package com.example.example.sipag

import android.content.Context
import android.util.Log
import ger7.com.br.pos7api.POS7API
import ger7.com.br.pos7api.ParamIn
import ger7.com.br.pos7api.ParamOut
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** O que o [P2Terminal] usa do pos7api, para os testes rodarem sem o app da Ger7. */
internal interface P2Sdk {
    /** Abre o app da Ger7 com os [params] e chama o [onResult] com a resposta dele. */
    fun process(context: Context, params: ParamIn, onResult: (ParamOut) -> Unit)
}

/**
 * O pos7api de verdade. O `processTransaction` abre a activity `Intercom` do AAR, que chama `pos7api://pos7`,
 * e um `AsyncTask` espera a saída dela para chamar o callback na main thread.
 */
internal object Pos7ApiSdk : P2Sdk {
    override fun process(context: Context, params: ParamIn, onResult: (ParamOut) -> Unit) {
        POS7API(context).processTransaction(params) { onResult(it) }
    }
}

/**
 * Sunmi P2 e P2-A11, pelo app da Ger7, como o `PaymentServiceP2Device` do plugin `flutter_sipag_sdk`: mesmos
 * tipos, produtos e id de transação (data e hora, `MMddHHmmss`). Recebe o contexto da aplicação, como lá.
 */
internal class P2Terminal(
    private val context: Context,
    private val sdk: P2Sdk = Pos7ApiSdk,
    private val now: () -> Long = System::currentTimeMillis
) : SipagTerminal {

    override fun creditPayment(amount: String, reply: SipagReply) =
        process(payment(CREDIT_PRODUCT, amount, installments = 1), reply)

    override fun debitPayment(amount: String, reply: SipagReply) =
        process(payment(DEBIT_PRODUCT, amount, installments = 1), reply)

    override fun pixPayment(amount: String, reply: SipagReply) = process(payment(PIX_PRODUCT, amount), reply)

    override fun refund(nsu: String, reply: SipagReply) = process(ParamIn().apply {
        trsType = REFUND_OPERATION
        trsRefundId = nsu
    }, reply)

    override fun pixRefund(nsu: String, reply: SipagReply) = process(ParamIn().apply {
        trsType = PIX_REFUND_OPERATION
        trsRefundPixId = nsu
    }, reply)

    /** O app da Ger7 recebe o valor em centavos: o texto do Dart sem a vírgula. */
    private fun payment(product: Int, amount: String, installments: Int? = null) = ParamIn().apply {
        trsType = TRANSACTION_OPERATION
        trsProduct = product
        trsAmount = amount.replace(",", "")
        installments?.let { trsInstallments = it }
    }

    private fun process(params: ParamIn, reply: SipagReply) {
        params.trsId = SimpleDateFormat("MMddHHmmss", Locale.getDefault()).format(Date(now()))
        try {
            sdk.process(context, params) { reply(P2ResultParser.parse(it)) }
        } catch (exception: Exception) {
            Log.e(TAG, "Falha ao abrir o app da Ger7.", exception)
            reply(SipagOutcome.Failed(ERRO_NA_OPERACAO, PAYMENT_FAILED))
        }
    }

    private companion object {
        const val TAG = "SipagP2"

        const val TRANSACTION_OPERATION = 1
        const val REFUND_OPERATION = 2
        const val PIX_REFUND_OPERATION = 21

        const val CREDIT_PRODUCT = 1
        const val DEBIT_PRODUCT = 2
        const val PIX_PRODUCT = 8
    }
}
