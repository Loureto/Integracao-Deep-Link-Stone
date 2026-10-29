
package com.example.example.printer

import android.content.Context
import android.graphics.Bitmap
import br.com.execucao.posmp_api.printer.Printer
import br.com.execucao.posmp_api.printer.PrinterListener

/**
 * Impressora do terminal pelo driver genérico, separada do posmpapi para os testes rodarem sem terminal: o
 * `Printer.getInstance` procura o serviço de impressão do fabricante.
 */
internal interface PosPrinter {
    fun open()
    fun print(bitmap: Bitmap, listener: PosPrinterListener)
    fun close()
}

/** Resultado de uma impressão, que o serviço do fabricante entrega depois de imprimir. */
internal interface PosPrinterListener {
    fun onFinish()
    fun onError(outOfPaper: Boolean)
}

/** [PosPrinter] pelo posmpapi da Execução, o mesmo driver do centralizer. */
internal class PosmpPrinter(context: Context) : PosPrinter {

    private val printer = Printer.getInstance(context)

    override fun open() = printer.open()

    override fun print(bitmap: Bitmap, listener: PosPrinterListener) {
        printer.print(bitmap, object : PrinterListener.Stub() {
            override fun onFinish() = listener.onFinish()

            override fun onError(error: Int) = listener.onError(outOfPaper = error == Printer.ERRO_SEM_PAPEL)
        })
    }

    override fun close() = printer.close()
}
