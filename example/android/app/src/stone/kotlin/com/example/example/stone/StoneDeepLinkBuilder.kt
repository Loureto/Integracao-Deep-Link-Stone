
package com.example.example.stone.payment

import android.content.Intent
import android.net.Uri

internal data class StonePaymentRequest(
    val amount: Long?,
    val editableAmount: Boolean?,
    val transactionType: String?,
    val installmentCount: Long?,
    val installmentType: String?,
    val orderId: Long?,
    val returnScheme: String?
)

internal class StoneDeepLinkBuilder(
    private val returnScheme: String
) {

    fun build(request: StonePaymentRequest): Intent {
        validate(request)

        val uri = Uri.Builder()
            .scheme(SCHEME)
            .authority(AUTHORITY)
            .appendQueryParameter(RETURN_SCHEME, returnScheme)
            .apply {
                request.editableAmount?.let {
                    appendQueryParameter(EDITABLE_AMOUNT, if (it) "1" else "0")
                }

                request.amount?.let {
                    appendQueryParameter(AMOUNT, it.toString())
                }

                request.transactionType?.let {
                    appendQueryParameter(TRANSACTION_TYPE, it.uppercase())
                }

                request.installmentType?.let {
                    appendQueryParameter(INSTALLMENT_TYPE, it.uppercase())
                }

                request.installmentCount?.let {
                    appendQueryParameter(INSTALLMENT_COUNT, it.toString())
                }

                request.orderId?.let {
                    appendQueryParameter(ORDER_ID, it.toString())
                }
            }
            .build()

        return Intent(Intent.ACTION_VIEW, uri).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }

    private fun validate(request: StonePaymentRequest) {
        val requestedReturnScheme = request.returnScheme?.takeIf { it.isNotBlank() }

        require(requestedReturnScheme == null || requestedReturnScheme == returnScheme) {
            "returnScheme deve ser igual ao scheme declarado no AndroidManifest ($returnScheme)."
        }
        require(request.amount == null || request.amount in AMOUNT_RANGE) {
            "amount deve estar entre $AMOUNT_RANGE (centavos)."
        }
        require(request.installmentCount == null || request.installmentCount in INSTALLMENT_COUNT_RANGE) {
            "installmentCount deve estar entre $INSTALLMENT_COUNT_RANGE."
        }
        require(request.transactionType == null || request.transactionType.uppercase() in TRANSACTION_TYPES) {
            "transactionType inválido. Valores aceitos: $TRANSACTION_TYPES."
        }
        require(request.installmentType == null || request.installmentType.uppercase() in INSTALLMENT_TYPES) {
            "installmentType inválido. Valores aceitos: $INSTALLMENT_TYPES."
        }
    }

    companion object {
        private const val SCHEME = "payment-app"
        private const val AUTHORITY = "pay"

        private const val AMOUNT = "amount"
        private const val ORDER_ID = "order_id"
        private const val EDITABLE_AMOUNT = "editable_amount"
        private const val TRANSACTION_TYPE = "transaction_type"
        private const val INSTALLMENT_TYPE = "installment_type"
        private const val INSTALLMENT_COUNT = "installment_count"
        private const val RETURN_SCHEME = "return_scheme"

        private val AMOUNT_RANGE = 0L..999_999_999L
        private val INSTALLMENT_COUNT_RANGE = 2L..99L
        private val TRANSACTION_TYPES = setOf("DEBIT", "CREDIT", "VOUCHER", "INSTANT_PAYMENT", "PIX")
        private val INSTALLMENT_TYPES = setOf("MERCHANT", "ISSUER", "NONE")
    }
}
