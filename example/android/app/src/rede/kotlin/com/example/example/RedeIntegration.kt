package com.example.example

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.example.example.rede.ProcessPrinter
import com.example.example.rede.RedePaymentApp
import com.example.example.rede.RedePaymentHandler
import com.example.example.rede.RedePrinterHandler
import com.example.example.rede.SmartRedePaymentApp
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import rede.smartrede.commons.contract.IConnectorPrinter
import rede.smartrede.sdk.api.IRedeSdk

internal fun createAcquirerIntegration(): AcquirerIntegration = RedeIntegration()

/** Impressora do SDK da Rede no L400, uma por processo. */
private val smartRedePrinter = ProcessPrinter {
    IRedeSdk.newInstance(it).getTerminalFunctions().getConnectorPrinter()
}

/**
 * Pagamento e impressão pelo SDK da Rede (L400), no canal `rede_sdk` do plugin flutter_rede_sdk. O resultado
 * do pagamento volta em [onActivityResult]. O app e a impressora entram pelo construtor para os testes.
 */
internal class RedeIntegration(
    private val paymentApp: (Context) -> RedePaymentApp = ::SmartRedePaymentApp,
    private val openPrinter: (Context) -> IConnectorPrinter = smartRedePrinter::get
) : AcquirerIntegration {

    private lateinit var paymentHandler: RedePaymentHandler

    override fun configure(activity: Activity, messenger: BinaryMessenger) {
        val context = activity.applicationContext
        paymentHandler = RedePaymentHandler(activity, paymentApp(context))
        val printerHandler = RedePrinterHandler { openPrinter(context) }
        // O SDK liga o serviço de impressão de forma assíncrona: aberto já aqui, ele está pronto na primeira
        // impressão. Se não abrir, só a impressão responde erro; o pagamento segue.
        printerHandler.prepare()

        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                in RedePaymentHandler.METHODS -> paymentHandler.handle(call, result)
                in RedePrinterHandler.METHODS -> printerHandler.handle(call, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) =
        paymentHandler.onActivityResult(requestCode, resultCode, data)

    private companion object {
        const val CHANNEL = "rede_sdk"
    }
}
