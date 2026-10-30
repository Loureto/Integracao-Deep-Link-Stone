package com.example.example.sipag

import android.app.Application
import android.content.Intent
import ger7.com.br.pos7api.ParamIn
import java.util.Calendar
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowPausedAsyncTask

/** O P2: o `ParamIn` de cada pedido, com o id de data e hora do plugin, e o resultado pelo parser. */
@RunWith(RobolectricTestRunner::class)
class P2TerminalTest {

    private val context: Application = RuntimeEnvironment.getApplication()
    private val sdk = FakeP2Sdk()

    /** 30/10/2026 14:05:09, no fuso do aparelho, como o plugin formata. */
    private val now = Calendar.getInstance().apply { set(2026, Calendar.OCTOBER, 30, 14, 5, 9) }.timeInMillis
    private val terminal = P2Terminal(context, sdk) { now }
    private val replies = mutableListOf<SipagOutcome>()
    private val reply: SipagReply = { replies += it }

    @After
    fun restoreAsyncTask() = ShadowPausedAsyncTask.reset()

    @Test
    fun `cada pedido manda ao SDK o ParamIn do plugin`() {
        terminal.creditPayment("1,00", reply)
        terminal.debitPayment("2,00", reply)
        terminal.pixPayment("3,00", reply)
        terminal.refund("N1", reply)
        terminal.pixRefund("P1", reply)

        assertEquals(
            listOf(
                listOf(1, 1, "100", 1, null, null),
                listOf(1, 2, "200", 1, null, null),
                listOf(1, 8, "300", 0, null, null),
                listOf(2, 7, "0", 0, "N1", null),
                listOf(21, 7, "0", 0, null, "P1")
            ),
            sdk.processed.map {
                listOf(it.trsType, it.trsProduct, it.trsAmount)
                    .plus(listOf(it.trsInstallments, it.trsRefundId, it.trsRefundPixId))
            }
        )
        assertTrue(sdk.processed.all { it.trsId == "1030140509" })
    }

    @Test
    fun `SDK que lanca responde a falha padrao`() {
        sdk.failure = IllegalStateException("sem contexto")

        terminal.creditPayment("1,00", reply)

        assertEquals(listOf(SipagOutcome.Failed("ERRO_NA_OPERACAO", "Falha ao efetuar a operação!")), replies)
    }

    @Test
    fun `o ParamOut do app da Ger7 passa pelo parser`() {
        terminal.creditPayment("1,00", reply)

        sdk.onResult!!.invoke(approvedParamOut())

        assertEquals("R1", (replies.single() as SipagOutcome.Approved).response["NSU_SITEF"])
    }

    @Test
    fun `com o AAR, o pedido abre o Intercom do pos7api com o ParamIn`() {
        // O AsyncTask do AAR espera a saída do Intercom para sempre; aqui ele não roda.
        ShadowPausedAsyncTask.overrideExecutor { }
        val params = ParamIn().apply { trsType = 1 }

        Pos7ApiSdk.process(context, params) { }

        val intent = shadowOf(context).nextStartedActivity
        assertEquals("ger7.com.br.pos7api.Intercom", intent.component?.className)
        assertTrue(intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
        assertNotNull(intent.getParcelableExtra<ParamIn>("ParamIn"))
    }
}
