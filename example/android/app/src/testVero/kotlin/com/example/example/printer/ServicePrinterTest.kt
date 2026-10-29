package com.example.example.printer

import android.graphics.Bitmap
import android.os.Looper
import java.io.ByteArrayOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * O Robolectric só desenha e decodifica imagens de verdade (modo NATIVE) a partir da API 26, então este teste
 * roda só na API 30 do robolectric.properties. Na API 25, o BitmapFactory falso devolve um bitmap até para bytes
 * inválidos, e a fonte não tem métricas; num terminal com API 25 isso funciona normalmente.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [30])
class ServicePrinterTest {

    private val printer = FakePosPrinter()
    private val result = RecordingResult()

    @Test
    fun `printTxtReceipt desenha o texto em 576 px e responde sucesso no onFinish`() {
        ServicePrinter(printer, result).printTxtReceipt("LINHA 1\nLINHA 2\nLINHA 3")

        val bitmap = printer.bitmap!!
        assertEquals(576, bitmap.width)
        assertTrue(bitmap.height > textToBitmap("LINHA 1").height)
        assertEquals(emptyList<String>(), result.replies)

        printer.listener!!.onFinish()

        assertEquals(listOf("success:Sucesso ao efetuar a impressão"), result.replies)
    }

    @Test
    fun `abre a impressora ao criar e fecha depois de mandar imprimir`() {
        ServicePrinter(printer, result).testPrint()

        assertEquals(listOf("open", "print", "close"), printer.log)
    }

    @Test
    fun `onError sem papel responde ERRO_SEM_PAPEL`() {
        ServicePrinter(printer, result).printTxtReceipt("X")

        printer.listener!!.onError(outOfPaper = true)

        assertEquals(listOf("error:ERRO_SEM_PAPEL:Impressora sem papel, verifique!"), result.replies)
    }

    @Test
    fun `onError com outro codigo responde ERRO_DESCONHECIDO`() {
        ServicePrinter(printer, result).printTxtReceipt("X")

        printer.listener!!.onError(outOfPaper = false)

        assertEquals(listOf("error:ERRO_DESCONHECIDO:Erro na impressão"), result.replies)
    }

    @Test
    fun `responde uma unica vez, mesmo que o driver chame o listener de novo`() {
        // Na Sunmi, o posmpapi guarda o listener num campo do singleton, e um trabalho sobreposto recebe dois retornos.
        ServicePrinter(printer, result).printTxtReceipt("X")

        printer.listener!!.onFinish()
        printer.listener!!.onError(outOfPaper = true)

        assertEquals(listOf("success:Sucesso ao efetuar a impressão"), result.replies)
    }

    @Test
    fun `retorno de outra thread responde pela main thread`() {
        // As impressoras do posmpapi chamam o listener de uma thread própria.
        ServicePrinter(printer, result).printTxtReceipt("X")

        Thread { printer.listener!!.onFinish() }.apply {
            start()
            join()
        }

        assertEquals(emptyList<String>(), result.replies)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf("success:Sucesso ao efetuar a impressão"), result.replies)
    }

    @Test
    fun `excecao da impressora responde ERRO_DESCONHECIDO e fecha a impressora`() {
        val failing = FakePosPrinter(failure = RuntimeException("serviço de impressão indisponível"))

        ServicePrinter(failing, result).printTxtReceipt("X")

        assertEquals(listOf("error:ERRO_DESCONHECIDO:Erro na impressão"), result.replies)
        assertEquals(listOf("open", "print", "close"), failing.log)
    }

    @Test
    fun `printReceipt decodifica os bytes e imprime o bitmap`() {
        val png = ByteArrayOutputStream().also {
            Bitmap.createBitmap(10, 4, Bitmap.Config.ARGB_8888).compress(Bitmap.CompressFormat.PNG, 100, it)
        }.toByteArray()

        ServicePrinter(printer, result).printReceipt(png)

        assertEquals(listOf(10, 4), listOf(printer.bitmap!!.width, printer.bitmap!!.height))
    }

    @Test
    fun `printReceipt com bytes que nao sao imagem responde ERRO_DESCONHECIDO sem imprimir`() {
        ServicePrinter(printer, result).printReceipt(byteArrayOf(1, 2, 3))

        assertEquals(listOf("error:ERRO_DESCONHECIDO:Erro na impressão"), result.replies)
        assertNull(printer.bitmap)
    }

    @Test
    fun `testPrint imprime Impressao teste`() {
        ServicePrinter(printer, result).testPrint()

        assertTrue(printer.bitmap!!.sameAs(textToBitmap(TEST_PRINT_TEXT)))
    }
}
