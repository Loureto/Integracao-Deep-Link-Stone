
package com.example.example.vero

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Pagamento e estorno pelo app da Vero, com os métodos, Intents e respostas do plugin `vero_flutter` do
 * flutter_acquirers_sdk: o app é aberto com `startActivityForResult`, e a resposta ao Dart fica guardada até o
 * [onActivityResult].
 */
internal class VeroPaymentHandler(private val activity: Activity) {

    /** Resposta à espera do app da Vero. Uma operação nova fica com o próximo retorno, como no plugin. */
    private var pending: MethodChannel.Result? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            PAY_CREDIT -> pay(call, CREDIT_TRANSACTION, result)
            PAY_DEBIT -> pay(call, DEBIT_TRANSACTION, result)
            PAY_PIX -> pay(call, PIX_TRANSACTION, result)
            WALLET -> pay(call, WALLET_TRANSACTION, result)
            REFUND -> refund(call, result)
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PAYMENT_REQUEST) return false

        val result = pending ?: return true
        pending = null

        if (data?.hasExtra(ERROR) == true) {
            val message = data.getStringExtra(ERROR)?.trimStart('.', ' ')?.takeIf { it.isNotBlank() }
            result.error(UNKNOWN_ERROR, message ?: TRANSACTION_REJECTED, TRANSACTION_REJECTED)
            return true
        }

        // A AUTORIZACAO aprova em qualquer tipo: lida só como String, uma numérica viraria cancelamento depois da
        // cobrança.
        val extras = data?.extras
        if (resultCode == Activity.RESULT_OK && extras?.textOf(AUTHORIZATION)?.isNotEmpty() == true) {
            result.success(extras.toMap(activity.applicationContext))
            return true
        }

        result.error(UNKNOWN_ERROR, CANCELED_BY_USER, null)
        return true
    }

    private fun pay(call: MethodCall, transaction: String, result: MethodChannel.Result) {
        val amount = call.argument<Number>(AMOUNT)
        if (amount == null) {
            result.error(INVALID_ARGUMENT, "$AMOUNT é obrigatório.", null)
            return
        }

        // O valor vai como o Number recebido do canal, como no plugin.
        val intent = Intent(PAYMENT_INTENT)
            .putExtra(TRANSACTION_AMOUNT, amount)
            .putExtra(TRANSACTION, transaction)
        start(intent, result)
    }

    private fun refund(call: MethodCall, result: MethodChannel.Result) {
        val nsu = call.argument<String>(NSU_ARGUMENT)
        if (nsu == null) {
            result.error(INVALID_ARGUMENT, "$NSU_ARGUMENT é obrigatório.", null)
            return
        }

        start(Intent(REFUND_INTENT).putExtra(NSU, nsu), result)
    }

    private fun start(intent: Intent, result: MethodChannel.Result) {
        // Quem imprime o comprovante é o driver genérico, chamado pelo core depois da resposta.
        intent.putExtra(RECEIPT_PRINTING, false)

        try {
            activity.startActivityForResult(intent, PAYMENT_REQUEST)
            pending = result
        } catch (exception: ActivityNotFoundException) {
            result.error(UNKNOWN_ERROR, NO_PAYMENT_APP, null)
        } catch (exception: Exception) {
            Log.e(TAG, "Erro ao abrir o app da Vero.", exception)
            result.error(UNKNOWN_ERROR, exception.message ?: OPEN_ERROR, null)
        }
    }

    companion object {
        const val CHANNEL = "vero_flutter"
        const val PAYMENT_REQUEST = 1

        private const val TAG = "VeroPaymentHandler"

        private const val PAY_CREDIT = "payCredit"
        private const val PAY_DEBIT = "payDebit"
        private const val PAY_PIX = "payPix"
        private const val WALLET = "wallet"
        private const val REFUND = "refund"
        private const val AMOUNT = "amount"
        private const val NSU_ARGUMENT = "nsu"

        private const val PAYMENT_INTENT = "br.com.execucao.PAGAR"
        private const val REFUND_INTENT = "br.com.execucao.ESTORNAR"
        private const val TRANSACTION_AMOUNT = "VALOR"
        private const val TRANSACTION = "TRANSACAO"
        private const val NSU = "NSU"
        private const val RECEIPT_PRINTING = "IMPRIMIR_COMPROVANTE"
        private const val CREDIT_TRANSACTION = "CREDITO_GENERICO"
        private const val DEBIT_TRANSACTION = "DEBITO"
        private const val PIX_TRANSACTION = "PIX"
        private const val WALLET_TRANSACTION = "WALLET"

        private const val AUTHORIZATION = "AUTORIZACAO"
        private const val ERROR = "ERRO"

        private const val UNKNOWN_ERROR = "ERRO_DESCONHECIDO"
        private const val INVALID_ARGUMENT = "INVALID_ARGUMENT"
        private const val TRANSACTION_REJECTED = "Transação rejeitada"
        private const val CANCELED_BY_USER = "Operação cancelada pelo usuário!"
        private const val NO_PAYMENT_APP = "Não localizamos aplicativo de pagamento neste terminal."
        private const val OPEN_ERROR = "Não foi possível abrir o aplicativo de pagamento."
    }
}
