package com.example.example.pagbank

import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPag
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagTransactionResult
import io.flutter.plugin.common.MethodCall
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class PagBankRequestsTest {

    @Test
    fun `monta o pagamento com as constantes do SDK`() {
        val data = PagBankRequests.payment(
            MethodCall(
                "doPayment",
                mapOf(
                    "type" to "CREDIT",
                    "amount" to 2000,
                    "installmentType" to "PARC_COMPRADOR",
                    "installments" to 2,
                    "userReference" to "VENDA01",
                    "printReceipt" to true
                )
            )
        )

        assertEquals(PlugPag.TYPE_CREDITO, data.type)
        assertEquals(2000, data.amount)
        assertEquals(PlugPag.INSTALLMENT_TYPE_PARC_COMPRADOR, data.installmentType)
        assertEquals(2, data.installments)
        assertEquals("VENDA01", data.userReference)
        assertEquals(true, data.printReceipt)
    }

    @Test
    fun `pagamento a vista sem userReference nem printReceipt`() {
        val data = PagBankRequests.payment(
            MethodCall(
                "doPayment",
                mapOf("type" to "PIX", "amount" to 100, "installmentType" to "A_VISTA", "installments" to 1)
            )
        )

        assertEquals(PlugPag.TYPE_PIX, data.type)
        assertEquals(PlugPag.INSTALLMENT_TYPE_A_VISTA, data.installmentType)
        assertNull(data.userReference)
        assertFalse(data.printReceipt)
    }

    @Test
    fun `PIX e QR Code sao estornados como QRCODE, como no demo oficial`() {
        listOf(PlugPag.TYPE_PIX, PlugPag.TYPE_QRCODE, PlugPag.TYPE_QRCODE_CREDITO).forEach { type ->
            assertEquals("$type", "QRCODE", PlugPagTransactionResult(paymentType = type).toMap()["voidType"])
        }
        listOf(PlugPag.TYPE_CREDITO, PlugPag.TYPE_DEBITO, PlugPag.TYPE_VOUCHER, null).forEach { type ->
            assertEquals("$type", "PAYMENT", PlugPagTransactionResult(paymentType = type).toMap()["voidType"])
        }
    }

    @Test
    fun `envia o tipo de pagamento pelo nome, ou nulo quando o canal nao o conhece`() {
        assertEquals("DEBIT", PlugPagTransactionResult(paymentType = PlugPag.TYPE_DEBITO).toMap()["paymentType"])
        assertNull(PlugPagTransactionResult(paymentType = PlugPag.TYPE_PREAUTO_CARD).toMap()["paymentType"])
    }
}
