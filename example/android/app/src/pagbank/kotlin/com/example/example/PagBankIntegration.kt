
package com.example.example

import android.app.Activity
import android.os.Handler
import android.os.Looper
import com.example.example.pagbank.PagBankRequestHandler
import com.example.example.pagbank.PlugPagTerminal
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor
import java.util.concurrent.Executors

internal fun createAcquirerIntegration(): AcquirerIntegration = PagBankIntegration()

/** Operações no terminal pelo PlugPagServiceWrapper: o resultado volta na resposta do canal, sem deep link. */
internal class PagBankIntegration : AcquirerIntegration {

    override fun configure(activity: Activity, messenger: BinaryMessenger) {
        val context = activity.applicationContext
        val channel = MethodChannel(messenger, CHANNEL)
        val handler = PagBankRequestHandler(
            terminal = { PlugPagTerminal.get(context) },
            operations = operations,
            aborts = aborts,
            mainThread = mainThread,
            onEvent = { event -> channel.invokeMethod(METHOD_ON_EVENT, event) }
        )

        channel.setMethodCallHandler(handler::handle)
    }

    companion object {
        private const val CHANNEL = "pagbankChannel"
        private const val METHOD_ON_EVENT = "onPagBankEvent"

        // Do processo, como o PlugPag: uma Activity recriada continua na mesma fila de operações.
        private val operations: Executor = Executors.newSingleThreadExecutor()
        private val aborts: Executor = Executors.newSingleThreadExecutor()
        private val mainHandler = Handler(Looper.getMainLooper())
        private val mainThread = Executor { mainHandler.post(it) }
    }
}
