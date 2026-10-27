package com.example.example.cielo

import android.content.Intent
import android.util.Base64
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class CieloDeepLinkBuilderTest {

    private val builder = CieloDeepLinkBuilder(RETURN_SCHEME)

    @Test
    fun `pagamento envia o JSON em Base64 e o urlCallback com o host da acao`() {
        val json = """{"clientID":"client","accessToken":"token","value":"1000"}"""

        val intent = builder.build(CieloAction.PAYMENT, json)
        val uri = intent.data!!

        assertEquals(Intent.ACTION_VIEW, intent.action)
        assertTrue(intent.flags and Intent.FLAG_ACTIVITY_CLEAR_TOP != 0)
        assertEquals("lio", uri.scheme)
        assertEquals("payment", uri.authority)
        assertEquals("$RETURN_SCHEME://payment", uri.getQueryParameter("urlCallback"))
        assertEquals(json, decode(uri.getQueryParameter("request")))
    }

    @Test
    fun `cada acao volta no host com o proprio nome`() {
        CieloAction.entries.forEach { action ->
            val uri = builder.build(action, "{}").data!!

            assertEquals(action.value, uri.authority)
            assertEquals("$RETURN_SCHEME://${action.value}", uri.getQueryParameter("urlCallback"))
        }
    }

    @Test
    fun `request vai sem quebra de linha e mantem o mais do Base64`() {
        // Seis '~' seguidos geram "fn5+" em Base64, e o JSON passa dos 76 caracteres do Base64.DEFAULT.
        val json = """{"notes":"${"~".repeat(6)}","reference":"${"x".repeat(200)}"}"""

        val request = builder.build(CieloAction.PAYMENT, json).data!!.getQueryParameter("request")!!

        assertTrue(request.contains('+'))
        assertFalse(request.contains('\n'))
        assertEquals(json, decode(request))
    }

    @Test
    fun `informacoes do terminal nao envia request`() {
        val uri = builder.build(CieloAction.TERMINAL_INFO, null).data!!

        assertEquals("lio://terminalinfo?urlCallback=$RETURN_SCHEME%3A%2F%2Fterminalinfo", uri.toString())
        assertNull(uri.getQueryParameter("request"))
    }

    @Test
    fun `acoes com corpo exigem request`() {
        listOf(null, "", " ").forEach { request ->
            assertThrows(IllegalArgumentException::class.java) {
                builder.build(CieloAction.PAYMENT, request)
            }
        }
    }

    private fun decode(base64: String?) = String(Base64.decode(base64, Base64.DEFAULT), Charsets.UTF_8)

    private companion object {
        const val RETURN_SCHEME = "paymentintegrationscielo"
    }
}
