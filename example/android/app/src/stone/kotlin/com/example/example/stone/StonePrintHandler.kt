
package com.example.example.stone.print

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Impressão pelo deep link da Stone, como no stone_sdk do flutter_acquirers_sdk: a resposta ao Dart fica guardada
 * até o app de impressão voltar no host `print`, com o resultado em `DEEPLINK_RETURN`.
 */
internal class StonePrintHandler(
    private val context: Context,
    private val returnScheme: String
) {

    private val deepLinkBuilder = StonePrintDeepLinkBuilder(returnScheme)

    /** Impressão à espera do retorno. Uma impressão nova fica com o próximo retorno, como no stone_sdk. */
    private var pending: MethodChannel.Result? = null

    fun printReceipt(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val imageBase64 = call.argument<String>(IMAGE_BASE64)
        if (imageBase64.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "$IMAGE_BASE64 é obrigatório.", null)
            return
        }

        try {
            context.startActivity(deepLinkBuilder.build(imageBase64))
            pending = result
        } catch (exception: ActivityNotFoundException) {
            result.error("PRINTER_APP_NOT_FOUND", "Nenhum aplicativo disponível para imprimir.", null)
        }
    }

    fun handle(intent: Intent) {
        val uri = intent.data ?: return
        if (uri.scheme != returnScheme || uri.host != PRINT_HOST) return

        val result = pending ?: run {
            Log.w(TAG, "Retorno de impressão sem impressão pendente: ${uri.getQueryParameter(DEEPLINK_RETURN)}")
            return
        }
        pending = null

        when (val code = uri.getQueryParameter(DEEPLINK_RETURN)) {
            null -> result.error(UNKNOWN_ERROR, "Sem resposta da impressora.", null)
            SUCCESS -> result.success(SUCCESS)
            else -> result.error(code, MESSAGES[code] ?: GENERIC_ERROR, null)
        }
    }

    companion object {
        private const val TAG = "StonePrintHandler"
        const val PRINT_HOST = "print"

        private const val IMAGE_BASE64 = "image_base64"
        private const val DEEPLINK_RETURN = "DEEPLINK_RETURN"
        private const val SUCCESS = "SUCCESS"
        private const val UNKNOWN_ERROR = "UNKNOWN_ERROR"
        private const val GENERIC_ERROR = "Erro genérico da impressora."

        /** Mensagens do stone_sdk para cada retorno documentado pela Stone; os demais usam [GENERIC_ERROR]. */
        private val MESSAGES = mapOf(
            "PRINTER_OUT_OF_PAPER" to "Impressora sem papel ou com a tampa de bobina aberta.",
            "PRINTER_INIT_ERROR" to "Erro ao inicializar a impressora.",
            "PRINTER_LOW_ENERGY" to "Máquina com baixa energia.",
            "PRINTER_BUSY" to "Impressora ocupada, há alguma impressão em andamento.",
            "PRINTER_UNSUPPORTED_FORMAT" to
                "Algum formato enviado não corresponde ao padrão de texto, imagem ou texto customizado.",
            "PRINTER_INVALID_DATA" to "Limite máximo do buffer foi ultrapassado.",
            "PRINTER_OVERHEATING" to "Superaquecimento da impressora.",
            "PRINTER_PAPER_JAM" to "Papel preso na caixa de bobina."
        )
    }
}
