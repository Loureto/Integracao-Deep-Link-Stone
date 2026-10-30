package com.example.example

import android.app.Activity
import android.content.Context
import android.os.Build
import android.util.Log
import com.example.example.printer.GenericPrinterHandler
import com.example.example.printer.PosPrinter
import com.example.example.printer.PosmpPrinter
import com.example.example.sipag.Apix990Sdk
import com.example.example.sipag.DxSdk
import com.example.example.sipag.DxTerminal
import com.example.example.sipag.P2Sdk
import com.example.example.sipag.P2Terminal
import com.example.example.sipag.PendingOperationStore
import com.example.example.sipag.Pos7ApiSdk
import com.example.example.sipag.SipagPaymentHandler
import com.example.example.sipag.isP2
import com.example.example.sipag.operationResultFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

internal fun createAcquirerIntegration(): AcquirerIntegration = SipagIntegration()

/**
 * Pagamento pela Sipag e impressão pelo driver genérico (posmpapi), nos canais `sipag_sdk` e `acquirers_sdk`
 * do flutter_acquirers_sdk. O terminal sai do [model]: o P2 pelo app da Ger7, o DX8000 e a X990 pelo app
 * Sicoob. Nenhum dos dois usa o `onActivityResult`: o DX lê um arquivo, e o P2 recebe pela activity do AAR.
 */
internal class SipagIntegration(
    private val model: String = Build.MODEL,
    private val dxSdk: DxSdk = Apix990Sdk,
    private val p2Sdk: P2Sdk = Pos7ApiSdk,
    private val lastOperationFile: () -> File = ::operationResultFile,
    private val openPrinter: (Context) -> PosPrinter = ::PosmpPrinter
) : AcquirerIntegration {

    override fun configure(activity: Activity, messenger: BinaryMessenger) {
        val terminal = when {
            isP2(model) -> P2Terminal(activity.applicationContext, p2Sdk)
            else -> DxTerminal(activity, dxSdk)
        }
        val paymentHandler = SipagPaymentHandler(
            terminal,
            PendingOperationStore(activity.applicationContext),
            lastOperationFile
        )
        MethodChannel(messenger, SipagPaymentHandler.CHANNEL).setMethodCallHandler(paymentHandler::handle)

        val printer = SharedPrinter { openPrinter(activity.applicationContext) }
        printer.openEarly()
        val printerHandler = GenericPrinterHandler(printer::get)
        MethodChannel(messenger, GenericPrinterHandler.CHANNEL).setMethodCallHandler(printerHandler::handle)
    }
}

/**
 * A impressora do driver genérico, aberta uma vez e reaproveitada. Na X990, o `Printer.getInstance` do
 * posmpapi cria uma impressora nova a cada chamada, e ela só liga ao serviço da Verifone depois, de forma
 * assíncrona; criada na hora de imprimir, ela imprimia desligada e lançava `NullPointerException`, e a nova
 * tentativa criava outra desligada. No P2 e no DX8000, o posmpapi já reaproveita a instância. O `open` e o
 * `close` não fazem nada nos três modelos.
 */
private class SharedPrinter(private val open: () -> PosPrinter) {

    private var printer: PosPrinter? = null

    /** Abre já ao configurar, para o serviço do fabricante ligar antes da primeira impressão. */
    fun openEarly() {
        try {
            get()
        } catch (error: LinkageError) {
            Log.e(TAG, "A impressora não abriu; a próxima impressão tenta de novo.", error)
        } catch (exception: RuntimeException) {
            Log.e(TAG, "A impressora não abriu; a próxima impressão tenta de novo.", exception)
        }
    }

    /** A impressora aberta; se ainda não abriu, abre agora, e a falha vai para quem imprime. */
    fun get(): PosPrinter = printer ?: open().also { printer = it }

    private companion object {
        const val TAG = "SipagPrinter"
    }
}
