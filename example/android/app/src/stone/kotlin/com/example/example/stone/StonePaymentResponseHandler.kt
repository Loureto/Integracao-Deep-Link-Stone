
package com.example.example.stone.payment

import android.content.Intent
import android.util.Log

internal class StonePaymentResponseHandler(
    private val returnScheme: String,
    private val onResponse: (Map<String, String?>) -> Unit
) {

    fun handle(intent: Intent) {
        val uri = intent.data ?: return

        if (uri.scheme != returnScheme || uri.host != PAYMENT_RESPONSE_HOST) {
            Log.w(TAG, "Retorno ignorado: scheme/host diferente de $returnScheme://$PAYMENT_RESPONSE_HOST.")
            return
        }

        try {
            val response = uri.queryParameterNames.associateWith { uri.getQueryParameter(it) }

            Log.i(TAG, "Resposta recebida: code=${response[CODE]}")
            onResponse(response)
        } catch (exception: Exception) {
            Log.e(TAG, "Erro ao interpretar a resposta do pagamento.", exception)
        }
    }

    companion object {
        private const val TAG = "StonePaymentResponse"
        private const val PAYMENT_RESPONSE_HOST = "pay-response"
        private const val CODE = "code"
    }
}
