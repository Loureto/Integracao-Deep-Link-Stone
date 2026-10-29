import 'dart:async';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

/// Transação aprovada que o serviço fake devolve por padrão.
const approvedTransaction = RedeTransactionResult(
  flag: 'VISA',
  nsu: '123',
  authorization: 'A1',
  installments: '1',
  amount: 1.0,
  cardNumber: 'Crédito',
);

class FakeRedePaymentService implements IRedePaymentService {
  /// Chamadas recebidas, com o valor, o NSU ou o que foi impresso, na ordem.
  final calls = <(String, Object?)>[];
  Either<RedeFailure, RedeTransactionResult> result = right(approvedTransaction);
  Either<RedeFailure, Unit> printResult = right(unit);

  /// Quando definido, o pagamento só termina ao completá-lo, como o app da Rede demorando a responder.
  Completer<void>? pending;

  Future<Either<RedeFailure, RedeTransactionResult>> _pay(String method, Object argument) async {
    calls.add((method, argument));
    await pending?.future;
    return result;
  }

  Future<Either<RedeFailure, Unit>> _print(String method, Object? argument) async {
    calls.add((method, argument));
    return printResult;
  }

  @override
  Future<Either<RedeFailure, RedeTransactionResult>> creditCardPayment(double amount) =>
      _pay('creditCardPayment', amount);

  @override
  Future<Either<RedeFailure, RedeTransactionResult>> debitCardPayment(double amount) =>
      _pay('debitCardPayment', amount);

  @override
  Future<Either<RedeFailure, RedeTransactionResult>> pixPayment(double amount) => _pay('pixPayment', amount);

  @override
  Future<Either<RedeFailure, RedeTransactionResult>> refundPayment(String nsu) => _pay('refundPayment', nsu);

  @override
  Future<Either<RedeFailure, Unit>> printTxt(String text) => _print('printTxt', text);

  @override
  Future<Either<RedeFailure, Unit>> printNfc(String nfcBase64) => _print('printNfc', nfcBase64);

  @override
  Future<Either<RedeFailure, Unit>> testPrint() => _print('testPrint', null);

  @override
  Future<Either<RedeFailure, Unit>> printReceipt({required Uint8List bitmap}) =>
      _print('printReceipt', bitmap);
}
