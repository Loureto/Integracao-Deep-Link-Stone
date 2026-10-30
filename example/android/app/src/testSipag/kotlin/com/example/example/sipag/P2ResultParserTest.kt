package com.example.example.sipag

import ger7.com.br.pos7api.ParamOut
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** O `ParamOut` que o app da Ger7 devolve no P2, lido como o callback do `PaymentServiceP2Device`. */
@RunWith(RobolectricTestRunner::class)
class P2ResultParserTest {

    /** Crédito aprovado, com o terminal pronto e a licença ativa. */
    private fun approvedCard(block: ParamOut.() -> Unit = {}) = ParamOut().apply {
        setStatus(0)
        setConfig(2)
        setLicense(1)
        setResponse(0)
        setResProduct(1)
        setResLabel("MASTER")
        setResRrn("R1")
        setResAuthorization("A1")
        setPan("5555****")
        setResInstallments(1)
        setResAmount("1000")
        setResPrint("LOJA VIA DO CLIENTE CLIENTE")
        block()
    }

    private fun approved(out: ParamOut) = (P2ResultParser.parse(out) as SipagOutcome.Approved).response

    private fun failed(out: ParamOut) = P2ResultParser.parse(out) as SipagOutcome.Failed

    @Test
    fun `cartao aprovado devolve as chaves do plugin`() {
        assertEquals(
            mapOf(
                "MESSAGE" to "Operação efetuada com sucesso!",
                "FLAG" to "MASTER",
                "NSU_SITEF" to "R1",
                "CARD_NUMBER" to "5555****",
                "AUTHORIZATION" to "A1",
                "COMPANY_RECEIPT" to "LOJA ",
                "CLIENT_RECEIPT" to " CLIENTE",
                "INSTALLMENTS" to 1,
                "AMOUNT" to 10.0
            ),
            approved(approvedCard())
        )
    }

    @Test
    fun `Pix usa o pixId na autorizacao e no NSU`() {
        val response = approved(approvedCard {
            setResProduct(8)
            setResPixId("X1")
        })

        assertEquals("Pix", response["FLAG"])
        assertEquals("X1", response["NSU_SITEF"])
        assertEquals("X1", response["AUTHORIZATION"])
        assertEquals("", response["CARD_NUMBER"])
    }

    @Test
    fun `cartao sem bandeira e sem numero vira Pix nos dois, como no plugin`() {
        val response = approved(approvedCard {
            setResLabel(null)
            setPan(null)
        })

        assertEquals("Pix", response["FLAG"])
        assertEquals("Pix", response["CARD_NUMBER"])
    }

    @Test
    fun `comprovante sem a via do cliente ou nulo deixa os dois vazios`() {
        for (print in listOf("SO A LOJA", null)) {
            val response = approved(approvedCard { setResPrint(print) })

            assertEquals("", response["COMPANY_RECEIPT"])
            assertEquals("", response["CLIENT_RECEIPT"])
        }
    }

    @Test
    fun `valor nulo vira 0`() {
        assertEquals(0.0, approved(approvedCard { setResAmount(null) })["AMOUNT"])
    }

    @Test
    fun `terminal fora do ar responde ERRO_INTERNO`() {
        val outcome = failed(approvedCard { setStatus(1) })

        assertEquals("ERRO_INTERNO", outcome.code)
        assertEquals("Terminal não configurado.", outcome.message)
    }

    @Test
    fun `terminal sem configuracao responde ERRO_NO_TERMINAL com a mensagem do TerminalStatus`() {
        assertEquals(
            listOf(
                "ERRO_NO_TERMINAL" to "Terminal configurado, mas sem paramêtros.",
                "ERRO_NO_TERMINAL" to "Não configurado.",
                "ERRO_NO_TERMINAL" to "Não configurado."
            ),
            listOf(1, 0, 5).map { config ->
                failed(approvedCard { setConfig(config) }).let { it.code to it.message }
            }
        )
    }

    @Test
    fun `licenca diferente de ativa responde LICENCA_INVALIDA`() {
        assertEquals(
            listOf(
                "Licença inativa.",
                "Licença negada.",
                "Licença bloqueada.",
                "Licença desativada.",
                "Licença expirada.",
                "Licença inválida."
            ),
            listOf(0, 96, 97, 98, 99, 2).map { license ->
                val outcome = failed(approvedCard { setLicense(license) })
                assertEquals("LICENCA_INVALIDA", outcome.code)
                outcome.message
            }
        )
    }

    @Test
    fun `transacao recusada responde ERRO_NA_OPERACAO com a mensagem do app e o mapa nos detalhes`() {
        val outcome = failed(approvedCard {
            setResponse(5)
            setResDisplay("NEGADA")
        })

        assertEquals("ERRO_NA_OPERACAO", outcome.code)
        assertEquals("NEGADA", outcome.message)
        assertEquals("NEGADA", outcome.details?.get("MESSAGE"))
        assertEquals("R1", outcome.details?.get("NSU_SITEF"))
    }

    @Test
    fun `transacao recusada sem mensagem usa a falha padrao`() {
        val outcome = failed(approvedCard {
            setResponse(5)
            setResDisplay(null)
        })

        assertEquals("Falha ao efetuar a operação!", outcome.message)
    }
}
