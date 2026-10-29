import 'dart:async';

import 'package:core/core.dart';
import 'package:dependencies/dependencies.dart';

/// Transação aprovada que o serviço fake devolve por padrão.
final approvedTransaction = VeroTransactionResult.fromMap({
  'NSU': '123',
  'AUTORIZACAO': 'A1',
  'BANDEIRA': 'VISA',
  'VALOR': '100',
});

class FakeVeroPaymentService implements IVeroPaymentService {
  /// Chamadas recebidas, com o valor ou o NSU, na ordem.
  final calls = <(String, Object)>[];
  Either<VeroFailure, VeroTransactionResult> result = right(approvedTransaction);

  /// Quando definido, a operação só termina ao completá-lo, como o app da Vero demorando a responder.
  Completer<void>? pending;

  Future<Either<VeroFailure, VeroTransactionResult>> _record(String method, Object argument) async {
    calls.add((method, argument));
    await pending?.future;
    return result;
  }

  @override
  Future<Either<VeroFailure, VeroTransactionResult>> creditCardPayment(double amount) =>
      _record('creditCardPayment', amount);

  @override
  Future<Either<VeroFailure, VeroTransactionResult>> debitCardPayment(double amount) =>
      _record('debitCardPayment', amount);

  @override
  Future<Either<VeroFailure, VeroTransactionResult>> pixPayment(double amount) =>
      _record('pixPayment', amount);

  @override
  Future<Either<VeroFailure, VeroTransactionResult>> acquirerPayment(double amount) =>
      _record('acquirerPayment', amount);

  @override
  Future<Either<VeroFailure, VeroTransactionResult>> refundPayment(String nsu) =>
      _record('refundPayment', nsu);
}
