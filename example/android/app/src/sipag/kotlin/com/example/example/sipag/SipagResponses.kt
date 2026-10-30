package com.example.example.sipag

/**
 * Resultado de uma operação da Sipag: o mapa com as chaves do plugin `flutter_sipag_sdk`, ou o erro com o
 * código, a mensagem e, quando o plugin mandava, o mesmo mapa nos detalhes. Um erro com `keepPending` deixa
 * a marca de operação pendente ligada, porque a venda pode ter sido aprovada.
 */
internal sealed interface SipagOutcome {
    data class Approved(val response: Map<String, Any?>) : SipagOutcome
    data class Failed(
        val code: String,
        val message: String,
        val details: Map<String, Any?>? = null,
        val keepPending: Boolean = false
    ) : SipagOutcome
}

// Mensagens e códigos do `strings.xml` e das classes do plugin, que o PDV Varejo mostra ou compara.
internal const val SUCCESS_PAYMENT = "Operação efetuada com sucesso!"
internal const val PAYMENT_FAILED = "Falha ao efetuar a operação!"
internal const val INVALID_OPERATION_CODE = "INVALID_OPERATION"
internal const val INTERNAL_ERROR_MESSAGE = "Erro interno da adquirente!"
internal const val ERRO_NA_OPERACAO = "ERRO_NA_OPERACAO"
internal const val ERRO_INTERNO = "ERRO_INTERNO"
internal const val ERRO_NO_TERMINAL = "ERRO_NO_TERMINAL"
internal const val LICENCA_INVALIDA = "LICENCA_INVALIDA"
internal const val LAST_OPERATION_NOT_FOUND = "LAST_OPERATION_NOT_FOUND"
internal const val LAST_OPERATION_NOT_FOUND_MESSAGE = "Não foi encontrado nenhuma operação no histórico!"
internal const val FILE_DOES_NOT_EXIST = "FILE_DOES_NOT_EXIST"
internal const val READ_OPERATION_FILE_FAILED = "READ_OPERATION_FILE_FAILED"
internal const val LAST_OPERATION_FAILED_MESSAGE = "Não foi possível recuperar a última operação!"

// Mensagens das situações em que o plugin travava o Dart ou o deixava sem mensagem; os códigos são os dele.
internal const val STORAGE_PERMISSION_MESSAGE = "Permita o acesso ao armazenamento e tente novamente."
internal const val NO_PAYMENT_APP_MESSAGE = "Não localizamos aplicativo de pagamento neste terminal."
internal const val REPLACED_OPERATION_MESSAGE = "Operação substituída por uma nova."
internal const val INVALID_LICENSE_MESSAGE = "Licença inválida."

/**
 * Mapa do `TransactionResponse.responseToJson` do plugin, com as nove chaves. Texto nulo vira "": no plugin,
 * ele chegava nulo ao Dart e quebrava o `toResult` com erro de tipo.
 */
internal fun transactionResponse(
    message: String,
    flag: String?,
    nsu: String?,
    cardNumber: String?,
    authorization: String?,
    companyReceipt: String?,
    clientReceipt: String?,
    installments: Int,
    amount: Double
): Map<String, Any?> = mapOf(
    "MESSAGE" to message,
    "FLAG" to flag.orEmpty(),
    "NSU_SITEF" to nsu.orEmpty(),
    "CARD_NUMBER" to cardNumber.orEmpty(),
    "AUTHORIZATION" to authorization.orEmpty(),
    "COMPANY_RECEIPT" to companyReceipt.orEmpty(),
    "CLIENT_RECEIPT" to clientReceipt.orEmpty(),
    "INSTALLMENTS" to installments,
    "AMOUNT" to amount
)

/** Centavos em texto para reais. Texto que não é inteiro vira 0; no plugin, o `parseLong` derrubava o app. */
internal fun centsToReais(cents: String?): Double = cents?.trim()?.toLongOrNull()?.div(100.0) ?: 0.0
