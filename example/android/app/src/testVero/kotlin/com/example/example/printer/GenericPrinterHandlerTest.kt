package com.example.example.printer

import android.graphics.Bitmap
import io.flutter.plugin.common.MethodCall
import java.io.ByteArrayOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class GenericPrinterHandlerTest {

    private val printers = mutableListOf<FakePosPrinter>()
    private val handler = GenericPrinterHandler { FakePosPrinter().also { printers += it } }

    @Test
    fun `printTxt printReceipt e testPrint chegam ao ServicePrinter, com uma impressora por chamada`() {
        val png = ByteArrayOutputStream().also {
            Bitmap.createBitmap(4, 2, Bitmap.Config.ARGB_8888).compress(Bitmap.CompressFormat.PNG, 100, it)
        }.toByteArray()

        listOf(
            MethodCall("printTxt", mapOf("text" to "LINHA")),
            MethodCall("printReceipt", mapOf("bitmap" to png)),
            MethodCall("testPrint", null)
        ).forEach { call ->
            val result = RecordingResult()

            handler.handle(call, result)
            printers.last().listener!!.onFinish()

            assertEquals(call.method, listOf("success:Sucesso ao efetuar a impressão"), result.replies)
        }
        assertEquals(3, printers.size)
    }

    @Test
    fun `sem argumento responde os codigos do plugin`() {
        val withoutBitmap = RecordingResult()
        val withoutText = RecordingResult()

        handler.handle(MethodCall("printReceipt", emptyMap<String, Any?>()), withoutBitmap)
        handler.handle(MethodCall("printTxt", emptyMap<String, Any?>()), withoutText)

        assertEquals(listOf("error:bitmap:bitmap is null"), withoutBitmap.replies)
        assertEquals(listOf("error:text:text is null"), withoutText.replies)
        assertTrue(printers.isEmpty())
    }

    @Test
    fun `falha do driver ao criar a impressora responde erro de impressao, sem derrubar o app`() {
        listOf<() -> PosPrinter>(
            // Biblioteca do fabricante fora do APK, como a da Sunmi no P2: o Printer.getInstance lança um Error.
            { throw NoClassDefFoundError("com/sunmi/peripheral/printer/InnerResultCallback") },
            // Modelo que o posmpapi não conhece: o Printer.getInstance devolve null e o open lança.
            { object : PosPrinter by FakePosPrinter() { override fun open(): Unit = throw NullPointerException() } }
        ).forEach { factory ->
            val result = RecordingResult()

            GenericPrinterHandler(factory).handle(MethodCall("printTxt", mapOf("text" to "LINHA")), result)

            assertEquals(listOf("error:ERRO_DESCONHECIDO:Erro na impressão"), result.replies)
        }
    }

    @Test
    fun `metodo desconhecido responde notImplemented`() {
        val result = RecordingResult()

        handler.handle(MethodCall("print_receipt", null), result)

        assertEquals(listOf("notImplemented"), result.replies)
    }
}
