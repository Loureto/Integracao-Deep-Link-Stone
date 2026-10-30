package com.example.example.sipag

import org.json.JSONArray
import org.json.JSONObject

/**
 * Lê o JSON que o app Sicoob grava no DX8000 e na X990, como o `DxParseOperation` do plugin
 * `flutter_sipag_sdk`: mesmas chaves, códigos e mensagens. A transação é aprovada quando há comprovante.
 *
 * No plugin, o `getString` lançava `JSONException` com uma chave ausente e derrubava o app no callback; aqui
 * um campo ausente ou `null` vira "" (ou 0), e só um JSON ilegível lança.
 */
internal object DxResultParser {

    private const val PIX = "PIX"
    private const val REFUND = "Refund"

    /** Lança `JSONException` se o [json] for ilegível. */
    fun parse(json: String): SipagOutcome {
        val result = JSONObject(json)

        result.optJSONArray("mError")?.firstObject()?.let { error ->
            val message = "${error.text("mErrorDescription")} ${error.optInt("mPOS7ErrorCode")}"
            return SipagOutcome.Failed(
                code = error.text("mErrorCode").ifBlank { ERRO_NA_OPERACAO },
                message = message,
                details = transactionResponse(message, null, null, null, null, null, null, 0, 0.0)
            )
        }

        val receipts = result.optJSONArray("receiptList")
        val companyReceipt = receipts?.firstObject()
        val approved = companyReceipt != null
        val message = when {
            approved -> SUCCESS_PAYMENT
            else -> result.text("displayMessage").ifEmpty { INTERNAL_ERROR_MESSAGE }
        }

        val product = result.text("product")
        val response = transactionResponse(
            message = message,
            flag = result.text("label"),
            nsu = result.text(if (product == PIX) "pixID" else "transactionID"),
            cardNumber = when {
                product.isEmpty() -> REFUND
                else -> result.text("maskedPan").ifEmpty { product }
            },
            authorization = result.text("authorizationCode"),
            companyReceipt = companyReceipt?.lines(),
            clientReceipt = receipts?.optJSONObject(1)?.lines(),
            installments = result.optInt("installments"),
            amount = centsToReais(result.text("amount"))
        )

        return if (approved) {
            SipagOutcome.Approved(response)
        } else {
            SipagOutcome.Failed(INVALID_OPERATION_CODE, message, response)
        }
    }

    /** O texto da [key]. Ausente ou `null` vira "": o `optString` do Android devolve "null" no `null`. */
    private fun JSONObject.text(key: String): String = if (isNull(key)) "" else optString(key)

    private fun JSONArray.firstObject(): JSONObject? = optJSONObject(0)

    /** As linhas do comprovante sem o `\u0000` que o app Sicoob deixa, cada uma seguida de quebra. */
    private fun JSONObject.lines(): String {
        val lines = optJSONArray("lines") ?: return ""
        return buildString {
            for (i in 0 until lines.length()) append(lines.optString(i).replace("\u0000", "")).append("\n")
        }
    }
}
