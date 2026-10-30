package com.example.example.sipag

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.ResolveInfo
import android.os.Looper
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import printx990.br.apix990.internal.domain.dto.PRODUCT
import printx990.br.apix990.internal.domain.dto.TransactionData
import printx990.br.apix990.internal.domain.dto.TypeTransaction

/** O DX8000 e a X990: o `TransactionData` de cada pedido e as checagens que evitam os travamentos do AAR. */
@RunWith(RobolectricTestRunner::class)
class DxTerminalTest {

    private val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    private val sdk = FakeDxSdk()
    private val resultFile = File(activity.cacheDir, "operation_result.json")
    private val terminal = DxTerminal(activity, sdk, { resultFile }, retryDelayMs = 0)
    private val replies = mutableListOf<SipagOutcome>()
    private val reply: SipagReply = { replies += it }

    private fun grantStorage() = shadowOf(activity.application).grantPermissions(
        Manifest.permission.READ_EXTERNAL_STORAGE,
        Manifest.permission.WRITE_EXTERNAL_STORAGE
    )

    private fun grantReadOnly() =
        shadowOf(activity.application).grantPermissions(Manifest.permission.READ_EXTERNAL_STORAGE)

    @Test
    fun `cada pedido manda ao SDK o TransactionData do plugin`() {
        grantStorage()

        terminal.creditPayment("1,00", reply)
        terminal.debitPayment("2,00", reply)
        terminal.pixPayment("3,00", reply)
        terminal.refund("N1", reply)
        terminal.pixRefund("P1", reply)

        assertEquals(
            listOf(
                listOf(PRODUCT.CREDITO, "1,00", TypeTransaction.TRANSACTION, "AVISTA", 0, null),
                listOf(PRODUCT.DEBITO, "2,00", TypeTransaction.TRANSACTION, null, null, null),
                listOf(PRODUCT.PIX, "3,00", TypeTransaction.TRANSACTION, null, null, null),
                // O estorno de cartão não leva o NSU: o TransactionData não tem o campo.
                listOf(null, null, TypeTransaction.CANCELTRANSACTION, null, null, null),
                listOf(null, null, TypeTransaction.PIXREVERSE, null, null, "P1")
            ),
            sdk.started.map {
                val credit = it.creditType
                listOf(it.product, it.amount, it.typeTransaction)
                    .plus(listOf(credit?.type, credit?.installments, it.pixId))
            }
        )
        sdk.started.forEach {
            assertFalse(it.pixReprinter)
            assertEquals(activity.packageName, it.packageName)
            assertEquals(true, it.receipt)
        }
    }

    @Test
    fun `sem a permissao de leitura responde o erro, pede a permissao e nao chama o SDK`() {
        terminal.creditPayment("1,00", reply)

        assertEquals(
            listOf(SipagOutcome.Failed("ERRO_NA_OPERACAO", STORAGE_MESSAGE)),
            replies
        )
        assertTrue(sdk.started.isEmpty())
        val request = shadowOf(activity).lastRequestedPermission
        assertTrue(Manifest.permission.READ_EXTERNAL_STORAGE in request.requestedPermissions)
    }

    @Test
    @Config(sdk = [25])
    fun `ate o Android 10, sem a WRITE responde o erro e pede as duas permissoes`() {
        // Sem a WRITE, o apix990 não consegue apagar o resultado anterior e o leria como o do pagamento novo.
        grantReadOnly()

        terminal.creditPayment("1,00", reply)

        assertEquals(listOf(SipagOutcome.Failed("ERRO_NA_OPERACAO", STORAGE_MESSAGE)), replies)
        assertTrue(sdk.started.isEmpty())
        val request = shadowOf(activity).lastRequestedPermission
        assertTrue(Manifest.permission.WRITE_EXTERNAL_STORAGE in request.requestedPermissions)
    }

    @Test
    @Config(sdk = [30])
    fun `a partir do Android 11, a READ basta`() {
        grantReadOnly()

        terminal.creditPayment("1,00", reply)

        assertEquals(1, sdk.started.size)
    }

    @Test
    fun `o resultado anterior e apagado antes de abrir o app Sicoob`() {
        grantStorage()
        resultFile.writeText(approvedDxJson())

        terminal.creditPayment("1,00", reply)

        assertFalse(resultFile.exists())
        assertEquals(1, sdk.started.size)
    }

    @Test
    fun `resultado anterior que nao sai responde o erro e nao abre o app Sicoob`() {
        grantStorage()
        // Uma pasta com conteúdo não sai com delete(), como o arquivo de outro app sem a escrita.
        resultFile.mkdirs()
        File(resultFile, "preso").writeText("")

        terminal.creditPayment("1,00", reply)

        assertEquals(listOf(SipagOutcome.Failed("ERRO_NA_OPERACAO", STORAGE_MESSAGE)), replies)
        assertTrue(sdk.started.isEmpty())
    }

    @Test
    fun `sem o app Sicoob responde o erro e nao chama o SDK`() {
        grantStorage()
        sdk.installed = false

        terminal.debitPayment("1,00", reply)

        assertEquals(
            listOf(SipagOutcome.Failed("ERRO_NA_OPERACAO", NO_APP_MESSAGE)),
            replies
        )
        assertTrue(sdk.started.isEmpty())
    }

