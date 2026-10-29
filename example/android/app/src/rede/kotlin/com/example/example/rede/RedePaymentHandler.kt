package com.example.example.rede

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import rede.smartrede.sdk.FlexTipoPagamento
import rede.smartrede.sdk.PaymentStatus
import rede.smartrede.sdk.RedePayments
import rede.smartrede.sdk.Receipt

/**
 * Pagamento e estorno pelo app da Rede, com os métodos, códigos e respostas do plugin `flutter_rede_sdk` do
 * flutter_acquirers_sdk: o app é aberto com `startActivityForResult`, e a resposta ao Dart fica guardada até
 * o [onActivityResult].
 */
internal class RedePaymentHandler(private val activity: Activity, private val app: RedePaymentApp) {

    /**
     * Resposta à espera do app da Rede. Uma operação nova fica com o próximo retorno, como no plugin; a
     * impressão nunca mexe aqui (no plugin, um campo só guardava a resposta de qualquer chamada).
     */
    private var pending: MethodChannel.Result? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            CREDIT_PAYMENT -> pay(call, FlexTipoPagamento.CREDITO_A_VISTA, result)
            DEBIT_PAYMENT -> pay(call, FlexTipoPagamento.DEBITO, result)
            PIX_PAYMENT -> pay(call, FlexTipoPagamento.PIX, result)
            REFUND -> refund(call, result)
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PAYMENT_REQUEST && requestCode != REFUND_REQUEST) return false

        val result = pending ?: return true
        pending = null

        val refund = requestCode == REFUND_REQUEST
        when (resultCode) {
            Activity.RESULT_OK -> replyPayment(result, data, refund)
            Activity.RESULT_CANCELED -> result.error(OPERATION_CANCELED, OPERATION_CANCELED_MESSAGE, null)
            else -> result.error(UNKNOWN_ERROR, UNKNOWN_ERROR_MESSAGE, null)
        }
        return true
    }

    private fun replyPayment(result: MethodChannel.Result, data: Intent?, refund: Boolean) {
        // No plugin, um retorno com dados mas sem pagamento ficava sem resposta, e um que o SDK não conseguia
        // ler (BadParcelableException, ClassCastException) derrubava o app.
        val payment = try {
            data?.let { RedePayments.getPaymentFromIntent(it) }
        } catch (exception: RuntimeException) {
            Log.e(TAG, "Retorno do app da Rede ilegível.", exception)
            null
        }
        when {
            payment == null -> result.error(ERRO_DESCONHECIDO, UNKNOWN_ERROR_MESSAGE, null)
            payment.status == PaymentStatus.AUTHORIZED ->
                result.success(if (refund) REFUND_RESPONSE else paymentResponse(payment.receipt))
            payment.status == PaymentStatus.FAILED && refund ->
                result.error(REFUND_FAILED, REFUND_FAILED_MESSAGE, null)
            payment.status == PaymentStatus.FAILED ->
                result.error(TRANSACTION_FAILED, TRANSACTION_FAILED_MESSAGE, null)
            refund -> result.error(REFUND_DENY, REFUND_DENY_MESSAGE, null)
            else -> result.error(TRANSACTION_DENY, TRANSACTION_DENY_MESSAGE, null)
        }
    }

    /**
     * Chaves do `TransactionResponse` do plugin. No `CARD_NUMBER` vai o tipo da operação, e no Pix a
     * autorização é o NSU, como lá. Campo nulo vai nulo, e o Dart o lê como texto vazio; no plugin, ele
     * quebrava o Dart.
     */
    private fun paymentResponse(receipt: Receipt?): Map<String, Any?> {
        val operationType = receipt?.operationType
        val pix = operationType?.lowercase()?.contains(PIX) == true
        return mapOf(
            FLAG to (receipt?.issuerName ?: operationType?.let { "Pagamento $it" }),
            NSU_SITEF to receipt?.nsu,
            AUTHORIZATION to if (pix) receipt?.nsu else receipt?.auto,
            INSTALLMENTS to receipt?.installments,
            AMOUNT to receipt?.value,
            CARD_NUMBER to operationType
        )
    }

    private fun pay(call: MethodCall, type: FlexTipoPagamento, result: MethodChannel.Result) {
        val amount = call.argument<Number>(AMOUNT_ARGUMENT)
        if (amount == null) {
            result.error(AMOUNT_ARGUMENT, "$AMOUNT_ARGUMENT is null", null)
            return
        }

        start(PAYMENT_REQUEST, result, START_PAYMENT_ERROR) { app.paymentIntent(type, amount.toLong()) }
    }

    private fun refund(call: MethodCall, result: MethodChannel.Result) {
        val nsu = call.argument<String>(NSU_ARGUMENT)
        if (nsu == null) {
            result.error(NSU_ARGUMENT, "$NSU_ARGUMENT is null", null)
            return
        }

        start(REFUND_REQUEST, result, START_REFUND_ERROR) { app.reversalIntent(nsu) }
    }

    /** No plugin, uma exceção ao abrir o app só ia para o log, e o Dart ficava esperando. */
    private fun start(
        requestCode: Int,
        result: MethodChannel.Result,
        fallback: String,
        intent: () -> Intent
    ) {
        try {
            activity.startActivityForResult(intent(), requestCode)
            pending = result
        } catch (exception: ActivityNotFoundException) {
            result.error(ERRO_DESCONHECIDO, NO_PAYMENT_APP, null)
        } catch (exception: Exception) {
            Log.e(TAG, "Erro ao abrir o app da Rede.", exception)
            result.error(ERRO_DESCONHECIDO, exception.message ?: fallback, null)
        }
    }

    companion object {
        const val PAYMENT_REQUEST = 4
        const val REFUND_REQUEST = 5

        private const val TAG = "RedePaymentHandler"

        private const val CREDIT_PAYMENT = "credit_payment"
        private const val DEBIT_PAYMENT = "debit_payment"
        private const val PIX_PAYMENT = "pix_payment"
        private const val REFUND = "refund"
        private const val AMOUNT_ARGUMENT = "amount"
        private const val NSU_ARGUMENT = "nsu"
        private const val PIX = "pix"

        /** Métodos do canal `rede_sdk` que este handler atende. */
        val METHODS = setOf(CREDIT_PAYMENT, DEBIT_PAYMENT, PIX_PAYMENT, REFUND)

        private const val FLAG = "FLAG"
        private const val NSU_SITEF = "NSU_SITEF"
        private const val AUTHORIZATION = "AUTHORIZATION"
        private const val INSTALLMENTS = "INSTALLMENTS"
        private const val AMOUNT = "AMOUNT"
        private const val CARD_NUMBER = "CARD_NUMBER"

        /** O estorno aprovado volta sempre com estes valores, como no plugin. */
        private val REFUND_RESPONSE = mapOf(
            FLAG to "Estorno",
            NSU_SITEF to "",
            AUTHORIZATION to "",
            INSTALLMENTS to 1,
            AMOUNT to 0.0,
            CARD_NUMBER to "refund"
        )

        private const val ERRO_DESCONHECIDO = "ERRO_DESCONHECIDO"
        private const val UNKNOWN_ERROR = "UNKNOWN_ERROR"
        private const val UNKNOWN_ERROR_MESSAGE = "Erro desconhecido, tente novamente!"
        private const val TRANSACTION_FAILED = "TRANSACTION_FAILED"
        private const val TRANSACTION_FAILED_MESSAGE = "Falha ao efetuar a transação!"
        private const val REFUND_FAILED = "REFUND_FAILED"
        private const val REFUND_FAILED_MESSAGE = "Falha ao realizar estorno!"
        private const val TRANSACTION_DENY = "TRANSACTION_DENY"
        private const val TRANSACTION_DENY_MESSAGE = "Operação negada!"
        private const val REFUND_DENY = "REFUND_DENY"
        private const val REFUND_DENY_MESSAGE = "Estorno negado!"
        private const val OPERATION_CANCELED = "OPERATION_CANCELED"
        private const val OPERATION_CANCELED_MESSAGE = "Operação cancelada!"
        private const val NO_PAYMENT_APP = "Não localizamos aplicativo de pagamento neste terminal."
        private const val START_PAYMENT_ERROR = "Erro ao iniciar pagamento, tente novamente!"
        private const val START_REFUND_ERROR = "Erro ao iniciar estorno, tente novamente!"
    }
}
