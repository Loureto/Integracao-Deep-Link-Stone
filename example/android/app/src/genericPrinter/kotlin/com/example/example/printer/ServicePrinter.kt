
package com.example.example.printer

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Impressão pelo driver genérico, com os nomes e o comportamento do `ServicePrinter` do centralizer: abre a
 * impressora ao ser criado, desenha o texto num bitmap de 80 mm ([textToBitmap]) e responde ao Dart quando a
 * impressão termina.
 */
internal class ServicePrinter(
    private val printer: PosPrinter,
    private val result: MethodChannel.Result
) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val replied = AtomicBoolean(false)

    init {
        printer.open()
    }

    fun printReceipt(byteArray: ByteArray) {
        val bitmap = BitmapFactory.decodeByteArray(byteArray, 0, byteArray.size)
        if (bitmap == null) {
            reply { result.error(UNKNOWN_ERROR, PRINTING_ERROR, "Os bytes recebidos não formam uma imagem.") }
            printer.close()
            return
        }

        printBitmap(bitmap)
    }

    fun testPrint() = printBitmap(textToBitmap(TEST_PRINT_TEXT))

    fun printTxtReceipt(text: String) = printBitmap(textToBitmap(text))

    private fun printBitmap(bitmap: Bitmap) {
        try {
            printer.print(bitmap, object : PosPrinterListener {
                override fun onFinish() = reply { result.success(SUCCESS) }

                override fun onError(outOfPaper: Boolean) = reply {
                    if (outOfPaper) {
                        result.error(OUT_OF_PAPER, OUT_OF_PAPER_MESSAGE, null)
                    } else {
                        result.error(UNKNOWN_ERROR, PRINTING_ERROR, null)
                    }
                }
            })
        } catch (exception: Exception) {
            Log.e(TAG, "Erro ao imprimir.", exception)
            reply { result.error(UNKNOWN_ERROR, PRINTING_ERROR, exception.toString()) }
        } finally {
            // Como no centralizer, a impressora fecha logo depois de receber o bitmap. Aqui também quando o print
            // falha, para o driver não ficar aberto.
            printer.close()
        }
    }

    /**
     * Responde ao Dart uma vez só, na main thread, como o Flutter pede. O listener do posmpapi chega por outra thread
     * e, na Sunmi, com trabalhos sobrepostos, pode chegar duas vezes; a segunda resposta derrubaria o app.
     */
    private fun reply(block: () -> Unit) {
        if (!replied.compareAndSet(false, true)) return
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post(block)
    }

    companion object {
        private const val TAG = "ServicePrinter"

        private const val SUCCESS = "Sucesso ao efetuar a impressão"
        internal const val UNKNOWN_ERROR = "ERRO_DESCONHECIDO"
        internal const val PRINTING_ERROR = "Erro na impressão"
        private const val OUT_OF_PAPER = "ERRO_SEM_PAPEL"
        private const val OUT_OF_PAPER_MESSAGE = "Impressora sem papel, verifique!"
    }
}
