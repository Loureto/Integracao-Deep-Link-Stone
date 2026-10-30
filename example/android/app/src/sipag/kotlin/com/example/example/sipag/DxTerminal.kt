package com.example.example.sipag

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.File
import org.json.JSONException
import printx990.br.apix990.internal.TransactionInfo
import printx990.br.apix990.internal.domain.callbacks.TransactionCallback
import printx990.br.apix990.internal.domain.dto.CREDITTYPE
import printx990.br.apix990.internal.domain.dto.CreditInfo
import printx990.br.apix990.internal.domain.dto.PRODUCT
import printx990.br.apix990.internal.domain.dto.TransactionData
import printx990.br.apix990.internal.domain.dto.TypeTransaction

/** O arquivo em que o app Sicoob grava o resultado e que a última operação lê, como no plugin. */
internal fun operationResultFile(): File {
    val documents = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
    return File(documents, "operation_result.json")
}

/** O que o [DxTerminal] usa do apix990, para os testes rodarem sem o app Sicoob. */
internal interface DxSdk {
    /** Se o app Sicoob atende a ação de pagamento neste aparelho. */
    fun isSicoobInstalled(context: Context): Boolean

    /** Abre o app Sicoob com o [data] e chama o [onResult] com o JSON que ele grava. */
    fun start(activity: Activity, data: TransactionData, onResult: (String) -> Unit)
}

/**
 * O apix990 de verdade. O `initTransaction` apaga `Documents/operation_result.json` sem conferir se
 * conseguiu, abre o app Sicoob com `startActivity` e lê o arquivo a cada 1 s até ele aparecer; o callback
 * chega numa thread de IO, uma vez só. O poller só para quando lê um arquivo: uma operação nova não o
 * encerra, e ele entrega à operação anterior o resultado da nova.
 */
internal object Apix990Sdk : DxSdk {
    override fun isSicoobInstalled(context: Context) = TransactionInfo().getSipag(context)

    override fun start(activity: Activity, data: TransactionData, onResult: (String) -> Unit) {
        TransactionInfo().initTransaction(activity, data, object : TransactionCallback {
            override fun onTransactionResult(resultData: String) = onResult(resultData)
        })
    }
}

/**
 * DX8000 e X990, pelo app Sicoob, como o `PaymentServiceDxDevice` do plugin `flutter_sipag_sdk`.
 *
 * Antes de chamar o AAR, confere o que no plugin travava o Dart ou trocava o resultado:
 * - sem a `READ_EXTERNAL_STORAGE`, o AAR pede a permissão e não retoma a transação;
 * - até o Android 10, sem a `WRITE_EXTERNAL_STORAGE`, o AAR não apaga o resultado anterior e o lê na hora
 *   como o do pagamento novo; o terminal pede as duas e só abre o app com o resultado anterior apagado;
 * - sem o app Sicoob, o AAR só mostra um Toast.
 */
