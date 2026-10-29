
package com.example.example.pagbank

import android.util.Log
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagEventData
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagPrinterData
import br.com.uol.pagseguro.plugpagservice.wrapper.exception.PlugPagException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executor

/**
 * Atende o canal do PagBank. As operações bloqueiam até o terminal responder, então rodam em [operations],
 * uma de cada vez, porque o PlugPagService recusa operações em paralelo (SV03/PP1047). O abort roda em
 * [aborts], já que precisa passar na frente do pagamento que interrompe. As respostas e os eventos voltam
 * em [mainThread], a única em que o canal pode responder. A impressão livre grava a imagem em
 * [printDirectory], nulo quando a pasta está indisponível.
 */
internal class PagBankRequestHandler(
    private val terminal: () -> PagBankTerminal,
    private val operations: Executor,
    private val aborts: Executor,
    private val mainThread: Executor,
    private val printDirectory: () -> File?,
    private val onEvent: (Map<String, Any?>) -> Unit
) {

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_PAYMENT -> {
                val data = parse(result) { PagBankRequests.payment(call) } ?: return

                execute(operations, result) { terminal ->
                    terminal.requireReady()
                    terminal.setEventListener(::sendEvent)
                    terminal.doPayment(data).toMap()
                }
            }

            METHOD_VOID_PAYMENT -> {
                val data = parse(result) { PagBankRequests.void(call) } ?: return

                execute(operations, result) { terminal ->
                    terminal.requireReady()
                    terminal.setEventListener(::sendEvent)
                    terminal.voidPayment(data).toMap()
                }
            }

            METHOD_ABORT -> execute(aborts, result) { terminal -> terminal.abort().result }

            METHOD_LAST_APPROVED_TRANSACTION -> execute(operations, result) { terminal ->
                terminal.requireReady()
                terminal.getLastApprovedTransaction().toMap()
            }

            METHOD_REPRINT_CUSTOMER_RECEIPT -> execute(operations, result) { terminal ->
                terminal.requireReady()
                terminal.reprintCustomerReceipt().toMap()
            }

            METHOD_REPRINT_ESTABLISHMENT_RECEIPT -> execute(operations, result) { terminal ->
                terminal.requireReady()
                terminal.reprintEstablishmentReceipt().toMap()
            }

            METHOD_PRINT_IMAGE -> {
                val request = parse(result) { PagBankRequests.print(call) } ?: return

                execute(operations, result) { terminal ->
                    terminal.requireReady()
                    withPrintFile(request.image) { file ->
                        terminal.printFromFile(PlugPagPrinterData(file.absolutePath, request.quality, request.steps))
                            .toMap()
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    /** Responde INVALID_ARGUMENT e devolve nulo quando os argumentos não montam a operação. */
    private inline fun <T : Any> parse(result: MethodChannel.Result, build: () -> T): T? {
        return try {
            build()
        } catch (exception: IllegalArgumentException) {
            result.error(PagBankException.INVALID_ARGUMENT, exception.message, null)
            null
        } catch (exception: ClassCastException) {
            result.error(PagBankException.INVALID_ARGUMENT, "Tipo de argumento inválido.", null)
            null
        }
    }

    private fun execute(executor: Executor, result: MethodChannel.Result, operation: (PagBankTerminal) -> Any?) {
        executor.execute {
            val reply = try {
                Reply.Success(operation(terminal()))
            } catch (exception: PagBankException) {
                Reply.Error(exception.code, exception.message)
            } catch (exception: PlugPagException) {
                Log.e(TAG, "Erro do PlugPagService.", exception)
                Reply.Error(exception.errorCode?.takeIf { it.isNotBlank() } ?: PLUGPAG_ERROR, exception.message)
            } catch (exception: Exception) {
                Log.e(TAG, "Erro na operação do PagBank.", exception)
                Reply.Error(PAGBANK_ERROR, exception.message)
            }

            mainThread.execute { reply.send(result) }
        }
    }

    /**
     * O printFromFile envia só o caminho ao serviço do PagBank, que lê o arquivo em outro processo: por isso a
     * imagem vai para [printDirectory], e o arquivo é apagado depois da impressão, com ou sem sucesso.
     */
    private fun <T> withPrintFile(image: ByteArray, print: (File) -> T): T {
        val directory = printDirectory() ?: throw PagBankException(
            PagBankException.STORAGE_UNAVAILABLE,
            "Armazenamento indisponível para gravar a imagem da impressão."
        )
        val file = File.createTempFile(PRINT_FILE_PREFIX, PRINT_FILE_SUFFIX, directory)

        try {
            file.writeBytes(image)
            return print(file)
        } finally {
            file.delete()
        }
    }

    private fun sendEvent(event: PlugPagEventData) {
        val data = event.toMap()
        mainThread.execute { onEvent(data) }
    }

    /** Recomendações do demo oficial: só operar com o terminal ativado e sem outra operação em andamento. */
    private fun PagBankTerminal.requireReady() {
        if (!isAuthenticated()) {
            throw PagBankException(PagBankException.NOT_AUTHENTICATED, "O terminal não está ativado no PagBank.")
        }
        if (isServiceBusy()) {
            throw PagBankException(
                PagBankException.SERVICE_BUSY,
                "O PlugPagService está ocupado com outra operação: aguarde ela terminar."
            )
        }
    }

    private sealed interface Reply {
        fun send(result: MethodChannel.Result)

        class Success(private val value: Any?) : Reply {
            override fun send(result: MethodChannel.Result) = result.success(value)
        }

        class Error(private val code: String, private val message: String?) : Reply {
            override fun send(result: MethodChannel.Result) = result.error(code, message, null)
        }
    }

    companion object {
        private const val TAG = "PagBankRequestHandler"

        const val METHOD_PAYMENT = "doPayment"
        const val METHOD_VOID_PAYMENT = "voidPayment"
        const val METHOD_ABORT = "abort"
        const val METHOD_LAST_APPROVED_TRANSACTION = "getLastApprovedTransaction"
        const val METHOD_REPRINT_CUSTOMER_RECEIPT = "reprintCustomerReceipt"
        const val METHOD_REPRINT_ESTABLISHMENT_RECEIPT = "reprintEstablishmentReceipt"
        const val METHOD_PRINT_IMAGE = "printImage"

        private const val PRINT_FILE_PREFIX = "pagbank_print"
        private const val PRINT_FILE_SUFFIX = ".png"

        /** PlugPagException sem errorCode próprio. */
        private const val PLUGPAG_ERROR = "PLUGPAG_ERROR"
        private const val PAGBANK_ERROR = "PAGBANK_ERROR"
    }
}
