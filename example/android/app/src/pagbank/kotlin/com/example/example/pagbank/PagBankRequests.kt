
package com.example.example.pagbank

import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPag
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagPaymentData
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagVoidData
import io.flutter.plugin.common.MethodCall

/** Tipos de pagamento aceitos pelo canal: o nome vai e volta do Dart, e [sdkValue] é a constante do SDK. */
internal enum class PagBankPaymentType(val sdkValue: Int) {
    CREDIT(PlugPag.TYPE_CREDITO),
    DEBIT(PlugPag.TYPE_DEBITO),
    VOUCHER(PlugPag.TYPE_VOUCHER),
    PIX(PlugPag.TYPE_PIX);

    companion object {
        fun fromSdk(value: Int?): PagBankPaymentType? = entries.firstOrNull { it.sdkValue == value }
    }
}

internal enum class PagBankInstallmentType(val sdkValue: Int) {
    A_VISTA(PlugPag.INSTALLMENT_TYPE_A_VISTA),

    /** Parcelado sem juros para o comprador. */
    PARC_VENDEDOR(PlugPag.INSTALLMENT_TYPE_PARC_VENDEDOR),

    /** Parcelado com juros para o comprador. */
    PARC_COMPRADOR(PlugPag.INSTALLMENT_TYPE_PARC_COMPRADOR)
}

internal enum class PagBankVoidType(val sdkValue: Int) {
    PAYMENT(PlugPag.VOID_PAYMENT),
    QRCODE(PlugPag.VOID_QRCODE);

    companion object {
        private val QRCODE_PAYMENTS = setOf(PlugPag.TYPE_PIX, PlugPag.TYPE_QRCODE, PlugPag.TYPE_QRCODE_CREDITO)

        /** Regra do demo oficial: PIX e QR Code são estornados como QRCODE. */
        fun forPayment(paymentType: Int?): PagBankVoidType = if (paymentType in QRCODE_PAYMENTS) QRCODE else PAYMENT
    }
}

/** Impressão livre pedida pelo canal. O handler grava [image] num arquivo, porque o printFromFile recebe um caminho. */
internal class PagBankPrintRequest(val image: ByteArray, val quality: Int, val steps: Int)

/** Monta os dados do SDK a partir dos argumentos do canal, validando as regras da documentação. */
internal object PagBankRequests {

    // "Deve conter apenas letras (não acentuadas) e números. Esse campo é limitado em 10 caracteres."
    private val USER_REFERENCE = Regex("[A-Za-z0-9]{1,10}")

    // printerQuality do PlugPagPrinterData: de 1 (menor) a 4 (maior), pela documentação anterior do SDK.
    private val PRINT_QUALITY = 1..4

    fun payment(call: MethodCall): PlugPagPaymentData {
        val type = call.enumArgument<PagBankPaymentType>(TYPE)
        val installmentType = call.enumArgument<PagBankInstallmentType>(INSTALLMENT_TYPE)
        val amount = call.required<Int>(AMOUNT)
        val installments = call.required<Int>(INSTALLMENTS)
        val userReference = call.argument<String>(USER_REFERENCE_KEY)?.takeIf { it.isNotEmpty() }

        require(amount > 0) { "amount deve ser maior que zero (centavos)." }
        if (installmentType == PagBankInstallmentType.A_VISTA) {
            require(installments == PlugPag.A_VISTA_INSTALLMENT_QUANTITY) { "À vista usa 1 parcela." }
        } else {
            require(installments >= 2) { "O parcelado usa 2 parcelas ou mais." }
        }
        require(userReference == null || USER_REFERENCE.matches(userReference)) {
            "userReference aceita até 10 letras sem acento e números."
        }

        return PlugPagPaymentData(
            type.sdkValue,
            amount,
            installmentType.sdkValue,
            installments,
            userReference,
            call.argument<Boolean>(PRINT_RECEIPT) ?: false
        )
    }

    fun void(call: MethodCall): PlugPagVoidData {
        val transactionCode = call.required<String>(TRANSACTION_CODE)
        val transactionId = call.required<String>(TRANSACTION_ID)

        require(transactionCode.isNotBlank() && transactionId.isNotBlank()) {
            "transactionCode e transactionId são obrigatórios."
        }

        return PlugPagVoidData(
            transactionCode,
            transactionId,
            call.argument<Boolean>(PRINT_RECEIPT) ?: false,
            call.enumArgument<PagBankVoidType>(VOID_TYPE).sdkValue
        )
    }

    fun print(call: MethodCall): PagBankPrintRequest {
        val image = call.required<ByteArray>(IMAGE)
        val quality = call.required<Int>(QUALITY)
        val steps = call.required<Int>(STEPS)

        require(image.isNotEmpty()) { "image não pode ser vazia." }
        require(quality in PRINT_QUALITY) { "quality aceita de ${PRINT_QUALITY.first} a ${PRINT_QUALITY.last}." }
        require(steps >= PlugPag.MIN_PRINTER_STEPS) { "steps deve ser de no mínimo ${PlugPag.MIN_PRINTER_STEPS}." }

        return PagBankPrintRequest(image, quality, steps)
    }

    private inline fun <reified T : Any> MethodCall.required(key: String): T =
        argument<Any>(key) as? T ?: throw IllegalArgumentException("$key ausente ou com tipo inválido.")

    private inline fun <reified T : Enum<T>> MethodCall.enumArgument(key: String): T {
        val value = argument<Any>(key)
        return enumValues<T>().firstOrNull { it.name == value }
            ?: throw IllegalArgumentException("$key inválido. Valores aceitos: ${enumValues<T>().map { it.name }}.")
    }

    private const val TYPE = "type"
    private const val AMOUNT = "amount"
    private const val INSTALLMENT_TYPE = "installmentType"
    private const val INSTALLMENTS = "installments"
    private const val USER_REFERENCE_KEY = "userReference"
    private const val PRINT_RECEIPT = "printReceipt"
    private const val TRANSACTION_CODE = "transactionCode"
    private const val TRANSACTION_ID = "transactionId"
    private const val VOID_TYPE = "voidType"
    private const val IMAGE = "image"
    private const val QUALITY = "quality"
    private const val STEPS = "steps"
}