internal class DxTerminal(
    private val activity: Activity,
    private val sdk: DxSdk = Apix990Sdk,
    private val resultFile: () -> File = ::operationResultFile,
    private val retryDelayMs: Long = 500
) : SipagTerminal {

    override fun creditPayment(amount: String, reply: SipagReply) = start(
        transaction(PRODUCT.CREDITO, amount, CreditInfo(CREDITTYPE.AVISTA.toString(), 0)),
        reply
    )

    override fun debitPayment(amount: String, reply: SipagReply) =
        start(transaction(PRODUCT.DEBITO, amount), reply)

    override fun pixPayment(amount: String, reply: SipagReply) =
        start(transaction(PRODUCT.PIX, amount), reply)

    /** O NSU não vai ao SDK: o `TransactionData` não tem o campo, e o app Sicoob pede a transação. */
    override fun refund(nsu: String, reply: SipagReply) =
        start(transaction(null, null, type = TypeTransaction.CANCELTRANSACTION), reply)

    override fun pixRefund(nsu: String, reply: SipagReply) =
        start(transaction(null, null, type = TypeTransaction.PIXREVERSE, pixId = nsu), reply)

    private fun transaction(
        product: PRODUCT?,
        amount: String?,
        credit: CreditInfo? = null,
        type: TypeTransaction = TypeTransaction.TRANSACTION,
        pixId: String? = null
    ) = TransactionData(
        product = product,
        amount = amount,
        creditType = credit,
        typeTransaction = type,
        pixId = pixId,
        pixReprinter = false,
        packageName = activity.packageName,
        receipt = true
    )

    private fun start(data: TransactionData, reply: SipagReply) {
        val missing = storagePermissions().filter {
            ContextCompat.checkSelfPermission(activity, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(activity, missing.toTypedArray(), STORAGE_REQUEST)
            return reply(SipagOutcome.Failed(ERRO_NA_OPERACAO, STORAGE_PERMISSION_MESSAGE))
        }
        if (!sdk.isSicoobInstalled(activity)) {
            return reply(SipagOutcome.Failed(ERRO_NA_OPERACAO, NO_PAYMENT_APP_MESSAGE))
        }
        if (!clearPreviousResult()) {
            return reply(SipagOutcome.Failed(ERRO_NA_OPERACAO, STORAGE_PERMISSION_MESSAGE))
        }

        try {
            sdk.start(activity, data) { json -> reply(parse(json)) }
        } catch (exception: Exception) {
            Log.e(TAG, "Falha ao abrir o app Sicoob.", exception)
            reply(SipagOutcome.Failed(ERRO_NA_OPERACAO, PAYMENT_FAILED))
        }
    }

    /** A WRITE só vale até o Android 10; depois, com o targetSdk do app, ela não dá acesso a nada. */
    private fun storagePermissions(): List<String> = when {
        Build.VERSION.SDK_INT <= Build.VERSION_CODES.Q -> listOf(READ_STORAGE, WRITE_STORAGE)
        else -> listOf(READ_STORAGE)
    }

    /** Se não sobrou o resultado de uma operação anterior, que o AAR leria como o da nova. */
    private fun clearPreviousResult(): Boolean {
        val file = resultFile()
        if (!file.exists() || file.delete() || !file.exists()) return true

        Log.e(TAG, "O resultado anterior não pôde ser apagado: ${file.absolutePath}")
        return false
    }

    /**
     * O AAR lê o arquivo assim que ele aparece, e o app Sicoob pode ainda estar gravando. Um JSON ilegível é
     * relido do arquivo algumas vezes (o callback já está na thread de IO do AAR). Se continuar ilegível, a
     * falha mantém a marca de operação pendente, para a última operação ainda achar a venda; no plugin, o
     * app caía, e a marca ficava ligada.
     */
    private fun parse(json: String): SipagOutcome {
        parseOrNull(json)?.let { return it }
        repeat(REREADS) {
            Thread.sleep(retryDelayMs)
            val text = try {
                resultFile().readText(Charsets.UTF_8)
            } catch (exception: Exception) {
                null
            }
            text?.let(::parseOrNull)?.let { return it }
        }
        Log.e(TAG, "Resultado do app Sicoob ilegível: $json")
        return SipagOutcome.Failed(ERRO_NA_OPERACAO, PAYMENT_FAILED, keepPending = true)
    }

    private fun parseOrNull(json: String): SipagOutcome? = try {
        DxResultParser.parse(json)
    } catch (exception: JSONException) {
        null
    }

    private companion object {
        const val TAG = "SipagDx"
        const val READ_STORAGE = Manifest.permission.READ_EXTERNAL_STORAGE
        const val WRITE_STORAGE = Manifest.permission.WRITE_EXTERNAL_STORAGE

        /** O mesmo código que o apix990 usa ao pedir a permissão. */
        const val STORAGE_REQUEST = 1001

        /** Releituras de um JSON ilegível, com o [retryDelayMs] entre elas. */
        const val REREADS = 3
    }
}
