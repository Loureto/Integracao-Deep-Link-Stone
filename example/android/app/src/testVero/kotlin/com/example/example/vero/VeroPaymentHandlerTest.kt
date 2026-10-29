package com.example.example.vero

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
class VeroPaymentHandlerTest {

    private val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    private val handler = VeroPaymentHandler(activity)
    private val result = RecordingResult()

    @Test
    fun `payCredit abre o app da Vero com os extras do plugin e codigo 1`() {
        handler.handle(MethodCall("payCredit", mapOf("amount" to 100)), result)

        val started = shadowOf(activity).nextStartedActivityForResult
        assertEquals(1, started.requestCode)
        assertEquals("br.com.execucao.PAGAR", started.intent.action)
        assertEquals(100, started.intent.extras!!.get("VALOR"))
        assertEquals("CREDITO_GENERICO", started.intent.getStringExtra("TRANSACAO"))
        assertFalse(started.intent.getBooleanExtra("IMPRIMIR_COMPROVANTE", true))
        assertEquals(emptyList<Any?>(), result.replies)
    }

    @Test
    fun `payDebit payPix e wallet usam DEBITO PIX e WALLET`() {
        listOf("payDebit" to "DEBITO", "payPix" to "PIX", "wallet" to "WALLET").forEach { (method, transaction) ->
            handler.handle(MethodCall(method, mapOf("amount" to 250)), RecordingResult())

            val started = shadowOf(activity).nextStartedActivityForResult
            assertEquals(method, "br.com.execucao.PAGAR", started.intent.action)
            assertEquals(method, transaction, started.intent.getStringExtra("TRANSACAO"))
            assertEquals(method, 250, started.intent.extras!!.get("VALOR"))
        }
    }

    @Test
    fun `refund abre ESTORNAR com o NSU`() {
        handler.handle(MethodCall("refund", mapOf("nsu" to "123")), result)

        val started = shadowOf(activity).nextStartedActivityForResult
        assertEquals(1, started.requestCode)
        assertEquals("br.com.execucao.ESTORNAR", started.intent.action)
        assertEquals("123", started.intent.getStringExtra("NSU"))
        assertFalse(started.intent.getBooleanExtra("IMPRIMIR_COMPROVANTE", true))
    }

    @Test
    fun `RESULT_OK com AUTORIZACAO responde o mapa dos extras`() {
        handler.handle(MethodCall("payCredit", mapOf("amount" to 100)), result)

        val handled = handler.onActivityResult(
            1,
            Activity.RESULT_OK,
            Intent().putExtra("AUTORIZACAO", "A1").putExtra("NSU", "123").putExtra("PARCELAS", 1)
        )

        assertTrue(handled)
        assertEquals(listOf<Any?>(mapOf("AUTORIZACAO" to "A1", "NSU" to "123", "PARCELAS" to 1)), result.replies)
    }

    @Test
    fun `AUTORIZACAO que nao e texto tambem aprova`() {
        handler.handle(MethodCall("payCredit", mapOf("amount" to 100)), result)

        handler.onActivityResult(1, Activity.RESULT_OK, Intent().putExtra("AUTORIZACAO", 123456))

        assertEquals(listOf<Any?>(mapOf("AUTORIZACAO" to 123456)), result.replies)
    }

    @Test
    fun `URI de comprovante vira caminho de arquivo no cache`() {
        // O app da Vero devolve os comprovantes como URI de conteúdo.
        val receipt = Uri.parse("content://br.com.execucao.veromobile/comprovantes/via-cliente.png")
        shadowOf(activity.contentResolver).registerInputStream(receipt, ByteArrayInputStream(byteArrayOf(1, 2, 3)))
        handler.handle(MethodCall("payDebit", mapOf("amount" to 100)), result)

        handler.onActivityResult(
            1,
            Activity.RESULT_OK,
            Intent().putExtra("AUTORIZACAO", "A1").putExtra("COMPROVANTE_CLIENTE", receipt)
        )

        // Cada extra tem a sua pasta no cache, com o nome do arquivo da URI.
        val copy = File(File(activity.cacheDir, "COMPROVANTE_CLIENTE"), "via-cliente.png")
        assertEquals(copy.absolutePath, (result.replies.single() as Map<*, *>)["COMPROVANTE_CLIENTE"])
        assertEquals(listOf<Byte>(1, 2, 3), copy.readBytes().toList())
    }

