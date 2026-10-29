package com.example.example.rede

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import io.flutter.plugin.common.MethodCall
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import rede.smartrede.sdk.FlexTipoPagamento
import rede.smartrede.sdk.PaymentStatus

/** O flavor exige a API 28, acima da 25 do robolectric.properties, então os testes rodam só na 30. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class RedePaymentHandlerTest {

    private val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    private val app = FakeRedePaymentApp()
    private val handler = RedePaymentHandler(activity, app)
    private val result = RecordingResult()

    private val approvedCredit = mapOf(
        "FLAG" to "VISA",
        "NSU_SITEF" to "123",
        "AUTHORIZATION" to "A1",
        "INSTALLMENTS" to 1,
        "AMOUNT" to 1.0,
        "CARD_NUMBER" to "Crédito"
    )

    private fun pay(method: String = "credit_payment", result: RecordingResult = this.result) =
        handler.handle(MethodCall(method, mapOf("amount" to 100)), result)

    private fun refund(result: RecordingResult = this.result) =
        handler.handle(MethodCall("refund", mapOf("nsu" to "123")), result)

    @Test
    fun `credit_payment debit_payment e pix_payment abrem o app da Rede com o tipo e o valor e codigo 4`() {
        listOf("credit_payment", "debit_payment", "pix_payment").forEach { method ->
            pay(method)
            assertEquals(method, 4, shadowOf(activity).nextStartedActivityForResult.requestCode)
        }

        assertEquals(
            listOf(
                FlexTipoPagamento.CREDITO_A_VISTA to 100L,
                FlexTipoPagamento.DEBITO to 100L,
                FlexTipoPagamento.PIX to 100L
            ),
            app.payments
        )
        assertEquals(emptyList<Any?>(), result.replies)
    }

    @Test
    fun `refund abre o estorno com o NSU e codigo 5`() {
        refund()

        assertEquals(5, shadowOf(activity).nextStartedActivityForResult.requestCode)
        assertEquals(listOf("123"), app.reversals)
        assertEquals(emptyList<Any?>(), result.replies)
    }

    @Test
    fun `pagamento aprovado responde as chaves do plugin`() {
        pay()

        val handled = handler.onActivityResult(4, Activity.RESULT_OK, paymentResult(PaymentStatus.AUTHORIZED))

        assertTrue(handled)
        assertEquals(listOf<Any?>(approvedCredit), result.replies)
    }

    @Test
    fun `no Pix a autorizacao e o NSU e sem emissor a bandeira e Pagamento mais o tipo`() {
        pay("pix_payment")

        handler.onActivityResult(
            4,
            Activity.RESULT_OK,
            paymentResult(PaymentStatus.AUTHORIZED, receipt(operationType = "PIX", issuerName = null))
        )

        val response = result.replies.single() as Map<*, *>
        assertEquals("Pagamento PIX", response["FLAG"])
        assertEquals("123", response["AUTHORIZATION"])
        assertEquals("PIX", response["CARD_NUMBER"])
    }

    @Test
    fun `recibo nulo responde as chaves sem valor`() {
        pay()

        handler.onActivityResult(
            4,
            Activity.RESULT_OK,
            paymentResult(PaymentStatus.AUTHORIZED, receipt = null)
        )

        val response = result.replies.single() as Map<*, *>
        assertEquals(
            setOf("FLAG", "NSU_SITEF", "AUTHORIZATION", "INSTALLMENTS", "AMOUNT", "CARD_NUMBER"),
            response.keys
        )
        assertTrue(response.values.all { it == null })
    }

    @Test
    fun `estorno aprovado responde os valores fixos do plugin`() {
        refund()

        handler.onActivityResult(5, Activity.RESULT_OK, paymentResult(PaymentStatus.AUTHORIZED))

        assertEquals(
            listOf<Any?>(
                mapOf(
                    "FLAG" to "Estorno",
                    "NSU_SITEF" to "",
                    "AUTHORIZATION" to "",
                    "INSTALLMENTS" to 1,
                    "AMOUNT" to 0.0,
                    "CARD_NUMBER" to "refund"
                )
            ),
            result.replies
        )
    }

    @Test
    fun `FAILED responde TRANSACTION_FAILED no pagamento e REFUND_FAILED no estorno`() {
        val refunded = RecordingResult()

        pay()
        handler.onActivityResult(4, Activity.RESULT_OK, paymentResult(PaymentStatus.FAILED))
        refund(refunded)
        handler.onActivityResult(5, Activity.RESULT_OK, paymentResult(PaymentStatus.FAILED))

        assertEquals(listOf<Any?>("error:TRANSACTION_FAILED:Falha ao efetuar a transação!"), result.replies)
        assertEquals(listOf<Any?>("error:REFUND_FAILED:Falha ao realizar estorno!"), refunded.replies)
    }

    @Test
    fun `outro status responde TRANSACTION_DENY no pagamento e REFUND_DENY no estorno`() {
        val refunded = RecordingResult()

        pay()
        handler.onActivityResult(4, Activity.RESULT_OK, paymentResult(PaymentStatus.DECLINED))
        refund(refunded)
        handler.onActivityResult(5, Activity.RESULT_OK, paymentResult(PaymentStatus.DECLINED))

        assertEquals(listOf<Any?>("error:TRANSACTION_DENY:Operação negada!"), result.replies)
        assertEquals(listOf<Any?>("error:REFUND_DENY:Estorno negado!"), refunded.replies)
    }

    @Test
    fun `RESULT_CANCELED responde OPERATION_CANCELED`() {
        pay()

        handler.onActivityResult(4, Activity.RESULT_CANCELED, null)

        assertEquals(listOf<Any?>("error:OPERATION_CANCELED:Operação cancelada!"), result.replies)
    }

    @Test
    fun `RESULT_OK sem dados ou sem pagamento responde ERRO_DESCONHECIDO`() {
        val withoutPayment = RecordingResult()

        pay()
        handler.onActivityResult(4, Activity.RESULT_OK, null)
        pay(result = withoutPayment)
        handler.onActivityResult(4, Activity.RESULT_OK, Intent())

        val unknown = listOf<Any?>("error:ERRO_DESCONHECIDO:Erro desconhecido, tente novamente!")
        assertEquals(unknown, result.replies)
        assertEquals(unknown, withoutPayment.replies)
    }

    @Test
    fun `retorno que o SDK nao consegue ler responde ERRO_DESCONHECIDO sem derrubar o app`() {
        // Um extra de pagamento de outro tipo faz o getPaymentFromIntent do SDK lançar ClassCastException.
        pay()

        val unreadable = Intent().putExtra(PAYMENT_EXTRA, Bundle())

        val handled = handler.onActivityResult(4, Activity.RESULT_OK, unreadable)

        assertTrue(handled)
        val unknown = listOf<Any?>("error:ERRO_DESCONHECIDO:Erro desconhecido, tente novamente!")
        assertEquals(unknown, result.replies)
    }

    @Test
    fun `outro resultCode responde UNKNOWN_ERROR`() {
        pay()

        handler.onActivityResult(4, Activity.RESULT_FIRST_USER, null)

        assertEquals(listOf<Any?>("error:UNKNOWN_ERROR:Erro desconhecido, tente novamente!"), result.replies)
    }

    @Test
    fun `outro requestCode e ignorado`() {
        pay()

        val handled = handler.onActivityResult(1, Activity.RESULT_OK, paymentResult(PaymentStatus.AUTHORIZED))

        assertFalse(handled)
        assertEquals(emptyList<Any?>(), result.replies)
    }

    @Test
    fun `responde uma unica vez`() {
        pay()

        handler.onActivityResult(4, Activity.RESULT_OK, paymentResult(PaymentStatus.AUTHORIZED))
        val handledAgain = handler.onActivityResult(4, Activity.RESULT_CANCELED, null)

        assertTrue(handledAgain)
        assertEquals(1, result.replies.size)
    }

    @Test
    fun `operacao nova fica com o proximo retorno`() {
        val first = RecordingResult()
        pay(result = first)
        pay("debit_payment")

        handler.onActivityResult(4, Activity.RESULT_OK, paymentResult(PaymentStatus.AUTHORIZED))

        assertEquals(emptyList<Any?>(), first.replies)
        assertEquals(listOf<Any?>(approvedCredit), result.replies)
    }

    @Test
    fun `app da Rede ausente responde ERRO_DESCONHECIDO`() {
        shadowOf(RuntimeEnvironment.getApplication()).checkActivities(true)

        pay()

        assertEquals(
            listOf<Any?>("error:ERRO_DESCONHECIDO:Não localizamos aplicativo de pagamento neste terminal."),
            result.replies
        )
    }

    @Test
    fun `excecao ao abrir responde a mensagem ou o texto padrao`() {
        val withoutMessage = RecordingResult()
        val refunded = RecordingResult()

        app.failure = RuntimeException("valor do pagamento menor ou igual a zero")
        pay()
        app.failure = RuntimeException()
        pay(result = withoutMessage)
        app.failure = IllegalArgumentException()
        refund(refunded)

        assertEquals(
            listOf<Any?>("error:ERRO_DESCONHECIDO:valor do pagamento menor ou igual a zero"),
            result.replies
        )
        assertEquals(
            listOf<Any?>("error:ERRO_DESCONHECIDO:Erro ao iniciar pagamento, tente novamente!"),
            withoutMessage.replies
        )
        assertEquals(
            listOf<Any?>("error:ERRO_DESCONHECIDO:Erro ao iniciar estorno, tente novamente!"),
            refunded.replies
        )
        assertNull(shadowOf(activity).nextStartedActivityForResult)
    }

    @Test
    fun `sem amount ou nsu responde o erro do plugin sem abrir o app`() {
        val withoutNsu = RecordingResult()

        handler.handle(MethodCall("credit_payment", emptyMap<String, Any?>()), result)
        handler.handle(MethodCall("refund", emptyMap<String, Any?>()), withoutNsu)

        assertEquals(listOf<Any?>("error:amount:amount is null"), result.replies)
        assertEquals(listOf<Any?>("error:nsu:nsu is null"), withoutNsu.replies)
        assertNull(shadowOf(activity).nextStartedActivityForResult)
    }
}
