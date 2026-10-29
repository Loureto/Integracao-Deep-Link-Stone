package com.example.example.rede

import android.content.Context
import android.content.Intent
import rede.smartrede.sdk.FlexTipoPagamento
import rede.smartrede.sdk.RedePayments

/**
 * O app de pagamento da Rede, aberto pelo SDK. Fica atrás desta interface para os testes rodarem sem o L400.
 */
internal interface RedePaymentApp {

    /**
     * Intent que abre o pagamento de [amount] centavos. Lança `RedePaymentValidationError` se o SDK o
     * recusar, como no valor zero.
     */
    fun paymentIntent(type: FlexTipoPagamento, amount: Long): Intent

    /** Intent que abre o estorno do pagamento [nsu]. */
    fun reversalIntent(nsu: String): Intent
}

/** [RedePaymentApp] pelo SDK SmartRede do L400, como o `PaymentService` do plugin flutter_rede_sdk. */
internal class SmartRedePaymentApp(private val context: Context) : RedePaymentApp {

    override fun paymentIntent(type: FlexTipoPagamento, amount: Long): Intent =
        RedePayments.getInstance(context).intentForPaymentBuilder(type, amount).build()

    override fun reversalIntent(nsu: String): Intent =
        RedePayments.getInstance(context).intentForReversal(nsu)
}
