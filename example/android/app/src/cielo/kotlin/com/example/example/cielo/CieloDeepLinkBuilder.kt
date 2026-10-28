
package com.example.example.cielo

import android.content.Intent
import android.net.Uri
import android.util.Base64

internal class CieloDeepLinkBuilder(
    private val returnScheme: String
) {

    /** [request] é o JSON da operação, montado no Dart; vai em Base64 no parâmetro `request`. */
    fun build(action: CieloAction, request: String?): Intent {
        require(!action.requiresRequest || !request.isNullOrBlank()) {
            "request é obrigatório para ${action.value}."
        }

        // O Uri.Builder codifica os parâmetros: sem isso, o '+' do Base64 chegaria como espaço na Cielo.
        val uri = Uri.Builder()
            .scheme(SCHEME)
            .authority(action.value)
            .apply {
                if (action.requiresRequest) appendQueryParameter(REQUEST, encode(request!!))
            }
            .appendQueryParameter(URL_CALLBACK, "$returnScheme://${action.value}")
            .build()

        // Mesma flag da documentação Cielo: com a MainActivity singleTop, o retorno chega no onNewIntent.
        return Intent(Intent.ACTION_VIEW, uri).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
    }

    // NO_WRAP: o Base64.DEFAULT quebra a linha a cada 76 caracteres, e a quebra não pode ir na URI.
    private fun encode(json: String): String =
        Base64.encodeToString(json.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)

    companion object {
        private const val SCHEME = "lio"
        private const val REQUEST = "request"
        private const val URL_CALLBACK = "urlCallback"
    }
}
