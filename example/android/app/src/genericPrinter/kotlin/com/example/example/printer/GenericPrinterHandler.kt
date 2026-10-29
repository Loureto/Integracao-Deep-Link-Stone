
package com.example.example.printer

import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Canal do driver genérico, com os métodos e argumentos do plugin do centralizer. Cada chamada cria a sua
 * impressora, como lá.
 */
internal class GenericPrinterHandler(private val printerFactory: () -> PosPrinter) {

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            PRINT_RECEIPT -> {
                val bitmap = call.argument<ByteArray>(BITMAP)
                if (bitmap == null) {
                    result.error(BITMAP, "bitmap is null", null)
                    return
                }
                withPrinter(result) { printReceipt(bitmap) }
            }

            PRINT_TXT -> {
                val text = call.argument<String>(TEXT)
                if (text == null) {
                    result.error(TEXT, "text is null", null)
                    return
                }
                withPrinter(result) { printTxtReceipt(text) }
            }

            TEST_PRINT -> withPrinter(result) { testPrint() }

            else -> result.notImplemented()
        }
    }

    /**
     * Cria a impressora e imprime. Uma biblioteca do fabricante fora do APK (`NoClassDefFoundError`) ou um modelo que
     * o posmpapi não conhece viram erro de impressão: o Error derrubaria o app, e a primeira impressão é o comprovante
     * de um pagamento já aprovado.
     */
    private fun withPrinter(result: MethodChannel.Result, print: ServicePrinter.() -> Unit) {
        try {
            ServicePrinter(printerFactory(), result).print()
        } catch (error: LinkageError) {
            replyFailure(result, error)
        } catch (exception: RuntimeException) {
            replyFailure(result, exception)
        }
    }

    private fun replyFailure(result: MethodChannel.Result, cause: Throwable) {
        Log.e(TAG, "Erro no driver de impressão.", cause)
        result.error(ServicePrinter.UNKNOWN_ERROR, ServicePrinter.PRINTING_ERROR, cause.toString())
    }

    companion object {
        const val CHANNEL = "acquirers_sdk"

        private const val TAG = "GenericPrinterHandler"

        private const val PRINT_RECEIPT = "printReceipt"
        private const val PRINT_TXT = "printTxt"
        private const val TEST_PRINT = "testPrint"
        private const val BITMAP = "bitmap"
        private const val TEXT = "text"
    }
}
