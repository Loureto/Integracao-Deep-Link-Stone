import 'dart:async';

import 'package:dependencies/dependencies.dart';
import 'package:flutter/services.dart';

import '../../data/data.dart';
import '../../domain/domain.dart';

/// [IVeroPaymentService] pelo canal `vero_flutter`, com os métodos do plugin `vero_flutter` do
/// flutter_acquirers_sdk. O Android abre o app da Vero e responde quando ele devolve o resultado.
class VeroPaymentService implements IVeroPaymentService {
  static const _payCredit = 'payCredit';
  static const _payDebit = 'payDebit';
  static const _payPix = 'payPix';
  static const _wallet = 'wallet';
  static const _refund = 'refund';

  /// Espera máxima pelo comprovante automático. O posmpapi pode nunca chamar o listener, e a transação aprovada
  /// precisa voltar a quem chamou.
  static const _receiptTimeout = Duration(seconds: 60);

  final MethodChannel _channel;
  final INativePrinterService _printer;

  const VeroPaymentService(this._channel, this._printer);

  @override
  Future<Either<VeroError, VeroTransactionResult>> creditCardPayment(double amount) =>
      _pay(_payCredit, amount);

  @override
  Future<Either<VeroError, VeroTransactionResult>> debitCardPayment(double amount) => _pay(_payDebit, amount);

  @override
  Future<Either<VeroError, VeroTransactionResult>> pixPayment(double amount) => _pay(_payPix, amount);

  @override
  Future<Either<VeroError, VeroTransactionResult>> acquirerPayment(double amount) => _pay(_wallet, amount);

  @override
  Future<Either<VeroError, VeroTransactionResult>> refundPayment(String nsu) async {
    if (nsu.trim().isEmpty) return left(VeroError.nsuNotInformed());

    return _call(_refund, {'nsu': nsu});
  }

  /// O app da Vero recebe o valor em centavos. O centralizer truncava (`toInt`) e cobrava R$ 0,29 como 28
  /// centavos; aqui o valor é arredondado.
  Future<Either<VeroError, VeroTransactionResult>> _pay(String method, double amount) {
    return _call(method, {'amount': (amount * 100).round()});
  }

  /// Chama o app da Vero e, como o `VeroPayment` do flutter_acquirers_sdk, imprime o comprovante do cliente pelo
  /// driver genérico depois do pagamento ou do estorno aprovado. O resultado da impressão não muda o da operação.
  Future<Either<VeroError, VeroTransactionResult>> _call(String method, Map<String, Object> arguments) async {
    final Map<dynamic, dynamic>? response;
    try {
      response = await _channel.invokeMethod<Map<dynamic, dynamic>>(method, arguments);
    } on PlatformException catch (e) {
      return left(VeroError(code: e.code, message: e.message ?? e.stacktrace ?? e.toString()));
    } on MissingPluginException {
      return left(VeroError.notImplemented(method));
    }
    if (response == null) return left(VeroError.unknown());

    final result = VeroTransactionResult.fromMap(response);
    await _printCustomerReceipt(result.customerReceiptTxt);
    return right(result);
  }

  /// Comprovante vazio não vai à impressora, que imprimiria só uma faixa em branco.
  Future<void> _printCustomerReceipt(String receipt) async {
    if (receipt.trim().isEmpty) return;

    try {
      await _printer.printTxt(receipt).timeout(_receiptTimeout);
    } on TimeoutException {
      // Sem resposta do driver, a transação aprovada volta assim mesmo: o resultado da impressão já é ignorado.
    }
  }
}