    @Test
    fun `nome de URI com barras codificadas nao escreve fora do cache`() {
        // O lastPathSegment chega decodificado: %2F vira /, e o nome passaria a subir pastas.
        val receipt = Uri.parse("content://br.com.execucao.veromobile/comprovantes/..%2F..%2Fsaida.png")
        shadowOf(activity.contentResolver).registerInputStream(receipt, ByteArrayInputStream(byteArrayOf(1)))
        handler.handle(MethodCall("payDebit", mapOf("amount" to 100)), result)

        handler.onActivityResult(
            1,
            Activity.RESULT_OK,
            Intent().putExtra("AUTORIZACAO", "A1").putExtra("COMPROVANTE_CLIENTE", receipt)
        )

        val copy = File((result.replies.single() as Map<*, *>)["COMPROVANTE_CLIENTE"] as String)
        assertTrue(copy.canonicalPath.startsWith(activity.cacheDir.canonicalPath + File.separator))
        assertEquals(listOf<Byte>(1), copy.readBytes().toList())
    }

    @Test
    fun `comprovantes com o mesmo nome nao se sobrescrevem`() {
        val merchant = Uri.parse("content://br.com.execucao.veromobile/lojista/comprovante.png")
        val customer = Uri.parse("content://br.com.execucao.veromobile/cliente/comprovante.png")
        shadowOf(activity.contentResolver).registerInputStream(merchant, ByteArrayInputStream(byteArrayOf(1)))
        shadowOf(activity.contentResolver).registerInputStream(customer, ByteArrayInputStream(byteArrayOf(2)))
        handler.handle(MethodCall("payDebit", mapOf("amount" to 100)), result)

        handler.onActivityResult(
            1,
            Activity.RESULT_OK,
            Intent()
                .putExtra("AUTORIZACAO", "A1")
                .putExtra("COMPROVANTE_LOJISTA", merchant)
                .putExtra("COMPROVANTE_CLIENTE", customer)
        )

        val response = result.replies.single() as Map<*, *>
        assertEquals(listOf<Byte>(1), File(response["COMPROVANTE_LOJISTA"] as String).readBytes().toList())
        assertEquals(listOf<Byte>(2), File(response["COMPROVANTE_CLIENTE"] as String).readBytes().toList())
    }

    @Test
    fun `URI que nao abre vira nulo`() {
        handler.handle(MethodCall("payDebit", mapOf("amount" to 100)), result)

        handler.onActivityResult(
            1,
            Activity.RESULT_OK,
            Intent()
                .putExtra("AUTORIZACAO", "A1")
                .putExtra("COMPROVANTE_CLIENTE", Uri.parse("content://br.com.execucao.veromobile/comprovantes/x.png"))
        )

        val response = result.replies.single() as Map<*, *>
        assertTrue(response.containsKey("COMPROVANTE_CLIENTE"))
        assertNull(response["COMPROVANTE_CLIENTE"])
    }

    @Test
    fun `extra ERRO responde ERRO_DESCONHECIDO sem pontos e espacos no comeco`() {
        handler.handle(MethodCall("payCredit", mapOf("amount" to 100)), result)
        handler.onActivityResult(1, Activity.RESULT_CANCELED, Intent().putExtra("ERRO", ". Saldo insuficiente"))

        val blank = RecordingResult()
        handler.handle(MethodCall("payCredit", mapOf("amount" to 100)), blank)
        handler.onActivityResult(1, Activity.RESULT_CANCELED, Intent().putExtra("ERRO", " . "))

        assertEquals(listOf<Any?>("error:ERRO_DESCONHECIDO:Saldo insuficiente"), result.replies)
        assertEquals(listOf<Any?>("error:ERRO_DESCONHECIDO:Transação rejeitada"), blank.replies)
    }

    @Test
    fun `cancelado ou sem AUTORIZACAO responde Operacao cancelada pelo usuario`() {
        handler.handle(MethodCall("payPix", mapOf("amount" to 100)), result)
        handler.onActivityResult(1, Activity.RESULT_CANCELED, null)

        val withoutAuthorization = RecordingResult()
        handler.handle(MethodCall("payPix", mapOf("amount" to 100)), withoutAuthorization)
        handler.onActivityResult(1, Activity.RESULT_OK, Intent().putExtra("NSU", "123"))

        assertEquals(listOf<Any?>("error:ERRO_DESCONHECIDO:Operação cancelada pelo usuário!"), result.replies)
        assertEquals(
            listOf<Any?>("error:ERRO_DESCONHECIDO:Operação cancelada pelo usuário!"),
            withoutAuthorization.replies
        )
    }

