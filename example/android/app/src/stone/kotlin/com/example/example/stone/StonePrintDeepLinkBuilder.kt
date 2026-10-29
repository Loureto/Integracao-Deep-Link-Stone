
package com.example.example.stone.print

import android.content.Intent
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject

/** Deep link de impressão da Stone com os mesmos parâmetros do stone_sdk, usado hoje pelo flutter_acquirers_sdk. */
internal class StonePrintDeepLinkBuilder(
    private val returnScheme: String
) {

    fun build(imageBase64: String): Intent {
        val content = JSONArray().put(
            JSONObject()
                .put(TYPE, IMAGE)
                .put(IMAGE_PATH, imageBase64)
        )

        val uri = Uri.Builder()
            .scheme(SCHEME)
            .authority(AUTHORITY)
            .appendQueryParameter(SHOW_FEEDBACK_SCREEN, "false")
            .appendQueryParameter(SCHEME_RETURN, returnScheme)
            .appendQueryParameter(PRINTABLE_CONTENT, content.toString())
            .build()

        return Intent(Intent.ACTION_VIEW, uri).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }

    companion object {
        private const val SCHEME = "printer-app"
        private const val AUTHORITY = "print"

        private const val SHOW_FEEDBACK_SCREEN = "SHOW_FEEDBACK_SCREEN"
        private const val SCHEME_RETURN = "SCHEME_RETURN"
        private const val PRINTABLE_CONTENT = "PRINTABLE_CONTENT"

        private const val TYPE = "type"
        private const val IMAGE = "image"

        /** Apesar do nome, a Stone espera aqui a imagem em base64, não um caminho de arquivo. */
        private const val IMAGE_PATH = "imagePath"
    }
}
