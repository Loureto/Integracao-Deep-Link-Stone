
package com.example.example

import android.app.Activity
import android.content.Intent
import com.example.example.printer.GenericPrinterHandler
import com.example.example.printer.PosmpPrinter
import com.example.example.vero.VeroPaymentHandler
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal fun createAcquirerIntegration(): AcquirerIntegration = VeroIntegration()

/**
 * Pagamento pelo app da Vero e impressão pelo driver genérico (posmpapi), nos canais `vero_flutter` e
 * `acquirers_sdk` do flutter_acquirers_sdk. O resultado do pagamento volta em [onActivityResult].
 */
internal class VeroIntegration : AcquirerIntegration {

    private lateinit var paymentHandler: VeroPaymentHandler

    override fun configure(activity: Activity, messenger: BinaryMessenger) {
        paymentHandler = VeroPaymentHandler(activity)
        MethodChannel(messenger, VeroPaymentHandler.CHANNEL).setMethodCallHandler(paymentHandler::handle)

        // A impressora só é criada a cada chamada: o posmpapi procura o serviço do fabricante.
        val printerHandler = GenericPrinterHandler { PosmpPrinter(activity.applicationContext) }
        MethodChannel(messenger, GenericPrinterHandler.CHANNEL).setMethodCallHandler(printerHandler::handle)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) =
        paymentHandler.onActivityResult(requestCode, resultCode, data)
}
