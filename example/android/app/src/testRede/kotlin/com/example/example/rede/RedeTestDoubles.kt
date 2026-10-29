package com.example.example.rede

import android.content.Intent
import android.graphics.Bitmap
import io.flutter.plugin.common.MethodChannel
import rede.smartrede.commons.callback.IPrinterCallback
import rede.smartrede.commons.contract.IConnectorPrinter
import rede.smartrede.sdk.FlexTipoPagamento
import rede.smartrede.sdk.Payment
import rede.smartrede.sdk.PaymentStatus
import rede.smartrede.sdk.Receipt

/** Extra em que o app da Rede devolve o pagamento, lido pelo `RedePayments.getPaymentFromIntent`. */
internal const val PAYMENT_EXTRA = "rede.smartrede.sdk.INTENT_EXTRAS_PAYMENT"

/** [RedePaymentApp] que registra os pedidos e devolve Intents que nenhum app real atende. */
internal class FakeRedePaymentApp : RedePaymentApp {
    val payments = mutableListOf<Pair<FlexTipoPagamento, Long>>()
    val reversals = mutableListOf<String>()

    /** Quando definida, os pedidos lançam esta exceção, como o SDK recusando o pagamento. */
    var failure: Exception? = null

    override fun paymentIntent(type: FlexTipoPagamento, amount: Long): Intent {
        failure?.let { throw it }
        payments += type to amount
        return Intent("rede.teste.PAGAMENTO")
    }

    override fun reversalIntent(nsu: String): Intent {
        failure?.let { throw it }
        reversals += nsu
        return Intent("rede.teste.ESTORNO")
    }
}

/** Recibo de um crédito aprovado, com os campos que o handler lê. */
internal fun receipt(operationType: String? = "Crédito", issuerName: String? = "VISA") = Receipt().apply {
    setNSU("123")
    setAUTO("A1")
    setIssuerName(issuerName)
    setOperationType(operationType)
    setValue(1.0)
    setInstallments(1)
}

/** Retorno do app da Rede com o pagamento no extra do SDK. */
internal fun paymentResult(status: PaymentStatus, receipt: Receipt? = receipt()): Intent {
    val payment = Payment().apply {
        setStatus(status)
        setReceipt(receipt)
    }
    return Intent().putExtra(PAYMENT_EXTRA, payment)
}

/** Impressora do SDK da Rede que guarda os bitmaps e o callback, sem o L400. */
internal class FakeConnectorPrinter : IConnectorPrinter {
    val printed = mutableListOf<Bitmap>()
    var callback: IPrinterCallback? = null
    var callbackRegistrations = 0

    /** O que acontece durante o `printBitmap`: avisar um erro pelo callback ou lançar, como o SDK. */
    var onPrint: (IPrinterCallback?) -> Unit = {}

    override fun setPrinterCallback(callback: IPrinterCallback) {
        this.callback = callback
        callbackRegistrations++
    }

    override fun printBitmap(bitmap: Bitmap) {
        printed += bitmap
        onPrint(callback)
    }

    override fun printBlankLines(lines: Int) = Unit

    override fun printArrayTextWithAttributes(texts: List<Pair<Array<String>, List<Map<String, Int>>>>) = Unit

    override fun printBitmapWithAttributes(bitmap: Bitmap, attributes: Map<String, Int>) = Unit

    override fun printBarCode(code: String, width: Int, height: Int, type: Int, showText: Boolean) = Unit

    override fun printQRCode(code: String, width: Int, height: Int) = Unit
}

/** Guarda o valor das respostas de sucesso e o código e a mensagem dos erros. */
internal class RecordingResult : MethodChannel.Result {
    val replies = mutableListOf<Any?>()

    override fun success(result: Any?) {
        replies += result
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        replies += "error:$errorCode:$errorMessage"
    }

    override fun notImplemented() {
        replies += "notImplemented"
    }
}
