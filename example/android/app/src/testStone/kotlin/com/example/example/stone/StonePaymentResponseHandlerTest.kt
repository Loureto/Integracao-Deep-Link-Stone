package com.example.example.stone.payment

import android.content.Intent
import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class StonePaymentResponseHandlerTest {

    private val responses = mutableListOf<Map<String, String?>>()
    private val handler = StonePaymentResponseHandler(RETURN_SCHEME) { responses += it }

    @Test
    fun `repassa o retorno de sucesso decodificado`() {
        handler.handle(
            response(
                "code=0&amount=100&cardholder_name=JOAO%2FSILVA&itk=PB0419AL60480-1.17.7-2278-0003" +
                    "&atk=37820073187607&authorization_date_time=05%2F10%2F2022%2002%3A36%3A17" +
                    "&brand=MASTERCARD&authorization_code=187607&installment_count=0" +
                    "&pan=627303****2166&type=D%C3%A9bito&entry_mode=ICC"
            )
        )

        val response = responses.single()
        assertEquals(12, response.size)
        assertEquals("0", response["code"])
        assertEquals("JOAO/SILVA", response["cardholder_name"])
        assertEquals("05/10/2022 02:36:17", response["authorization_date_time"])
        assertEquals("37820073187607", response["atk"])
        assertEquals("627303****2166", response["pan"])
        assertEquals("Débito", response["type"])
    }

    @Test
    fun `repassa o encerramento pelo usuario`() {
        handler.handle(response("code=2&message=Usu%C3%A1rio%20encerrou%20o%20aplicativo"))

        assertEquals(
            mapOf("code" to "2", "message" to "Usuário encerrou o aplicativo"),
            responses.single()
        )
    }

    @Test
    fun `repassa a transacao nao autorizada com todos os campos`() {
        handler.handle(
            response("success=false&reason=1016&response_code=-6&code=-6&message=N%C3%A3o%20autorizada")
        )

        assertEquals(
            mapOf(
                "success" to "false",
                "reason" to "1016",
                "response_code" to "-6",
                "code" to "-6",
                "message" to "Não autorizada"
            ),
            responses.single()
        )
    }

    @Test
    fun `ignora intents que nao sao retorno de pagamento`() {
        handler.handle(Intent(Intent.ACTION_VIEW, Uri.parse("outroapp://pay-response?code=0")))
        handler.handle(Intent(Intent.ACTION_VIEW, Uri.parse("$RETURN_SCHEME://print?code=0")))
        handler.handle(Intent(Intent.ACTION_VIEW))

        assertTrue(responses.isEmpty())
    }

    private fun response(query: String) =
        Intent(Intent.ACTION_VIEW, Uri.parse("$RETURN_SCHEME://pay-response?$query"))

    private companion object {
        const val RETURN_SCHEME = "paymentintegrationsstone"
    }
}
