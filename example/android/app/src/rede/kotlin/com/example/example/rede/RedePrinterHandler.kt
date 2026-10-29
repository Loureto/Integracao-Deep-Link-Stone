package com.example.example.rede

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import com.example.example.printer.TEST_PRINT_TEXT
import com.example.example.printer.textToBitmap
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import rede.smartrede.commons.callback.IPrinterCallback
import rede.smartrede.commons.contract.IConnectorPrinter

/**
 * Impressão pela impressora do SDK da Rede (L400), com os métodos, códigos e mensagens do plugin
 * `flutter_rede_sdk`. O SDK segura o `printBitmap` enquanto confere a impressora (pronta, com papel) e
 * entrega o bitmap ao serviço de impressão; os erros dessas checagens chegam pelo callback durante a chamada.
 * Um erro que o serviço avise depois, por outra thread, já não tem a quem responder e só vai para o log.
 */
internal class RedePrinterHandler(private val openPrinter: () -> IConnectorPrinter) {

    /**
     * Impressora do SDK, aberta pelo [prepare] ou na primeira impressão. No plugin, ela era aberta em toda
     * chamada, até nos pagamentos, e num aparelho sem o SDK até o pagamento falhava.
     */
    private var printer: IConnectorPrinter? = null

    /** Se há um `printBitmap` em andamento: só nessa janela o erro do callback tem a quem responder. */
    @Volatile
    private var printing = false

    /** Primeiro erro que o SDK avisou durante a impressão em andamento. */
    @Volatile
    private var printError: String? = null

    private val callback = object : IPrinterCallback {
        override fun onCompleted() = Unit

        override fun onError(error: String) {
            if (!printing) {
                Log.w(TAG, "Erro da impressora fora de uma impressão: $error")
                return
            }
            if (printError == null) printError = error
            // Como o plugin, interrompe o SDK aqui. Se o callback só guardasse o erro, o SDK seguiria para a
            // nova tentativa atrasada dele: imprimiria de novo um segundo depois, ou derrubaria o app na
            // terceira vez.
            throw PrintAborted(error)
        }
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            PRINT_RECEIPT -> {
                val bytes = call.argument<ByteArray>(BITMAP)
                if (bytes == null) {
                    result.error(BITMAP, "bitmap is null", null)
                    return
                }
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (bitmap == null) {
                    result.error(UNKNOWN_ERROR, PRINTING_ERROR, "Os bytes recebidos não formam uma imagem.")
                    return
                }
                print(bitmap, result)
            }

            PRINT_TXT -> {
                val text = call.argument<String>(TEXT)
                if (text == null) {
                    result.error(TEXT, "text is null", null)
                    return
                }
                print(textToBitmap(text), result)
            }

            TEST_PRINT -> print(textToBitmap(TEST_PRINT_TEXT), result)

            else -> result.notImplemented()
        }
    }

    /**
     * Abre a impressora antes da primeira impressão. Uma falha aqui só vai para o log: a impressão tenta de
     * novo.
     */
    fun prepare() {
        try {
            openedPrinter()
        } catch (exception: RuntimeException) {
            Log.w(TAG, "SDK da impressora da Rede indisponível.", exception)
        } catch (error: LinkageError) {
            Log.e(TAG, "Biblioteca do SDK da Rede ausente.", error)
        }
    }

    private fun openedPrinter(): IConnectorPrinter = printer ?: openPrinter().also {
        it.setPrinterCallback(callback)
        printer = it
    }

    private fun print(bitmap: Bitmap, result: MethodChannel.Result) {
        val printer = try {
            openedPrinter()
        } catch (exception: RuntimeException) {
            // Fora do L400, o SDK não abre; a próxima impressão tenta de novo.
            Log.e(TAG, "SDK da impressora da Rede indisponível.", exception)
            result.error(PRINTER_UNAVAILABLE, PRINTER_UNAVAILABLE_MESSAGE, exception.toString())
            return
        } catch (error: LinkageError) {
            replyFailure(error, result)
            return
        }

        printError = null
        printing = true
        try {
            printer.printBitmap(bitmap)
        } catch (aborted: PrintAborted) {
            // O erro já ficou em printError, no callback.
        } catch (exception: Exception) {
            // PrinterException e InvalidSdkStateException trazem as mesmas mensagens do callback; o primeiro
            // erro avisado vale mais que a exceção em que o SDK o embrulhou.
            if (printError == null) printError = exception.message.orEmpty()
        } catch (error: LinkageError) {
            replyFailure(error, result)
            return
        } finally {
            printing = false
        }

        val error = printError
        if (error == null) result.success(SUCCESS) else replyError(error, result)
    }

    private fun replyError(message: String, result: MethodChannel.Result) {
        when (message) {
            in OUT_OF_PAPER_MESSAGES -> result.error(OUT_OF_PAPER, OUT_OF_PAPER_MESSAGE, message)
            in UNAVAILABLE_MESSAGES -> result.error(PRINTER_UNAVAILABLE, PRINTER_UNAVAILABLE_MESSAGE, message)
            else -> result.error(UNKNOWN_ERROR, PRINTING_ERROR, message)
        }
    }

    /**
     * Biblioteca que o SDK usa fora do APK (`NoClassDefFoundError`) vira erro de impressão: o Error
     * derrubaria o app, como aconteceu com a biblioteca da Sunmi na Vero.
     */
    private fun replyFailure(error: LinkageError, result: MethodChannel.Result) {
        Log.e(TAG, "Biblioteca do SDK da Rede ausente.", error)
        result.error(UNKNOWN_ERROR, PRINTING_ERROR, error.toString())
    }

    /** Interrompe o SDK no callback de erro, como a `RedePrinterException` do plugin. */
    private class PrintAborted(message: String) : RuntimeException(message)

    companion object {
        private const val TAG = "RedePrinterHandler"

        private const val PRINT_RECEIPT = "print_receipt"
        private const val PRINT_TXT = "print_txt"
        private const val TEST_PRINT = "test_print"
        private const val BITMAP = "bitmap"
        private const val TEXT = "text"

        /** Métodos do canal `rede_sdk` que este handler atende. */
        val METHODS = setOf(PRINT_RECEIPT, PRINT_TXT, TEST_PRINT)

        private const val SUCCESS = "Sucesso ao efetuar a impressão"
        private const val UNKNOWN_ERROR = "ERRO_DESCONHECIDO"
        private const val PRINTING_ERROR = "Erro na impressão"
        private const val OUT_OF_PAPER = "ERRO_SEM_PAPEL"
        private const val OUT_OF_PAPER_MESSAGE = "Impressora sem papel, verifique!"
        private const val PRINTER_UNAVAILABLE = "IMPRESSORA_INDISPONIVEL"
        private const val PRINTER_UNAVAILABLE_MESSAGE = "Módulo de impressão não inicializado"

        /** Mensagens do SDK e do plugin para falta de papel. */
        private val OUT_OF_PAPER_MESSAGES = setOf("Printer out of paper", OUT_OF_PAPER_MESSAGE)

        /**
         * Mensagens de impressora que não ficou pronta: "Init failed" vem do módulo da Positivo, e "Printer
         * not ready", do SDK da Rede depois das tentativas dele. No plugin, só a primeira tinha esse código.
         */
        private val UNAVAILABLE_MESSAGES =
            setOf("Init failed", "Printer not ready", PRINTER_UNAVAILABLE_MESSAGE)
    }
}
