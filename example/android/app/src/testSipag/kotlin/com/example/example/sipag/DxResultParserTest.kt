package com.example.example.sipag

import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** O JSON que o app Sicoob grava no DX8000 e na X990, lido como o `DxParseOperation` do plugin. */
@RunWith(RobolectricTestRunner::class)
class DxResultParserTest {

    private fun receipt(vararg lines: String) = JSONObject().put("lines", JSONArray(lines.toList()))

    /** Crédito aprovado, com os campos que o app Sicoob grava. */
    private fun approvedCard() = JSONObject()
        .put("label", "VISA")
        .put("authorizationCode", "A1")
        .put("installments", 1)
        .put("product", "CREDITO")
        .put("maskedPan", "****1234")
        .put("transactionID", "T1")
        .put("amount", "100")
        .put("displayMessage", "APROVADA")
        .put("mError", JSONArray())
        .put("receiptList", JSONArray().put(receipt("LOJA\u0000", "L2")).put(receipt("CLIENTE")))

    private fun approved(json: JSONObject): Map<String, Any?> {
        val outcome = DxResultParser.parse(json.toString())
        return (outcome as SipagOutcome.Approved).response
    }

    @Test
    fun `cartao aprovado devolve as chaves do plugin`() {
        assertEquals(
            mapOf(
                "MESSAGE" to "Operação efetuada com sucesso!",
                "FLAG" to "VISA",
                "NSU_SITEF" to "T1",
                "CARD_NUMBER" to "****1234",
                "AUTHORIZATION" to "A1",
                "COMPANY_RECEIPT" to "LOJA\nL2\n",
                "CLIENT_RECEIPT" to "CLIENTE\n",
                "INSTALLMENTS" to 1,
                "AMOUNT" to 1.0
            ),
            approved(approvedCard())
        )
    }

    @Test
    fun `Pix usa o pixID no NSU e, sem maskedPan, o produto no cartao`() {
        val pix = approvedCard().put("product", "PIX").put("pixID", "P9").apply { remove("maskedPan") }
        val response = approved(pix)

        assertEquals("P9", response["NSU_SITEF"])
        assertEquals("PIX", response["CARD_NUMBER"])
    }

    @Test
    fun `estorno sem produto vira Refund com o transactionID`() {
        val response = approved(approvedCard().apply { remove("product") })

        assertEquals("Refund", response["CARD_NUMBER"])
        assertEquals("T1", response["NSU_SITEF"])
    }

    @Test
    fun `mError vira o erro do app Sicoob com a descricao e o codigo POS7`() {
        val error = JSONObject()
            .put("mErrorCode", "E1")
            .put("mErrorDescription", "Cartão recusado")
            .put("mPOS7ErrorCode", 51)
        val outcome = DxResultParser.parse(approvedCard().put("mError", JSONArray().put(error)).toString())

        outcome as SipagOutcome.Failed
        assertEquals("E1", outcome.code)
        assertEquals("Cartão recusado 51", outcome.message)
        assertEquals("Cartão recusado 51", outcome.details?.get("MESSAGE"))
    }

    @Test
    fun `mError sem codigo usa ERRO_NA_OPERACAO`() {
        val error = JSONObject()
            .put("mErrorCode", "")
            .put("mErrorDescription", "Falha")
            .put("mPOS7ErrorCode", 1)
        val outcome = DxResultParser.parse(approvedCard().put("mError", JSONArray().put(error)).toString())

        assertEquals("ERRO_NA_OPERACAO", (outcome as SipagOutcome.Failed).code)
    }

    @Test
    fun `sem comprovante responde INVALID_OPERATION com a mensagem do app`() {
        val outcome = DxResultParser.parse(
            approvedCard().put("receiptList", JSONArray()).put("displayMessage", "NEGADA").toString()
        )

        outcome as SipagOutcome.Failed
        assertEquals("INVALID_OPERATION", outcome.code)
        assertEquals("NEGADA", outcome.message)
    }

    @Test
    fun `sem comprovante e sem mensagem usa o erro interno da adquirente`() {
        val outcome = DxResultParser.parse(
            approvedCard().put("receiptList", JSONArray()).apply { remove("displayMessage") }.toString()
        )

        assertEquals("Erro interno da adquirente!", (outcome as SipagOutcome.Failed).message)
    }

    @Test
    fun `um comprovante so deixa o do cliente vazio`() {
        val response = approved(approvedCard().put("receiptList", JSONArray().put(receipt("LOJA"))))

        assertEquals("", response["CLIENT_RECEIPT"])
    }

    @Test
    fun `null explicito e chave ausente viram texto vazio ou 0`() {
        val response = approved(
            approvedCard().put("label", JSONObject.NULL).apply {
                remove("installments")
                remove("amount")
                remove("authorizationCode")
            }
        )

        assertEquals("", response["FLAG"])
        assertEquals("", response["AUTHORIZATION"])
        assertEquals(0, response["INSTALLMENTS"])
        assertEquals(0.0, response["AMOUNT"])
    }

    @Test
    fun `valor que nao e um inteiro de centavos vira 0`() {
        assertEquals(0.0, approved(approvedCard().put("amount", "1,00"))["AMOUNT"])
    }

    @Test
    fun `JSON ilegivel lanca JSONException`() {
        assertThrows(JSONException::class.java) { DxResultParser.parse("{") }
    }
}
