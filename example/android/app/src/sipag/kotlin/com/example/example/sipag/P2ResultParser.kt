package com.example.example.sipag

import ger7.com.br.pos7api.ParamOut

/**
 * Lê o `ParamOut` que o app da Ger7 devolve no P2, como o callback do `PaymentServiceP2Device` do plugin
 * `flutter_sipag_sdk`: o terminal, a configuração e a licença vêm antes do resultado da transação, com as
 * mensagens do `TerminalStatus` dele.
 */
internal object P2ResultParser {

    private const val PIX_PRODUCT = 8
    private const val PIX = "Pix"
    private const val CUSTOMER_COPY = "VIA DO CLIENTE"

    private const val READY_STATUS = 0
    private const val READY_CONFIG = 2
    private const val ACTIVE_LICENSE = 1
    private const val APPROVED_RESPONSE = 0

    private const val NOT_CONFIGURED = "Não configurado."
    private const val CONFIGURED_WITHOUT_PARAMETERS = "Terminal configurado, mas sem paramêtros."

    /** Mensagens das licenças do `TerminalStatus`. Um código fora do mapa ia nulo no plugin. */
    private val licenses = mapOf(
        0 to "Licença inativa.",
        96 to "Licença negada.",
        97 to "Licença bloqueada.",
        98 to "Licença desativada.",
        99 to "Licença expirada."
    )

    fun parse(out: ParamOut): SipagOutcome {
        if (out.status != READY_STATUS) return SipagOutcome.Failed(ERRO_INTERNO, "Terminal não configurado.")
        if (out.config != READY_CONFIG) {
            val message = if (out.config == 1) CONFIGURED_WITHOUT_PARAMETERS else NOT_CONFIGURED
            return SipagOutcome.Failed(ERRO_NO_TERMINAL, message)
        }
        if (out.license != ACTIVE_LICENSE) {
            return SipagOutcome.Failed(LICENCA_INVALIDA, licenses[out.license] ?: INVALID_LICENSE_MESSAGE)
        }

        val approved = out.response == APPROVED_RESPONSE
        val message = if (approved) SUCCESS_PAYMENT else out.resDisplay ?: PAYMENT_FAILED
        val receipts = out.resPrint?.takeIf { it.contains(CUSTOMER_COPY) }?.split(CUSTOMER_COPY)
        val pix = out.resProduct == PIX_PRODUCT

        // Bandeira e número do cartão nulos viram "Pix", como no `TransactionResponse` do plugin.
        val response = transactionResponse(
            message = message,
            flag = if (pix) PIX else out.resLabel ?: PIX,
            nsu = if (pix) out.resPixId else out.resRrn,
            cardNumber = if (pix) "" else out.pan ?: PIX,
            authorization = if (pix) out.resPixId else out.resAuthorization,
            companyReceipt = receipts?.getOrElse(0) { "" },
            clientReceipt = receipts?.getOrElse(1) { "" },
            installments = out.resInstallments,
            amount = centsToReais(out.resAmount)
        )

        return if (approved) {
            SipagOutcome.Approved(response)
        } else {
            SipagOutcome.Failed(ERRO_NA_OPERACAO, message, response)
        }
    }
}
