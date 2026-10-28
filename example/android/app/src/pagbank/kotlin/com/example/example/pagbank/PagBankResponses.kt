
package com.example.example.pagbank

import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagEventData
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagPrintResult
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagTransactionResult

/**
 * Transação enviada ao Dart, aprovada ou não: `result` 0 (PlugPag.RET_OK) indica sucesso. O `voidType` já
 * vai calculado para o estorno dela.
 */
internal fun PlugPagTransactionResult.toMap(): Map<String, Any?> = mapOf(
    "result" to result,
    "errorCode" to errorCode,
    "message" to message,
    "transactionCode" to transactionCode,
    "transactionId" to transactionId,
    "date" to date,
    "time" to time,
    "amount" to amount,
    "installments" to installments,
    "paymentType" to PagBankPaymentType.fromSdk(paymentType)?.name,
    "voidType" to PagBankVoidType.forPayment(paymentType).name,
    "cardBrand" to cardBrand,
    "bin" to bin,
    "holder" to holder,
    "holderName" to holderName,
    "nsu" to nsu,
    "hostNsu" to hostNsu,
    "autoCode" to autoCode,
    "userReference" to userReference,
    "label" to label,
    "typeTransaction" to typeTransaction,
    "terminalSerialNumber" to terminalSerialNumber
)

internal fun PlugPagPrintResult.toMap(): Map<String, Any?> = mapOf(
    "result" to result,
    "errorCode" to errorCode,
    "message" to message
)

internal fun PlugPagEventData.toMap(): Map<String, Any?> = mapOf(
    "code" to eventCode,
    "message" to customMessage
)