    @Test
    fun `SDK que lanca responde a falha padrao`() {
        grantStorage()
        sdk.failure = IllegalStateException("sem activity")

        terminal.pixPayment("1,00", reply)

        assertEquals(listOf(SipagOutcome.Failed("ERRO_NA_OPERACAO", "Falha ao efetuar a operação!")), replies)
    }

    @Test
    fun `JSON cortado e relido do arquivo, que ja tem o resultado completo`() {
        // O AAR lê o arquivo assim que ele aparece, e o app Sicoob pode ainda estar gravando.
        grantStorage()
        terminal.creditPayment("1,00", reply)
        resultFile.writeText(approvedDxJson())

        sdk.onResult!!.invoke("{\"label\": \"VI")

        assertEquals("T1", (replies.single() as SipagOutcome.Approved).response["NSU_SITEF"])
    }

    @Test
    fun `JSON que continua ilegivel responde a falha padrao e mantem a marca`() {
        // Com a marca ligada, a última operação ainda pode achar a venda, se o app Sicoob a aprovou.
        grantStorage()
        terminal.pixPayment("1,00", reply)
        resultFile.writeText("{")

        sdk.onResult!!.invoke("{")

        val failure = SipagOutcome.Failed("ERRO_NA_OPERACAO", PAYMENT_FAILED_MESSAGE, keepPending = true)
        assertEquals(listOf(failure), replies)
    }

    @Test
    fun `o JSON do app Sicoob passa pelo parser`() {
        grantStorage()
        terminal.creditPayment("1,00", reply)

        sdk.onResult!!.invoke(approvedDxJson())

        assertEquals("T1", (replies.single() as SipagOutcome.Approved).response["NSU_SITEF"])
    }

    /** Instala o app Sicoob no aparelho do Robolectric, atendendo a ação de pagamento. */
    private fun installSicoob() {
        val sicoob = ResolveInfo().apply {
            activityInfo = ActivityInfo().apply {
                packageName = "br.com.sicoob.skin.acquirerposskin"
                name = "br.com.sicoob.skin.acquirerposskin.MainActivity"
            }
        }
        shadowOf(activity.packageManager).addResolveInfoForIntent(Intent(SICOOB_ACTION), sicoob)
    }

    @Test
    fun `com o AAR, o app Sicoob so aparece quando atende a acao`() {
        assertFalse(Apix990Sdk.isSicoobInstalled(activity))

        installSicoob()

        assertTrue(Apix990Sdk.isSicoobInstalled(activity))
    }

    @Test
    fun `com o AAR, o credito abre o app Sicoob com os extras do plugin`() {
        grantStorage()
        installSicoob()

        DxTerminal(activity).creditPayment("1,00", reply)

        val intent = shadowOf(activity).nextStartedActivity
        assertEquals(SICOOB_ACTION, intent.action)
        assertEquals("1,00", intent.getStringExtra("EXTRA_AMOUNT"))
        assertEquals("CREDITO", intent.getStringExtra("EXTRA_PRODUCT"))
        assertEquals("TRANSACTION", intent.getStringExtra("TRANSACTIONTYPE"))
        assertEquals(activity.packageName, intent.getStringExtra("PACKAGENAME"))
        assertEquals(true, intent.getSerializableExtra("RECEIPT"))
        assertEquals("AVISTA", intent.getStringExtra("EXTRA_CREDIT_TYPE"))
        assertEquals(0, intent.getSerializableExtra("EXTRA_CREDIT_INSTALLMENT"))
        assertFalse(intent.getBooleanExtra("REPRINTERPIX", true))
    }

    @Test
    fun `com o AAR, o resultado chega fora da main thread quando o app Sicoob grava o arquivo`() {
        grantStorage()
        val received = CountDownLatch(1)
        var text: String? = null
        var looper: Looper? = Looper.getMainLooper()
        val data = TransactionData(
            product = PRODUCT.CREDITO,
            amount = "1,00",
            creditType = null,
            typeTransaction = TypeTransaction.TRANSACTION,
            pixId = null,
            pixReprinter = false,
            packageName = activity.packageName,
            receipt = true
        )

        Apix990Sdk.start(activity, data) {
            text = it
            looper = Looper.myLooper()
            received.countDown()
        }
        // O AAR fixa o caminho quando a classe carrega, e apaga o arquivo antes de abrir o app.
        // O AbstractionInfo é internal no Kotlin do AAR, então a classe é lida pelo nome.
        val abstraction = Class.forName("printx990.br.apix990.internal.domain.AbstractionInfo")
        val field = abstraction.getDeclaredField("file").apply { isAccessible = true }
        val file = field.get(null) as File
        file.parentFile?.mkdirs()
        file.writeText(approvedDxJson())

        assertTrue(received.await(5, TimeUnit.SECONDS))
        assertEquals(approvedDxJson(), text)
        assertNotEquals(Looper.getMainLooper(), looper)
    }

    private companion object {
        const val SICOOB_ACTION = "br.com.sicoob.skin.acquirerposskin.ACAO_ESPECIFICA"
        const val STORAGE_MESSAGE = "Permita o acesso ao armazenamento e tente novamente."
        const val NO_APP_MESSAGE = "Não localizamos aplicativo de pagamento neste terminal."
        const val PAYMENT_FAILED_MESSAGE = "Falha ao efetuar a operação!"
    }
}
