package com.example.example.stone.print

import android.app.Application
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
class StonePrintHandlerTest {

    private val application: Application = RuntimeEnvironment.getApplication()
    private val handler = StonePrintHandler(application, RETURN_SCHEME)

    @Test
    fun `abre o deeplink de impressao com a imagem e espera o retorno para responder`() {
        val result = RecordingResult()

        handler.printReceipt(call(IMAGE), result)

        val uri = shadowOf(application).nextStartedActivity.data!!
        assertEquals("printer-app", uri.scheme)
        assertEquals("print", uri.host)
        assertEquals("false", uri.getQueryParameter("SHOW_FEEDBACK_SCREEN"))
        assertEquals(RETURN_SCHEME, uri.getQueryParameter("SCHEME_RETURN"))
        val content = JSONArray(uri.getQueryParameter("PRINTABLE_CONTENT"))
        assertEquals(1, content.length())
        assertEquals("image", content.getJSONObject(0).getString("type"))
        assertEquals(IMAGE, content.getJSONObject(0).getString("imagePath"))
        assertEquals(emptyList<String>(), result.replies)
    }

    @Test
    fun `responde SUCCESS quando a impressao termina`() {
        val result = RecordingResult()
        handler.printReceipt(call(IMAGE), result)

        handler.handle(printReturn("DEEPLINK_RETURN=SUCCESS"))

        assertEquals(listOf("success:SUCCESS"), result.replies)
    }

    @Test
    fun `repassa o codigo da impressora com a mensagem do stone_sdk`() {
        listOf(
            "PRINTER_OUT_OF_PAPER" to "Impressora sem papel ou com a tampa de bobina aberta.",
            "PRINTER_INIT_ERROR" to "Erro ao inicializar a impressora.",
            "PRINTER_LOW_ENERGY" to "Máquina com baixa energia.",
            "PRINTER_BUSY" to "Impressora ocupada, há alguma impressão em andamento.",
            "PRINTER_UNSUPPORTED_FORMAT" to
                "Algum formato enviado não corresponde ao padrão de texto, imagem ou texto customizado.",
            "PRINTER_INVALID_DATA" to "Limite máximo do buffer foi ultrapassado.",
            "PRINTER_OVERHEATING" to "Superaquecimento da impressora.",
            "PRINTER_PAPER_JAM" to "Papel preso na caixa de bobina.",
            "PRINTER_PRINT_ERROR" to "Erro genérico da impressora.",
            "CODIGO_NOVO" to "Erro genérico da impressora."
        ).forEach { (code, message) ->
            val result = RecordingResult()
            handler.printReceipt(call(IMAGE), result)

            handler.handle(printReturn("DEEPLINK_RETURN=$code"))

            assertEquals(listOf("error:$code:$message"), result.replies)
        }
    }

    @Test
    fun `retorno sem DEEPLINK_RETURN vira UNKNOWN_ERROR`() {
        val result = RecordingResult()
        handler.printReceipt(call(IMAGE), result)

        handler.handle(printReturn())

        assertEquals(listOf("error:UNKNOWN_ERROR:Sem resposta da impressora."), result.replies)
    }

    @Test
    fun `responde uma unica vez e ignora retorno sem impressao pendente`() {
        val result = RecordingResult()
        handler.printReceipt(call(IMAGE), result)

        handler.handle(printReturn("DEEPLINK_RETURN=SUCCESS"))
        handler.handle(printReturn("DEEPLINK_RETURN=PRINTER_BUSY"))

        assertEquals(listOf("success:SUCCESS"), result.replies)
    }

    @Test
    fun `ignora retorno de outro scheme ou de outro fluxo`() {
        val result = RecordingResult()
        handler.printReceipt(call(IMAGE), result)

        handler.handle(Intent(Intent.ACTION_VIEW, Uri.parse("outroapp://print?DEEPLINK_RETURN=SUCCESS")))
        handler.handle(Intent(Intent.ACTION_VIEW, Uri.parse("$RETURN_SCHEME://pay-response?code=0")))

        assertEquals(emptyList<String>(), result.replies)
    }

    @Test
    fun `responde PRINTER_APP_NOT_FOUND quando o app de impressao da Stone nao esta instalado`() {
        shadowOf(application).checkActivities(true)
        val result = RecordingResult()

        handler.printReceipt(call(IMAGE), result)
        handler.handle(printReturn("DEEPLINK_RETURN=SUCCESS"))

        assertEquals(
            listOf("error:PRINTER_APP_NOT_FOUND:Nenhum aplicativo disponível para imprimir."),
            result.replies
        )
    }

    @Test
    fun `responde INVALID_ARGUMENT sem abrir o app de impressao quando falta a imagem`() {
        val result = RecordingResult()

        handler.printReceipt(MethodCall("print_receipt", emptyMap<String, Any?>()), result)

        assertEquals(listOf("error:INVALID_ARGUMENT:image_base64 é obrigatório."), result.replies)
        assertNull(shadowOf(application).nextStartedActivity)
    }

    private fun call(imageBase64: String) = MethodCall("print_receipt", mapOf("image_base64" to imageBase64))

    private fun printReturn(query: String = "") =
        Intent(Intent.ACTION_VIEW, Uri.parse("$RETURN_SCHEME://print?$query"))

    private class RecordingResult : MethodChannel.Result {
        val replies = mutableListOf<String>()

        override fun success(result: Any?) {
            replies += "success:$result"
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            replies += "error:$errorCode:$errorMessage"
        }

        override fun notImplemented() {
            replies += "notImplemented"
        }
    }

    private companion object {
        const val RETURN_SCHEME = "paymentintegrationsstone"

        /** Base64 com `+`, `/` e `=`, que precisam chegar intactos ao app de impressão. */
        const val IMAGE = "iVBORw0KGgo+AAAA/NSUhEUg=="
    }
}
