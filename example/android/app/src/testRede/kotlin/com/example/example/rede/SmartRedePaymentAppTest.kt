package com.example.example.rede

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import rede.smartrede.sdk.FlexTipoPagamento
import rede.smartrede.sdk.Payment
import rede.smartrede.sdk.RedePaymentValidationError

/** O adaptador com o SDK da Rede de verdade: só o app da Rede, que fica no L400, falta aqui. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class SmartRedePaymentAppTest {

    private val app = SmartRedePaymentApp(RuntimeEnvironment.getApplication())

    @Test
    fun `paymentIntent leva o valor e o tipo no pagamento do SDK`() {
        @Suppress("DEPRECATION")
        val payment = app.paymentIntent(FlexTipoPagamento.CREDITO_A_VISTA, 100)
            .getParcelableExtra<Payment>(PAYMENT_EXTRA)!!

        assertEquals(100L, payment.amount)
        assertEquals(FlexTipoPagamento.CREDITO_A_VISTA, payment.paymentType)
    }

    @Test
    fun `valor zero e recusado pela validacao do SDK`() {
        assertThrows(RedePaymentValidationError::class.java) {
            app.paymentIntent(FlexTipoPagamento.DEBITO, 0)
        }
    }
}