    @Test
    fun `responde uma unica vez`() {
        handler.handle(MethodCall("payCredit", mapOf("amount" to 100)), result)

        handler.onActivityResult(1, Activity.RESULT_OK, Intent().putExtra("AUTORIZACAO", "A1"))
        val handledAgain = handler.onActivityResult(1, Activity.RESULT_CANCELED, null)

        assertTrue(handledAgain)
        assertEquals(1, result.replies.size)
    }

    @Test
    fun `outro requestCode e ignorado`() {
        handler.handle(MethodCall("payCredit", mapOf("amount" to 100)), result)

        val handled = handler.onActivityResult(2, Activity.RESULT_OK, Intent().putExtra("AUTORIZACAO", "A1"))

        assertFalse(handled)
        assertEquals(emptyList<Any?>(), result.replies)
    }

    @Test
    fun `app da Vero ausente responde ERRO_DESCONHECIDO`() {
        shadowOf(RuntimeEnvironment.getApplication()).checkActivities(true)

        handler.handle(MethodCall("payCredit", mapOf("amount" to 100)), result)

        assertEquals(
            listOf<Any?>("error:ERRO_DESCONHECIDO:Não localizamos aplicativo de pagamento neste terminal."),
            result.replies
        )
    }

    @Test
    fun `outra excecao ao abrir o app da Vero responde ERRO_DESCONHECIDO com a mensagem`() {
        val failing = Robolectric.buildActivity(FailingActivity::class.java).setup().get()
        val failingHandler = VeroPaymentHandler(failing)
        val withoutMessage = RecordingResult()

        failing.failure = SecurityException("Permissão negada")
        failingHandler.handle(MethodCall("payCredit", mapOf("amount" to 100)), result)
        failing.failure = SecurityException()
        failingHandler.handle(MethodCall("payCredit", mapOf("amount" to 100)), withoutMessage)

        assertEquals(listOf<Any?>("error:ERRO_DESCONHECIDO:Permissão negada"), result.replies)
        assertEquals(
            listOf<Any?>("error:ERRO_DESCONHECIDO:Não foi possível abrir o aplicativo de pagamento."),
            withoutMessage.replies
        )
    }

    @Test
    fun `operacao nova fica com o proximo retorno`() {
        val first = RecordingResult()
        handler.handle(MethodCall("payCredit", mapOf("amount" to 100)), first)
        handler.handle(MethodCall("payDebit", mapOf("amount" to 200)), result)

        handler.onActivityResult(1, Activity.RESULT_OK, Intent().putExtra("AUTORIZACAO", "A2"))

        assertEquals(emptyList<Any?>(), first.replies)
        assertEquals(listOf<Any?>(mapOf("AUTORIZACAO" to "A2")), result.replies)
    }

    @Test
    fun `sem amount ou nsu responde INVALID_ARGUMENT sem abrir o app`() {
        val withoutNsu = RecordingResult()

        handler.handle(MethodCall("payCredit", emptyMap<String, Any?>()), result)
        handler.handle(MethodCall("refund", emptyMap<String, Any?>()), withoutNsu)

        assertEquals(listOf<Any?>("error:INVALID_ARGUMENT:amount é obrigatório."), result.replies)
        assertEquals(listOf<Any?>("error:INVALID_ARGUMENT:nsu é obrigatório."), withoutNsu.replies)
        assertNull(shadowOf(activity).nextStartedActivityForResult)
    }

    /** Activity em que abrir outro app lança [failure], como quando o sistema nega a abertura. */
    class FailingActivity : Activity() {
        var failure: RuntimeException = SecurityException()

        override fun startActivityForResult(intent: Intent, requestCode: Int) {
            throw failure
        }
    }

    /** Guarda o valor das respostas de sucesso e o código e a mensagem dos erros. */
    private class RecordingResult : MethodChannel.Result {
        val replies = mutableListOf<Any?>()

        override fun success(result: Any?) {
            replies += result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            replies += "error:$errorCode:$errorMessage"
        }

        override fun notImplemented() {
            replies += "notImplemented"
        }
    }
}
