package com.example.example.sipag

/** Recebe o resultado de uma operação. O DX o chama de uma thread de IO, às vezes com o da seguinte. */
internal typealias SipagReply = (SipagOutcome) -> Unit

/** O P2 (P2-B, P2-A11) usa o pos7api; os outros modelos, o apix990. É a escolha do plugin. */
internal fun isP2(model: String): Boolean = model.contains("P2")

/**
 * Um dos dois SDKs da Sipag: o do DX8000 e da X990 ([DxTerminal]) ou o do P2 ([P2Terminal]), com as
 * operações do `PaymentInterface` do plugin `flutter_sipag_sdk`. O valor chega como o Dart o manda, em reais
 * com vírgula.
 */
internal interface SipagTerminal {
    fun creditPayment(amount: String, reply: SipagReply)
    fun debitPayment(amount: String, reply: SipagReply)
    fun pixPayment(amount: String, reply: SipagReply)
    fun refund(nsu: String, reply: SipagReply)
    fun pixRefund(nsu: String, reply: SipagReply)
}
