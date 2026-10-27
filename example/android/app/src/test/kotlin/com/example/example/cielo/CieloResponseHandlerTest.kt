package com.example.example.cielo

import android.content.Intent
import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class CieloResponseHandlerTest {

    private val responses = mutableListOf<Map<String, String?>>()
    private val handler = CieloResponseHandler(RETURN_SCHEME) { responses += it }

    @Test
    fun `decodifica o erro de pagamento da documentacao`() {
        handler.handle(
            response(
                "payment",
                "response=eyJjb2RlIjoxLCJyZWFzb24iOiJDQU5DRUxBRE8gUEVMTyBVU1XDgVJJTyJ9&responsecode=0"
            )
        )

        assertEquals(
            mapOf(
                "action" to "payment",
                "responseCode" to "0",
                "response" to """{"code":1,"reason":"CANCELADO PELO USUÁRIO"}"""
            ),
            responses.single()
        )
    }

    @Test
    fun `aceita o Base64 com quebras de linha do exemplo de informacoes do terminal`() {
        val base64 = "eyJiYXR0ZXJ5TGV2ZWwiOjEuMCwiZGV2aWNlTW9kZWwiOiJEWDgwMDAiLCJpbWVpTnVtYmVyIjoi\n" +
            "ODY2MzcyMDU0OTgwNzk4IiwibG9naWNOdW1iZXIiOiI5MzAwMDA2OS0wIiwibWVyY2hhbnRDb2Rl\n" +
            "IjoiMDAyMDAwMDIzNDU3MDAwMiIsInNlcmlhbE51bWJlciI6IjI0MTlGRDhRODU3NyJ9"

        handler.handle(response("terminalinfo", "response=${Uri.encode(base64)}&responsecode=0"))

        assertEquals(
            """{"batteryLevel":1.0,"deviceModel":"DX8000","imeiNumber":"866372054980798",""" +
                """"logicNumber":"93000069-0","merchantCode":"0020000234570002","serialNumber":"2419FD8Q8577"}""",
            responses.single()["response"]
        )
    }

    @Test
    fun `restaura o mais que o getQueryParameter transforma em espaco`() {
        // Base64 de {"code":0,"message":"~~~~~~"}, com '+' sem codificação na URI.
        handler.handle(response("print", "response=eyJjb2RlIjowLCJtZXNzYWdlIjoifn5+fn5+In0="))

        assertEquals("""{"code":0,"message":"~~~~~~"}""", responses.single()["response"])
        assertNull(responses.single()["responseCode"])
    }

    @Test
    fun `envia response nulo quando o Base64 e invalido ou nao veio`() {
        handler.handle(response("payment", "response=A&responsecode=2"))
        handler.handle(response("orders", "responsecode=2"))

        assertEquals(listOf("payment", "orders"), responses.map { it["action"] })
        assertEquals(listOf(null, null), responses.map { it["response"] })
    }

    @Test
    fun `ignora intents que nao sao retorno da Cielo`() {
        handler.handle(Intent(Intent.ACTION_VIEW, Uri.parse("outroapp://payment?response=e30=")))
        handler.handle(Intent(Intent.ACTION_VIEW, Uri.parse("$RETURN_SCHEME://response?response=e30=")))
        handler.handle(Intent(Intent.ACTION_VIEW))

        assertTrue(responses.isEmpty())
    }

    private fun response(host: String, query: String) =
        Intent(Intent.ACTION_VIEW, Uri.parse("$RETURN_SCHEME://$host?$query"))

    private companion object {
        const val RETURN_SCHEME = "paymentintegrationscielo"
    }
}
