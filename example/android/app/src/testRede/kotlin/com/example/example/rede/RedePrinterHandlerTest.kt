package com.example.example.rede

import android.graphics.Bitmap
import com.example.example.printer.TEST_PRINT_TEXT
import com.example.example.printer.textToBitmap
import io.flutter.plugin.common.MethodCall
import java.io.ByteArrayOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import rede.smartrede.commons.exception.PrinterException

/**
 * O flavor exige a API 28, e o Robolectric só desenha de verdade (NATIVE) a partir da 26: os testes rodam na
 * API 30.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [30])
class RedePrinterHandlerTest {

    private val printer = FakeConnectorPrinter()
    private var opened = 0
    private val handler = RedePrinterHandler {
        opened++
        printer
    }
    private val result = RecordingResult()

    private val printed = listOf<Any?>("Sucesso ao efetuar a impressão")

    private fun printTxt(handler: RedePrinterHandler = this.handler, result: RecordingResult = this.result) =
        handler.handle(MethodCall("print_txt", mapOf("text" to "LINHA")), result)

    @Test
    fun `print_txt imprime o texto em 576 px e responde sucesso`() {
        printTxt()

        assertEquals(576, printer.printed.single().width)
        assertEquals(printed, result.replies)
    }

    @Test
    fun `print_receipt decodifica o PNG e imprime`() {
        val png = ByteArrayOutputStream().also {
            Bitmap.createBitmap(10, 4, Bitmap.Config.ARGB_8888).compress(Bitmap.CompressFormat.PNG, 100, it)
        }.toByteArray()

        handler.handle(MethodCall("print_receipt", mapOf("bitmap" to png)), result)

        assertEquals(listOf(10, 4), listOf(printer.printed.single().width, printer.printed.single().height))
        assertEquals(printed, result.replies)
    }

    @Test
    fun `test_print imprime Impressao teste`() {
        handler.handle(MethodCall("test_print", null), result)

        assertTrue(printer.printed.single().sameAs(textToBitmap(TEST_PRINT_TEXT)))
        assertEquals(printed, result.replies)
    }

    @Test
    fun `Printer out of paper responde ERRO_SEM_PAPEL`() {
        printer.onPrint = { it!!.onError("Printer out of paper") }

        printTxt()

        assertEquals(listOf<Any?>("error:ERRO_SEM_PAPEL:Impressora sem papel, verifique!"), result.replies)
    }

    @Test
    fun `Init failed e Printer not ready respondem IMPRESSORA_INDISPONIVEL`() {
        listOf("Init failed", "Printer not ready").forEach { message ->
            val result = RecordingResult()
            printer.onPrint = { it!!.onError(message) }

            printTxt(result = result)

            assertEquals(
                message,
                listOf<Any?>("error:IMPRESSORA_INDISPONIVEL:Módulo de impressão não inicializado"),
                result.replies
            )
        }
    }

    @Test
    fun `erro do SDK durante a impressao interrompe o SDK, como no plugin`() {
        // Se o callback só guardar o erro, o SDK segue para a nova tentativa atrasada dele: imprime de novo
        // um segundo depois ou derruba o app na terceira vez.
        var sdkContinued = false
        printer.onPrint = { callback ->
            callback!!.onError("Init failed")
            sdkContinued = true
        }

        printTxt()

        assertFalse(sdkContinued)
        assertEquals(
            listOf<Any?>("error:IMPRESSORA_INDISPONIVEL:Módulo de impressão não inicializado"),
            result.replies
        )
    }

    @Test
    fun `erro repetido pelo catch do SDK ainda interrompe e mantem o primeiro erro`() {
        // O doPrint do SDK captura a exceção e chama o onError de novo com a mensagem dela.
        var sdkContinued = false
        printer.onPrint = { callback ->
            try {
                callback!!.onError("Printer out of paper")
            } catch (exception: RuntimeException) {
                callback!!.onError(exception.message ?: "Error during print")
            }
            sdkContinued = true
        }

        printTxt()

        assertFalse(sdkContinued)
        assertEquals(listOf<Any?>("error:ERRO_SEM_PAPEL:Impressora sem papel, verifique!"), result.replies)
    }

    @Test
    fun `erro do SDK depois que a impressao terminou so vai para o log`() {
        // Um erro que o serviço de impressão avise depois, por outra thread, não tem a quem responder.
        printTxt()

        printer.callback!!.onError("Printer out of paper")
        val next = RecordingResult()
        printTxt(result = next)

        assertEquals(printed, result.replies)
        assertEquals(printed, next.replies)
    }

    @Test
    fun `prepare abre a impressora e registra o callback sem imprimir`() {
        handler.prepare()

        assertEquals(1, opened)
        assertEquals(1, printer.callbackRegistrations)
        assertTrue(printer.printed.isEmpty())
    }

    @Test
    fun `prepare sem o SDK nao lanca, e a impressao tenta abrir de novo`() {
        var attempts = 0
        val withoutSdk = RedePrinterHandler {
            attempts++
            throw IllegalStateException("SDK da Rede indisponível neste aparelho")
        }

        withoutSdk.prepare()
        printTxt(withoutSdk)

        assertEquals(2, attempts)
        assertEquals(
            listOf<Any?>("error:IMPRESSORA_INDISPONIVEL:Módulo de impressão não inicializado"),
            result.replies
        )
    }

    @Test
    fun `outra mensagem do SDK responde ERRO_DESCONHECIDO`() {
        printer.onPrint = { it!!.onError("Error during print") }

        printTxt()

        assertEquals(listOf<Any?>("error:ERRO_DESCONHECIDO:Erro na impressão"), result.replies)
    }

    @Test
    fun `PrinterException responde pela mensagem dela`() {
        printer.onPrint = { throw PrinterException("Printer out of paper", null) }

        printTxt()

        assertEquals(listOf<Any?>("error:ERRO_SEM_PAPEL:Impressora sem papel, verifique!"), result.replies)
    }

    @Test
    fun `LinkageError na impressao responde ERRO_DESCONHECIDO sem derrubar o app`() {
        // Biblioteca que o SDK usa sem trazer, fora do APK: o runBlocking das coroutines, por exemplo.
        printer.onPrint = { throw NoClassDefFoundError("kotlinx/coroutines/BuildersKt") }

        printTxt()

        assertEquals(listOf<Any?>("error:ERRO_DESCONHECIDO:Erro na impressão"), result.replies)
    }

    @Test
    fun `SDK que nao abre responde IMPRESSORA_INDISPONIVEL e tenta abrir de novo na proxima impressao`() {
        var attempts = 0
        val withoutSdk = RedePrinterHandler {
            attempts++
            throw IllegalStateException("SDK da Rede indisponível neste aparelho")
        }
        val next = RecordingResult()

        printTxt(withoutSdk)
        printTxt(withoutSdk, next)

        val unavailable = listOf<Any?>("error:IMPRESSORA_INDISPONIVEL:Módulo de impressão não inicializado")
        assertEquals(unavailable, result.replies)
        assertEquals(unavailable, next.replies)
        assertEquals(2, attempts)
    }

    @Test
    fun `a impressora e aberta uma vez so e o callback registrado nela`() {
        printTxt()
        printTxt(result = RecordingResult())

        assertEquals(1, opened)
        assertEquals(1, printer.callbackRegistrations)
        assertEquals(2, printer.printed.size)
    }

    @Test
    fun `o erro de uma impressao nao passa para a seguinte`() {
        val next = RecordingResult()
        printer.onPrint = { it!!.onError("Printer out of paper") }
        printTxt()

        printer.onPrint = {}
        printTxt(result = next)

        assertEquals(printed, next.replies)
    }

    @Test
    fun `bytes que nao formam imagem respondem ERRO_DESCONHECIDO sem imprimir`() {
        handler.handle(MethodCall("print_receipt", mapOf("bitmap" to byteArrayOf(1, 2, 3))), result)

        assertEquals(listOf<Any?>("error:ERRO_DESCONHECIDO:Erro na impressão"), result.replies)
        assertTrue(printer.printed.isEmpty())
    }

    @Test
    fun `sem bitmap ou text responde o erro do plugin sem abrir a impressora`() {
        val withoutText = RecordingResult()

        handler.handle(MethodCall("print_receipt", emptyMap<String, Any?>()), result)
        handler.handle(MethodCall("print_txt", emptyMap<String, Any?>()), withoutText)

        assertEquals(listOf<Any?>("error:bitmap:bitmap is null"), result.replies)
        assertEquals(listOf<Any?>("error:text:text is null"), withoutText.replies)
        assertEquals(0, opened)
    }
}
