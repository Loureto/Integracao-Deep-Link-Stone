package com.example.example.stone.payment

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class StoneDeepLinkBuilderTest {

    private val builder = StoneDeepLinkBuilder(RETURN_SCHEME)

    @Test
    fun `sem campos opcionais envia somente return_scheme`() {
        val intent = builder.build(request())

        assertEquals(Intent.ACTION_VIEW, intent.action)
        assertTrue(intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
        assertEquals("payment-app://pay?return_scheme=$RETURN_SCHEME", intent.dataString)
    }

    @Test
    fun `credito parcelado envia todos os campos documentados`() {
        val uri = builder.build(
            request(
                amount = 999_999_999,
                editableAmount = true,
                transactionType = "credit",
                installmentCount = 99,
                installmentType = "issuer",
                orderId = Long.MAX_VALUE,
                returnScheme = RETURN_SCHEME
            )
        ).data!!

        assertEquals("payment-app", uri.scheme)
        assertEquals("pay", uri.authority)
        assertEquals(RETURN_SCHEME, uri.getQueryParameter("return_scheme"))
        assertEquals("1", uri.getQueryParameter("editable_amount"))
        assertEquals("999999999", uri.getQueryParameter("amount"))
        assertEquals("CREDIT", uri.getQueryParameter("transaction_type"))
        assertEquals("ISSUER", uri.getQueryParameter("installment_type"))
        assertEquals("99", uri.getQueryParameter("installment_count"))
        assertEquals("9223372036854775807", uri.getQueryParameter("order_id"))
    }

    @Test
    fun `debito nao envia campos de parcelamento`() {
        val uri = builder.build(
            request(amount = 0, editableAmount = false, transactionType = "DEBIT")
        ).data!!

        assertEquals("0", uri.getQueryParameter("amount"))
        assertEquals("0", uri.getQueryParameter("editable_amount"))
        assertEquals("DEBIT", uri.getQueryParameter("transaction_type"))
        assertNull(uri.getQueryParameter("installment_type"))
        assertNull(uri.getQueryParameter("installment_count"))
        assertNull(uri.getQueryParameter("order_id"))
    }

    @Test
    fun `return_scheme em branco usa o scheme configurado`() {
        val uri = builder.build(request(returnScheme = " ")).data!!

        assertEquals(RETURN_SCHEME, uri.getQueryParameter("return_scheme"))
    }

    @Test
    fun `rejeita valores fora do contrato documentado`() {
        listOf(
            request(amount = -1),
            request(amount = 1_000_000_000),
            request(installmentCount = 1),
            request(installmentCount = 100),
            request(transactionType = "CASH"),
            request(transactionType = ""),
            request(installmentType = "SEM_JUROS"),
            request(returnScheme = "outroapp")
        ).forEach { invalid ->
            assertThrows(invalid.toString(), IllegalArgumentException::class.java) {
                builder.build(invalid)
            }
        }
    }

    private fun request(
        amount: Long? = null,
        editableAmount: Boolean? = null,
        transactionType: String? = null,
        installmentCount: Long? = null,
        installmentType: String? = null,
        orderId: Long? = null,
        returnScheme: String? = null
    ) = StonePaymentRequest(
        amount = amount,
        editableAmount = editableAmount,
        transactionType = transactionType,
        installmentCount = installmentCount,
        installmentType = installmentType,
        orderId = orderId,
        returnScheme = returnScheme
    )

    private companion object {
        const val RETURN_SCHEME = "paymentintegrationsstone"
    }
}
