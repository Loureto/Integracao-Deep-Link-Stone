
package com.example.example.stone.payment

import android.content.ActivityNotFoundException
import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class StonePaymentHandler(
    private val context: Context,
    returnScheme: String
) {

    private val deepLinkBuilder = StoneDeepLinkBuilder(returnScheme)

    fun sendPayment(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val intent = try {
            deepLinkBuilder.build(call.toPaymentRequest())
        } catch (exception: IllegalArgumentException) {
            result.error("INVALID_ARGUMENT", exception.message, null)
            return
        } catch (exception: ClassCastException) {
            result.error("INVALID_ARGUMENT", "Tipo de argumento inválido.", null)
            return
        }

        try {
            context.startActivity(intent)

            Log.d(TAG, "Deep Link iniciado: ${intent.data}")
            result.success(true)
        } catch (exception: ActivityNotFoundException) {
            result.error(
                "PAYMENT_APP_NOT_FOUND",
                "Nenhum aplicativo disponível para processar o pagamento.",
                null
            )
        } catch (exception: Exception) {
            Log.e(TAG, "Erro ao iniciar o pagamento.", exception)

            result.error(
                "PAYMENT_START_ERROR",
                exception.message ?: "Não foi possível iniciar o pagamento.",
                null
            )
        }
    }

    private fun MethodCall.toPaymentRequest() = StonePaymentRequest(
        amount = longArgument("amount"),
        editableAmount = argument<Boolean>("editableAmount"),
        transactionType = argument<String>("transactionType"),
        installmentCount = longArgument("installmentCount"),
        installmentType = argument<String>("installmentType"),
        orderId = longArgument("orderId"),
        returnScheme = argument<String>("returnScheme")
    )

    private fun MethodCall.longArgument(key: String): Long? =
        when (val value = argument<Any>(key)) {
            null -> null
            is Int -> value.toLong()
            is Long -> value
            else -> throw IllegalArgumentException("$key deve ser um número inteiro.")
        }

    companion object {
        private const val TAG = "StonePaymentHandler"
    }
}
