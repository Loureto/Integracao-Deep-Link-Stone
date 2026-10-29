
package com.example.example.pagbank

import android.content.Context
import android.content.pm.PackageManager
import br.com.uol.pagseguro.plugpagservice.wrapper.IPlugPagWrapper
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPag
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagAbortResult
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagEventData
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagEventListener
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagPaymentData
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagPrintResult
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagPrinterData
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagTransactionResult
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagVoidData

/**
 * Operações do PlugPagService usadas pela integração, separadas do wrapper para os testes rodarem sem
 * terminal. Todas, menos [setEventListener], bloqueiam até o serviço responder e não podem rodar na main
 * thread: a resposta do serviço chega por ela, e a chamada ficaria esperando até o timeout.
 */
internal interface PagBankTerminal {
    fun isAuthenticated(): Boolean
    fun isServiceBusy(): Boolean

    /** Mensagens do serviço durante pagamento e estorno, entregues na main thread. */
    fun setEventListener(listener: (PlugPagEventData) -> Unit)

    fun doPayment(data: PlugPagPaymentData): PlugPagTransactionResult
    fun voidPayment(data: PlugPagVoidData): PlugPagTransactionResult
    fun abort(): PlugPagAbortResult
    fun getLastApprovedTransaction(): PlugPagTransactionResult
    fun reprintCustomerReceipt(): PlugPagPrintResult
    fun reprintEstablishmentReceipt(): PlugPagPrintResult

    /** Impressão livre do arquivo em [PlugPagPrinterData.filePath], lido pelo serviço do PagBank. */
    fun printFromFile(data: PlugPagPrinterData): PlugPagPrintResult
}

/** Erro da integração enviado ao Dart com [code]. */
internal class PagBankException(val code: String, message: String) : Exception(message) {

    companion object {
        const val INVALID_ARGUMENT = "INVALID_ARGUMENT"
        const val TERMINAL_UNAVAILABLE = "TERMINAL_UNAVAILABLE"
        const val NOT_AUTHENTICATED = "NOT_AUTHENTICATED"
        const val SERVICE_BUSY = "SERVICE_BUSY"
        const val STORAGE_UNAVAILABLE = "STORAGE_UNAVAILABLE"
    }
}

/** [PagBankTerminal] pelo PlugPagServiceWrapper. */
internal class PlugPagTerminal private constructor(private val plugPag: IPlugPagWrapper) : PagBankTerminal {

    override fun isAuthenticated() = plugPag.isAuthenticated()

    override fun isServiceBusy() = plugPag.isServiceBusy()

    override fun setEventListener(listener: (PlugPagEventData) -> Unit) {
        plugPag.setEventListener(object : PlugPagEventListener {
            override fun onEvent(data: PlugPagEventData) = listener(data)
        })
    }

    override fun doPayment(data: PlugPagPaymentData) = plugPag.doPayment(data)

    override fun voidPayment(data: PlugPagVoidData) = plugPag.voidPayment(data)

    override fun abort() = plugPag.abort()

    override fun getLastApprovedTransaction() = plugPag.getLastApprovedTransaction()

    override fun reprintCustomerReceipt() = plugPag.reprintCustomerReceipt()

    override fun reprintEstablishmentReceipt() = plugPag.reprintStablishmentReceipt()

    override fun printFromFile(data: PlugPagPrinterData) = plugPag.printFromFile(data)

    companion object {
        private const val SERVICE_PACKAGE = "br.com.uol.pagseguro.plugpagservice"

        @Volatile
        private var instance: PlugPagTerminal? = null

        /**
         * Um PlugPag por processo, como pede o demo oficial, criado na primeira operação e não na abertura do
         * app: o construtor registra um receiver sem flag de export, o que lança SecurityException no
         * Android 14+ (os terminais vão até o Android 11).
         */
        fun get(context: Context): PagBankTerminal {
            instance?.let { return it }

            synchronized(this) {
                instance?.let { return it }
                requireService(context)

                return try {
                    PlugPagTerminal(PlugPag(context.applicationContext)).also { instance = it }
                } catch (exception: SecurityException) {
                    throw PagBankException(
                        PagBankException.TERMINAL_UNAVAILABLE,
                        "O PlugPagServiceWrapper não roda neste Android: use um terminal Smart do PagBank."
                    )
                }
            }
        }

        private fun requireService(context: Context) {
            try {
                context.packageManager.getPackageInfo(SERVICE_PACKAGE, 0)
            } catch (exception: PackageManager.NameNotFoundException) {
                throw PagBankException(
                    PagBankException.TERMINAL_UNAVAILABLE,
                    "PlugPagService não encontrado: rode o app num terminal Smart do PagBank."
                )
            }
        }
    }
}
