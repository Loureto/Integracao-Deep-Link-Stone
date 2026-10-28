
package com.example.example.cielo

import android.content.Intent
import android.util.Base64
import android.util.Log

internal class CieloResponseHandler(
    private val returnScheme: String,
    private val onResponse: (Map<String, String?>) -> Unit
) {

    /** Repassa a ação, o `responsecode` e o JSON decodificado do `response`, nulo se ausente ou inválido. */
    fun handle(intent: Intent) {
        val uri = intent.data ?: return
        val action = CieloAction.fromValue(uri.host)

        if (uri.scheme != returnScheme || action == null) {
            Log.w(TAG, "Retorno ignorado: ${uri.scheme}://${uri.host} não é um retorno da Cielo.")
            return
        }

        onResponse(
            mapOf(
                ACTION to action.value,
                RESPONSE_CODE to uri.getQueryParameter(RESPONSE_CODE_PARAMETER),
                RESPONSE to decode(uri.getQueryParameter(RESPONSE_PARAMETER))
            )
        )
    }

    /**
     * A Cielo devolve Base64 com quebras de linha (Base64.DEFAULT), que o decoder do Android ignora. O
     * getQueryParameter troca '+' por espaço, e espaço não existe no Base64, então ele volta a ser '+'.
     */
    private fun decode(response: String?): String? {
        if (response.isNullOrBlank()) return null

        return try {
            String(Base64.decode(response.replace(' ', '+'), Base64.DEFAULT), Charsets.UTF_8)
        } catch (exception: IllegalArgumentException) {
            Log.e(TAG, "Retorno da Cielo com Base64 inválido.", exception)
            null
        }
    }

    companion object {
        private const val TAG = "CieloResponse"
        private const val ACTION = "action"
        private const val RESPONSE = "response"
        private const val RESPONSE_CODE = "responseCode"
        private const val RESPONSE_PARAMETER = "response"
        private const val RESPONSE_CODE_PARAMETER = "responsecode"
    }
}
