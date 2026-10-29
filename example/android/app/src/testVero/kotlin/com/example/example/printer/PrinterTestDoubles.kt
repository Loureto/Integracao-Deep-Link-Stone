package com.example.example.printer

import android.graphics.Bitmap
import io.flutter.plugin.common.MethodChannel

/** [PosPrinter] que guarda o bitmap e o listener da impressão e registra a ordem das chamadas. */
internal class FakePosPrinter(private val failure: RuntimeException? = null) : PosPrinter {
    val log = mutableListOf<String>()
    var bitmap: Bitmap? = null
    var listener: PosPrinterListener? = null

    override fun open() {
        log += "open"
    }

    override fun print(bitmap: Bitmap, listener: PosPrinterListener) {
        log += "print"
        failure?.let { throw it }
        this.bitmap = bitmap
        this.listener = listener
    }

    override fun close() {
        log += "close"
    }
}

/** Respostas ao Dart, com código e mensagem dos erros. */
internal class RecordingResult : MethodChannel.Result {
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
